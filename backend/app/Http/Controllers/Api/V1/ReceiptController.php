<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\PickupRequest;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Symfony\Component\HttpFoundation\Response as SymfonyResponse;

class ReceiptController extends Controller
{
    use RespondsWithJson;

    public function show(Request $request, string $receiptId): JsonResponse
    {
        $user = $request->user();
        $pr = $this->findReceipt($receiptId);

        if ($pr === null) {
            return response()->json(['message' => 'Receipt not found.'], 404);
        }

        if (! $this->userCanView($user->id, $pr)) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }

        return $this->success($this->receiptPayload($request, $pr));
    }

    public function pdf(Request $request, string $receiptId): SymfonyResponse|Response
    {
        $user = $request->user();
        $pr = $this->findReceipt($receiptId);

        if ($pr === null) {
            return response()->json(['message' => 'Receipt not found.'], 404);
        }

        if (! $this->userCanView($user->id, $pr)) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }

        $order = $pr->order;
        $payload = $this->receiptPayload($request, $pr);

        $pdf = Pdf::loadView('receipts.pdf', [
            'receiptId' => $pr->receipt_id,
            'issuedAt' => $pr->receipt_issued_at?->toIso8601String() ?? '',
            'pickupRequestId' => $pr->public_id,
            'orderId' => $order?->public_id,
            'currency' => $payload['currency'] ?? 'KES',
            'lineDescription' => $pr->waste_type.' pickup',
            'quantityKg' => (float) $pr->quantity_kg,
            'totalAmount' => $pr->total_amount !== null ? (string) $pr->total_amount : '—',
            'escrow' => $payload['escrow'] ?? null,
        ]);

        $filename = 'receipt-'.$pr->receipt_id.'.pdf';

        return $pdf->download($filename);
    }

    private function findReceipt(string $receiptId): ?PickupRequest
    {
        return PickupRequest::query()
            ->with(['order', 'listing', 'generator', 'assignedCollector'])
            ->where('receipt_id', $receiptId)
            ->first();
    }

    private function userCanView(int $userId, PickupRequest $pr): bool
    {
        $allowed = $pr->generator_user_id === $userId
            || $pr->assigned_collector_user_id === $userId;

        $order = $pr->order;
        if ($order !== null) {
            $allowed = $allowed
                || $order->seller_user_id === $userId
                || $order->buyer_user_id === $userId;
        }

        return $allowed;
    }

    /**
     * @return array<string, mixed>
     */
    private function receiptPayload(Request $request, PickupRequest $pr): array
    {
        $order = $pr->order;

        return [
            'receiptId' => $pr->receipt_id,
            'issuedAt' => $pr->receipt_issued_at?->toIso8601String(),
            'pickupRequestId' => $pr->public_id,
            'orderId' => $order?->public_id,
            'currency' => $order?->currency ?? 'KES',
            'lineItems' => [
                [
                    'description' => $pr->waste_type.' pickup',
                    'quantityKg' => (float) $pr->quantity_kg,
                    'totalAmount' => $pr->total_amount !== null ? (float) $pr->total_amount : null,
                ],
            ],
            'escrow' => $order !== null ? [
                'status' => $order->escrow_status,
                'amount' => $order->escrow_amount !== null ? (float) $order->escrow_amount : null,
                'platformFee' => $order->platform_fee_amount !== null ? (float) $order->platform_fee_amount : null,
            ] : null,
            'receiptUrl' => $request->getSchemeAndHttpHost().'/api/v1/receipts/'.$pr->receipt_id,
            'receiptPdfUrl' => $request->getSchemeAndHttpHost().'/api/v1/receipts/'.$pr->receipt_id.'/pdf',
        ];
    }
}
