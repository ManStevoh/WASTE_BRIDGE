<?php

namespace App\Services;

use App\Events\WalletWithdrawalB2cFinalized;
use App\Models\MpesaWebhookEvent;
use App\Models\User;
use App\Models\WalletLedgerEntry;
use App\Services\Mpesa\MpesaB2cService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Processes Safaricom Daraja B2C ResultURL and QueueTimeOutURL callbacks (Phase 4).
 */
final class WalletB2cPayoutCompletionService
{
    /**
     * @param  'result'|'timeout'  $kind
     */
    public static function handle(array $payload, string $kind): void
    {
        $parsed = MpesaB2cService::parseB2cResultPayload($payload);

        $conv = $parsed['conversation_id'] ?? null;
        $orig = $parsed['originator_conversation_id'] ?? null;
        $lookup = $conv ?: $orig;

        if ($lookup === null || $lookup === '') {
            Log::warning('mpesa.b2c.callback.no_conversation', ['kind' => $kind, 'payload' => $payload]);

            return;
        }

        $idemKey = 'b2c-'.$kind.'-'.$lookup;

        if (MpesaWebhookEvent::query()
            ->where('idempotency_key', $idemKey)
            ->where('processing_status', 'processed')
            ->exists()) {
            return;
        }

        MpesaWebhookEvent::query()
            ->where('idempotency_key', $idemKey)
            ->where('processing_status', 'failed')
            ->delete();

        $event = MpesaWebhookEvent::query()->create([
            'idempotency_key' => $idemKey,
            'event_type' => $kind === 'timeout' ? 'b2c_timeout' : 'b2c_result',
            'payload' => $payload,
            'processing_status' => 'received',
        ]);

        $entry = self::findWithdrawalDebit($parsed['conversation_id'], $parsed['originator_conversation_id']);

        if ($entry === null) {
            $event->update([
                'processing_status' => 'skipped',
                'processing_error' => 'No wallet ledger debit for ConversationID',
                'processed_at' => now(),
            ]);
            Log::info('mpesa.b2c.callback.no_ledger_entry', ['lookup' => $lookup, 'kind' => $kind]);

            return;
        }

        try {
            if ($kind === 'timeout') {
                self::applyTimeout($entry, $parsed);
            } else {
                self::applyResult($entry, $parsed);
            }

            $event->update([
                'processing_status' => 'processed',
                'processed_at' => now(),
            ]);
        } catch (\Throwable $e) {
            Log::error('mpesa.b2c.callback.process_failed', [
                'lookup' => $lookup,
                'error' => $e->getMessage(),
            ]);
            $event->update([
                'processing_status' => 'failed',
                'processing_error' => $e->getMessage(),
                'processed_at' => now(),
            ]);
        }
    }

    private static function findWithdrawalDebit(?string $conversationId, ?string $originatorId): ?WalletLedgerEntry
    {
        return WalletLedgerEntry::query()
            ->where('category', 'withdrawal')
            ->where('entry_type', 'debit')
            ->where(function ($q) use ($conversationId, $originatorId): void {
                $has = false;
                if (is_string($conversationId) && $conversationId !== '') {
                    $q->where('provider_reference', $conversationId);
                    $has = true;
                }
                if (is_string($originatorId) && $originatorId !== '') {
                    if ($has) {
                        $q->orWhere('originator_conversation_id', $originatorId);
                    } else {
                        $q->where('originator_conversation_id', $originatorId);
                    }
                }
            })
            ->orderByDesc('id')
            ->first();
    }

    /**
     * @param  array{conversation_id: ?string, originator_conversation_id: ?string, result_code: int, result_desc: string, transaction_receipt: ?string, transaction_amount: ?string}  $parsed
     */
    private static function applyTimeout(WalletLedgerEntry $entry, array $parsed): void
    {
        if (in_array($entry->payout_status, ['completed', 'failed'], true)) {
            return;
        }

        $entry->payout_status = 'timeout';
        $entry->save();

        $user = User::query()->find($entry->user_id);
        if ($user === null) {
            return;
        }

        event(new WalletWithdrawalB2cFinalized(
            $user->id,
            'timeout',
            (string) $entry->amount,
            'KES',
            (string) ($entry->provider_reference ?? $parsed['conversation_id'] ?? ''),
            null,
            'M-Pesa did not confirm your payout in time. If your phone still shows success, wait a few minutes; otherwise contact support with reference '.($entry->provider_reference ?? '').'.',
            'withdrawalTimeout',
        ));
    }

    /**
     * @param  array{conversation_id: ?string, originator_conversation_id: ?string, result_code: int, result_desc: string, transaction_receipt: ?string, transaction_amount: ?string}  $parsed
     */
    private static function applyResult(WalletLedgerEntry $entry, array $parsed): void
    {
        if ($entry->payout_status === 'completed') {
            return;
        }

        $code = $parsed['result_code'];
        $success = $code === 0;

        if ($success) {
            if ($entry->payout_status === 'failed') {
                return;
            }

            $entry->payout_status = 'completed';
            $entry->payout_completed_at = now();
            $entry->payout_receipt = $parsed['transaction_receipt'];
            $entry->save();

            $user = User::query()->find($entry->user_id);
            if ($user === null) {
                return;
            }

            $ref = $parsed['transaction_receipt'] ?? '(see M-Pesa SMS)';
            event(new WalletWithdrawalB2cFinalized(
                $user->id,
                'completed',
                (string) $entry->amount,
                'KES',
                (string) ($entry->provider_reference ?? ''),
                $parsed['transaction_receipt'],
                'M-Pesa sent '.$entry->amount.' KES to your phone. Receipt '.$ref.'.',
                'withdrawalCompleted',
            ));

            return;
        }

        if (! in_array($entry->payout_status, ['submitted', 'timeout'], true)) {
            return;
        }

        self::reverseDebitAndMarkFailed($entry, $parsed['result_desc'] ?? 'M-Pesa declined (ResultCode '.$code.').');
    }

    private static function reverseDebitAndMarkFailed(WalletLedgerEntry $debit, string $reason): void
    {
        $reversalKey = 'b2c-reversal-'.($debit->provider_reference ?? $debit->public_id);

        DB::transaction(function () use ($debit, $reason, $reversalKey): void {
            /** @var WalletLedgerEntry $debit */
            $debit = WalletLedgerEntry::query()->lockForUpdate()->findOrFail($debit->id);

            if ($debit->payout_status === 'failed') {
                return;
            }

            $user = User::query()->lockForUpdate()->findOrFail($debit->user_id);

            WalletLedgerService::creditUserAccount(
                $user,
                (string) $debit->amount,
                'b2c_reversal',
                'Refund: withdrawal failed — '.$reason,
                $reversalKey,
                null,
                $debit->provider_reference,
            );

            $debit->payout_status = 'failed';
            $debit->payout_completed_at = now();
            $debit->save();
        });

        $user = User::query()->find($debit->user_id);
        if ($user === null) {
            return;
        }

        event(new WalletWithdrawalB2cFinalized(
            $user->id,
            'failed',
            (string) $debit->amount,
            'KES',
            (string) ($debit->provider_reference ?? ''),
            null,
            'M-Pesa could not complete the payout. '.$reason.' Your wallet has been refunded.',
            'withdrawalFailed',
        ));
    }
}
