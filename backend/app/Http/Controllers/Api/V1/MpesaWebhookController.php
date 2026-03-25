<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\MpesaWebhookEvent;
use App\Models\PaymentIntent;
use App\Models\User;
use App\Services\EscrowService;
use App\Services\Mpesa\MpesaService;
use App\Services\WalletLedgerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class MpesaWebhookController extends Controller
{
    public function callback(Request $request): JsonResponse
    {
        $payload = $request->all();

        $parsed = MpesaService::parseStkCallback($payload);
        $checkoutId = $parsed['checkout_request_id'];

        if ($checkoutId !== null && $checkoutId !== '') {
            return $this->handleStkCallback($payload, $parsed);
        }

        return $this->handleLegacyTestPayload($request, $payload);
    }

    /**
     * @param  array<string, mixed>  $payload
     * @param  array{checkout_request_id: ?string, merchant_request_id: ?string, result_code: int, result_desc: string, receipt: ?string, amount: ?string, phone: ?string}  $parsed
     */
    private function handleStkCallback(array $payload, array $parsed): JsonResponse
    {
        $checkoutId = (string) $parsed['checkout_request_id'];

        if (MpesaWebhookEvent::query()->where('idempotency_key', $checkoutId)->exists()) {
            return response()->json([
                'ResultCode' => 0,
                'ResultDesc' => 'Duplicate — already recorded.',
            ]);
        }

        $event = MpesaWebhookEvent::query()->create([
            'idempotency_key' => $checkoutId,
            'event_type' => 'stk_callback',
            'payload' => $payload,
            'processing_status' => 'received',
        ]);

        Log::info('mpesa.webhook.received', ['id' => $event->id, 'checkoutRequestID' => $checkoutId]);

        $intent = PaymentIntent::query()
            ->where('provider_checkout_id', $checkoutId)
            ->first();

        if ($intent === null) {
            $event->update([
                'processing_status' => 'skipped',
                'processing_error' => 'No payment intent for CheckoutRequestID',
                'processed_at' => now(),
            ]);

            return response()->json([
                'ResultCode' => 0,
                'ResultDesc' => 'Accepted (no matching intent)',
            ]);
        }

        try {
            if ($parsed['result_code'] !== 0) {
                EscrowService::markIntentFailed(
                    $intent,
                    $parsed['result_desc'] !== '' ? $parsed['result_desc'] : 'M-Pesa declined (ResultCode '.$parsed['result_code'].').'
                );
            } else {
                EscrowService::applySuccessfulPayment($intent, [
                    'receipt' => $parsed['receipt'],
                    'amount' => $parsed['amount'],
                ]);
            }

            $event->update([
                'processing_status' => 'processed',
                'processed_at' => now(),
            ]);
        } catch (\Throwable $e) {
            Log::error('mpesa.webhook.process_failed', [
                'checkout' => $checkoutId,
                'error' => $e->getMessage(),
            ]);
            $event->update([
                'processing_status' => 'failed',
                'processing_error' => $e->getMessage(),
                'processed_at' => now(),
            ]);
        }

        return response()->json([
            'ResultCode' => 0,
            'ResultDesc' => 'Accepted',
        ]);
    }

    /**
     * Local-only test credit path (unchanged behaviour for dev harnesses).
     *
     * @param  array<string, mixed>  $payload
     */
    private function handleLegacyTestPayload(Request $request, array $payload): JsonResponse
    {
        $idempotencyKey = $request->header('Idempotency-Key')
            ?? ($payload['CheckoutRequestID'] ?? null)
            ?? hash('sha256', json_encode($payload));

        if (MpesaWebhookEvent::query()->where('idempotency_key', $idempotencyKey)->exists()) {
            return response()->json([
                'ResultCode' => 0,
                'ResultDesc' => 'Duplicate — already recorded.',
            ]);
        }

        $event = MpesaWebhookEvent::query()->create([
            'idempotency_key' => $idempotencyKey,
            'event_type' => 'stk_callback',
            'payload' => $payload,
            'processing_status' => 'received',
        ]);

        Log::info('mpesa.webhook.received', ['id' => $event->id, 'key' => $idempotencyKey]);

        $testUserId = $payload['_test_credit_user_public_id'] ?? null;
        $testAmount = $payload['_test_amount'] ?? null;
        if (is_string($testUserId) && $testAmount !== null && app()->environment('local')) {
            $user = User::query()->where('public_id', $testUserId)->first();
            if ($user !== null) {
                WalletLedgerService::creditFromMpesa(
                    $user,
                    (string) $testAmount,
                    'mpesa:'.$idempotencyKey,
                    isset($payload['MpesaReceiptNumber']) ? (string) $payload['MpesaReceiptNumber'] : null,
                );
                $event->update([
                    'processing_status' => 'processed',
                    'processed_at' => now(),
                ]);
            }
        }

        return response()->json([
            'ResultCode' => 0,
            'ResultDesc' => 'Accepted',
        ]);
    }
}
