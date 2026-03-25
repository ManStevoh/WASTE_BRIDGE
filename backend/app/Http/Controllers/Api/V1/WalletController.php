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
