<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\WalletLedgerEntry;
use App\Services\Mpesa\MpesaB2cService;
use App\Services\NotificationWriter;
use App\Services\WalletLedgerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\StreamedResponse;

class WalletController extends Controller
{
    use RespondsWithJson;

    public function show(Request $request): JsonResponse
    {
        $wallet = $request->user()->wallet;

        if ($wallet === null) {
            return response()->json(['message' => 'Wallet not found.'], 404);
        }

        return $this->success([
            'publicId' => $wallet->public_id,
            'balance' => (float) $wallet->balance,
            'currency' => $wallet->currency,
        ]);
    }

    public function transactions(Request $request): JsonResponse
    {
        $user = $request->user();

        $paginator = WalletLedgerEntry::query()
            ->where('user_id', $user->id)
            ->latest('created_at')
            ->paginate(perPage: min((int) $request->query('per_page', 20), 100));

        $items = $paginator->getCollection()->map(fn (WalletLedgerEntry $e) => $e->toAppTransactionArray())->values();

        return $this->success(
            ['items' => $items],
            [
                'page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ]
        );
    }

    /**
     * CSV export of the authenticated user's ledger rows (Phase 4 reconciliation).
     */
    public function exportLedger(Request $request): StreamedResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date', 'after_or_equal:from'],
        ]);

        $q = WalletLedgerEntry::query()
            ->where('user_id', $user->id)
            ->orderBy('created_at');

        if (! empty($validated['from'])) {
            $q->where('created_at', '>=', $validated['from'].' 00:00:00');
        }
        if (! empty($validated['to'])) {
            $q->where('created_at', '<=', $validated['to'].' 23:59:59');
        }

        $safeId = $user->public_id ?? (string) $user->id;
        $filename = 'wallet-'.$safeId.'-'.now()->format('Y-m-d-His').'.csv';

        return response()->streamDownload(function () use ($q): void {
            $out = fopen('php://output', 'w');
            if ($out === false) {
                return;
            }

            fputcsv($out, [
                'public_id',
                'created_at',
                'entry_type',
                'category',
                'amount',
                'balance_after',
                'idempotency_key',
                'provider_reference',
                'originator_conversation_id',
                'payout_status',
                'payout_completed_at',
                'payout_receipt',
            ]);

            $q->chunk(200, function ($rows) use ($out): void {
                foreach ($rows as $row) {
                    /** @var WalletLedgerEntry $row */
                    fputcsv($out, [
                        $row->public_id,
                        $row->created_at?->toIso8601String() ?? '',
                        $row->entry_type,
                        $row->category,
                        (string) $row->amount,
                        $row->balance_after !== null ? (string) $row->balance_after : '',
                        $row->idempotency_key ?? '',
                        $row->provider_reference ?? '',
                        $row->originator_conversation_id ?? '',
                        $row->payout_status ?? '',
                        $row->payout_completed_at?->toIso8601String() ?? '',
                        $row->payout_receipt ?? '',
                    ]);
                }
            });

            fclose($out);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    public function withdraw(Request $request): JsonResponse
    {
        $user = $request->user();
        $min = (float) config('waste_bridge.settlements.min_withdrawal_kes', 10);

        $validated = $request->validate([
            'amount' => ['required', 'numeric', 'min:'.$min],
            'phone' => ['nullable', 'string', 'max:20'],
            'idempotencyKey' => ['nullable', 'string', 'max:64'],
        ]);

        $idem = $validated['idempotencyKey'] ?? 'wd-'.$user->id.'-'.Str::lower((string) Str::ulid());

        $phone = $validated['phone'] ?? $user->phone;
        $amountStr = (string) $validated['amount'];

        if (MpesaB2cService::isConfigured()) {
            if ($phone === null || $phone === '') {
                return response()->json([
                    'message' => 'Phone number required for M-Pesa payout (set profile phone or pass `phone`).',
                ], 422);
            }

            try {
                $b2c = MpesaB2cService::requestPayout(
                    $phone,
                    $amountStr,
                    'WasteBridge withdrawal',
                );
            } catch (\RuntimeException $e) {
                return response()->json(['message' => $e->getMessage()], 422);
            }

            try {
                $entry = WalletLedgerService::debitUserAccount(
                    $user,
                    $amountStr,
                    'withdrawal',
                    'Withdrawal to M-Pesa (B2C)',
                    $idem,
                    null,
                    $b2c['ConversationID'],
                    $b2c['OriginatorConversationID'] ?? null,
                    'submitted',
                );
            } catch (\RuntimeException $e) {
                return response()->json(['message' => $e->getMessage()], 422);
            }

            NotificationWriter::notify(
                $user->id,
                'Withdrawal submitted',
                $amountStr.' KES is being sent to your M-Pesa. Reference '.$b2c['ConversationID'].'.',
                'withdrawalSubmitted',
            );

            return $this->success([
                'ledgerEntryId' => $entry->public_id,
                'amount' => (float) $entry->amount,
                'payoutStatus' => 'submitted',
                'conversationId' => $b2c['ConversationID'],
                'clientMessage' => 'M-Pesa B2C request accepted. Final result arrives via Daraja ResultURL callback.',
            ]);
        }

        try {
            $entry = WalletLedgerService::debitUserAccount(
                $user,
                $amountStr,
                'withdrawal',
                'Withdrawal to M-Pesa',
                $idem,
            );
        } catch (\RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        NotificationWriter::notify(
            $user->id,
            'Withdrawal requested',
            'We queued '.$amountStr.' KES to your M-Pesa. Enable MPESA_B2C_* for live B2C.',
            'withdrawalQueued',
        );

        return $this->success([
            'ledgerEntryId' => $entry->public_id,
            'amount' => (float) $entry->amount,
            'payoutStatus' => 'queued',
            'clientMessage' => 'Balance debited. Set MPESA_B2C_ENABLED and credentials for live M-Pesa B2C.',
        ]);
    }
}
