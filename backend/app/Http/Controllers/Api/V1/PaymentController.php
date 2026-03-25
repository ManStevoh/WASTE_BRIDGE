<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\PaymentIntent;
use App\Services\AuditLogger;
use App\Services\EscrowService;
use App\Services\Mpesa\MpesaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use RuntimeException;

class PaymentController extends Controller
{
    use RespondsWithJson;

    public function initiate(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01'],
            'currency' => ['nullable', 'string', 'size:3'],
            'orderPublicId' => ['nullable', 'string', 'max:36'],
            'idempotencyKey' => ['nullable', 'string', 'max:64'],
            'phone' => ['nullable', 'string', 'max:20'],
        ]);

        $order = null;
        if (! empty($validated['orderPublicId'])) {
            $order = Order::query()->where('public_id', $validated['orderPublicId'])->first();
            if ($order === null) {
                return response()->json(['message' => 'Order not found.'], 404);
            }
            if ($order->seller_user_id !== $user->id && $order->buyer_user_id !== $user->id) {
                return response()->json(['message' => 'Forbidden.'], 403);
            }

            if ($order->subtotal_amount !== null) {
                if (bccomp((string) $validated['amount'], (string) $order->subtotal_amount, 2) !== 0) {
                    return response()->json([
                        'message' => 'Amount must match order subtotal.',
                        'meta' => ['expectedAmount' => (float) $order->subtotal_amount],
                    ], 422);
                }
            }
        }

        $idem = $validated['idempotencyKey'] ?? 'pi-'.$user->id.'-'.Str::lower((string) Str::ulid());

        $existing = PaymentIntent::query()->where('idempotency_key', $idem)->first();
        if ($existing !== null) {
            return $this->success([
                ...$existing->toClientArray(),
                'clientMessage' => 'Existing payment intent returned (idempotent).',
            ]);
        }

        $intent = PaymentIntent::create([
            'user_id' => $user->id,
            'order_id' => $order?->id,
            'amount' => $validated['amount'],
            'currency' => $validated['currency'] ?? 'KES',
            'provider' => 'mpesa',
            'status' => 'pending',
            'idempotency_key' => $idem,
            'raw_payload' => ['phase' => 'created'],
        ]);

        AuditLogger::record($request, $user, 'payment.intent_created', PaymentIntent::class, $intent->id, [
            'amount' => (string) $intent->amount,
            'currency' => $intent->currency,
        ]);

        if (! MpesaService::isConfigured()) {
            return $this->success([
                ...$intent->toClientArray(),
                'mpesa' => [
                    'enabled' => false,
                    'clientMessage' => 'M-Pesa is disabled. Set MPESA_* env vars and MPESA_ENABLED=true for STK push.',
                ],
            ]);
        }

        $phone = $validated['phone'] ?? $user->phone;
        if ($phone === null || $phone === '') {
            EscrowService::markIntentFailed($intent, 'Phone number required for M-Pesa (set profile phone or pass `phone`).');

            return response()->json(['message' => 'Phone number required for M-Pesa payment.'], 422);
        }

        try {
            $stk = MpesaService::initiateStkPush($user, $intent, $phone);
        } catch (RuntimeException $e) {
            EscrowService::markIntentFailed($intent, $e->getMessage());

            return response()->json(['message' => $e->getMessage()], 422);
        }

        $checkoutId = $stk['CheckoutRequestID'] ?? null;
        if (! is_string($checkoutId) || $checkoutId === '') {
            EscrowService::markIntentFailed($intent, 'M-Pesa STK did not return CheckoutRequestID.');

            return response()->json(['message' => 'M-Pesa STK response incomplete.'], 502);
        }

        $intent->provider_checkout_id = $checkoutId;
        $intent->status = 'processing';
        $intent->raw_payload = array_merge($intent->raw_payload ?? [], [
            'stk' => $stk['raw'] ?? $stk,
            'merchant_request_id' => $stk['MerchantRequestID'] ?? null,
        ]);
        $intent->save();

        return $this->success([
            ...$intent->fresh()->toClientArray(),
            'mpesa' => [
                'enabled' => true,
                'checkoutRequestId' => $checkoutId,
                'merchantRequestId' => $stk['MerchantRequestID'] ?? null,
                'customerMessage' => $stk['CustomerMessage'] ?? null,
                'clientMessage' => 'Enter your M-Pesa PIN on your phone to authorize.',
            ],
        ]);
    }
}
