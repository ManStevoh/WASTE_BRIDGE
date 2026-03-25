<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\WalletLedgerEntry;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Phase 4 — immutable ledger export for finance reconciliation (admin).
 */
class AdminWalletReconciliationController extends Controller
{
    public function export(Request $request): StreamedResponse
    {
        $validated = $request->validate([
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date', 'after_or_equal:from'],
        ]);

        $q = WalletLedgerEntry::query()->orderBy('created_at');

        if (! empty($validated['from'])) {
            $q->where('created_at', '>=', $validated['from'].' 00:00:00');
        }
        if (! empty($validated['to'])) {
            $q->where('created_at', '<=', $validated['to'].' 23:59:59');
        }

        $filename = 'wallet-reconciliation-'.now()->format('Y-m-d-His').'.csv';

        return response()->streamDownload(function () use ($q): void {
            $out = fopen('php://output', 'w');
            if ($out === false) {
                return;
            }

            fputcsv($out, [
                'public_id',
                'user_id',
                'wallet_id',
                'created_at',
                'entry_type',
                'category',
                'amount',
                'balance_after',
                'status',
                'idempotency_key',
                'provider_reference',
                'originator_conversation_id',
                'payout_status',
                'payout_completed_at',
                'payout_receipt',
                'order_id',
            ]);

            $q->chunk(500, function ($rows) use ($out): void {
                foreach ($rows as $row) {
                    /** @var WalletLedgerEntry $row */
                    fputcsv($out, [
                        $row->public_id,
                        (string) $row->user_id,
                        (string) $row->wallet_id,
                        $row->created_at?->toIso8601String() ?? '',
                        $row->entry_type,
                        $row->category,
                        (string) $row->amount,
                        $row->balance_after !== null ? (string) $row->balance_after : '',
                        $row->status,
                        $row->idempotency_key ?? '',
                        $row->provider_reference ?? '',
                        $row->originator_conversation_id ?? '',
                        $row->payout_status ?? '',
                        $row->payout_completed_at?->toIso8601String() ?? '',
                        $row->payout_receipt ?? '',
                        $row->order_id !== null ? (string) $row->order_id : '',
                    ]);
                }
            });

            fclose($out);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }
}
