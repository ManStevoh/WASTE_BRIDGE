<?php

namespace App\Services;

use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletLedgerEntry;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Request as RequestFacade;

/**
 * Append-only wallet ledger. Use for M-Pesa deposits and future escrow flows.
 */
final class WalletLedgerService
{
    /**
     * Credit wallet from M-Pesa (or other PSP) with idempotency.
     */
    public static function creditFromMpesa(
        User $user,
        string $amount,
        string $idempotencyKey,
        ?string $providerReference = null,
    ): ?WalletLedgerEntry {
        $credit = $amount;

        return DB::transaction(function () use ($user, $credit, $idempotencyKey, $providerReference): ?WalletLedgerEntry {
            $existing = WalletLedgerEntry::query()->where('idempotency_key', $idempotencyKey)->first();
            if ($existing !== null) {
                return $existing;
            }

            $wallet = Wallet::query()->where('user_id', $user->id)->lockForUpdate()->firstOrFail();
            $wallet->balance = bcadd((string) $wallet->balance, (string) $credit, 2);
            $wallet->save();

            $entry = WalletLedgerEntry::query()->create([
                'wallet_id' => $wallet->id,
                'user_id' => $user->id,
                'amount' => $credit,
                'entry_type' => 'credit',
                'status' => 'posted',
                'category' => 'mpesa_deposit',
                'description' => 'M-Pesa deposit',
                'balance_after' => $wallet->balance,
                'idempotency_key' => $idempotencyKey,
                'provider_reference' => $providerReference,
                'created_at' => now(),
            ]);

            AuditLogger::recordSystem(
                $user,
                'wallet.mpesa_credit',
                WalletLedgerEntry::class,
                $entry->id,
                [
                    'amount' => $credit,
                    'idempotency_key' => $idempotencyKey,
                    'provider_reference' => $providerReference,
                ],
                RequestFacade::ip(),
            );

            return $entry;
        });
    }

    /**
     * Generic credit (escrow release, adjustments, etc.).
     */
    public static function creditUserAccount(
        User $user,
        string $amount,
        string $category,
        string $description,
        string $idempotencyKey,
        ?int $orderId = null,
        ?string $providerReference = null,
    ): ?WalletLedgerEntry {
        $credit = $amount;

        return DB::transaction(function () use ($user, $credit, $category, $description, $idempotencyKey, $orderId, $providerReference): ?WalletLedgerEntry {
            $existing = WalletLedgerEntry::query()->where('idempotency_key', $idempotencyKey)->first();
            if ($existing !== null) {
                return $existing;
            }

            $wallet = Wallet::query()->where('user_id', $user->id)->lockForUpdate()->firstOrFail();
            $wallet->balance = bcadd((string) $wallet->balance, (string) $credit, 2);
            $wallet->save();

            return WalletLedgerEntry::query()->create([
                'wallet_id' => $wallet->id,
                'user_id' => $user->id,
                'amount' => $credit,
                'entry_type' => 'credit',
                'status' => 'posted',
                'category' => $category,
                'description' => $description,
                'balance_after' => $wallet->balance,
                'idempotency_key' => $idempotencyKey,
                'provider_reference' => $providerReference,
                'order_id' => $orderId,
                'created_at' => now(),
            ]);
        });
    }

    /**
     * @throws \RuntimeException when insufficient balance
     */
    public static function debitUserAccount(
        User $user,
        string $amount,
        string $category,
        string $description,
        string $idempotencyKey,
        ?int $orderId = null,
        ?string $providerReference = null,
        ?string $originatorConversationId = null,
        ?string $initialPayoutStatus = null,
    ): WalletLedgerEntry {
        $debit = $amount;

        return DB::transaction(function () use ($user, $debit, $category, $description, $idempotencyKey, $orderId, $providerReference, $originatorConversationId, $initialPayoutStatus): WalletLedgerEntry {
            $existing = WalletLedgerEntry::query()->where('idempotency_key', $idempotencyKey)->first();
            if ($existing !== null) {
                return $existing;
            }

            $wallet = Wallet::query()->where('user_id', $user->id)->lockForUpdate()->firstOrFail();
            if (bccomp((string) $wallet->balance, (string) $debit, 2) < 0) {
                throw new \RuntimeException('Insufficient wallet balance.');
            }

            $wallet->balance = bcsub((string) $wallet->balance, (string) $debit, 2);
            $wallet->save();

            return WalletLedgerEntry::query()->create([
                'wallet_id' => $wallet->id,
                'user_id' => $user->id,
                'amount' => $debit,
                'entry_type' => 'debit',
                'status' => 'posted',
                'category' => $category,
                'description' => $description,
                'balance_after' => $wallet->balance,
                'idempotency_key' => $idempotencyKey,
                'provider_reference' => $providerReference,
                'originator_conversation_id' => $originatorConversationId,
                'payout_status' => $initialPayoutStatus,
                'order_id' => $orderId,
                'created_at' => now(),
            ]);
        });
    }
}
