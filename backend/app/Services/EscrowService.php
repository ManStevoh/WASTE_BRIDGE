<?php

namespace App\Services;

use App\Domain\Enums\MarketplaceOrderStatus;
use App\Models\Order;
use App\Models\PaymentIntent;
use App\Models\PickupJob;
use App\Models\PickupRequest;
use App\Models\User;
use App\Support\OrderLifecycle;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Request as RequestFacade;
use Illuminate\Support\Str;

/**
 * Escrow capture on successful M-Pesa STK; release to seller when order completes.
 */
final class EscrowService
{
    public static function commissionPercent(): float
    {
        return max(0.0, (float) config('waste_bridge.settlements.platform_commission_percent', 0));
    }

    /**
     * Apply successful PSP result to wallet top-up or order escrow.
     *
     * @param  array{receipt: ?string, amount: ?string}  $meta
     */
    public static function applySuccessfulPayment(PaymentIntent $intent, array $meta): void
    {
        DB::transaction(function () use ($intent, $meta): void {
            /** @var PaymentIntent $intent */
            $intent = PaymentIntent::query()->lockForUpdate()->findOrFail($intent->id);

            if ($intent->status === 'succeeded') {
                return;
            }

            $receipt = $meta['receipt'] ?? null;
            $user = User::query()->lockForUpdate()->findOrFail($intent->user_id);

            if ($intent->order_id === null) {
                WalletLedgerService::creditFromMpesa(
                    $user,
                    (string) $intent->amount,
                    'mpesa:stk:'.$intent->provider_checkout_id,
                    $receipt,
                );

                $intent->status = 'succeeded';
                $intent->raw_payload = array_merge($intent->raw_payload ?? [], [
                    'mpesa_receipt' => $receipt,
                    'captured_at' => now()->toIso8601String(),
                ]);
                $intent->save();

                NotificationWriter::notify(
                    $user->id,
                    'Wallet topped up',
                    'Your wallet was credited with '.(string) $intent->amount.' '.$intent->currency.'.',
                    'walletCredit',
                );

                return;
            }

            $order = Order::query()->lockForUpdate()->findOrFail($intent->order_id);

            if ($order->buyer_user_id === null) {
                $order->buyer_user_id = $user->id;
            }

            $pct = self::commissionPercent();
            $gross = (string) $intent->amount;
            $fee = bcmul($gross, (string) ($pct / 100.0), 2);
            if (bccomp($fee, $gross, 2) > 0) {
                $fee = $gross;
            }

            $order->escrow_amount = $gross;
            $order->escrow_status = 'held';
            $order->platform_fee_amount = $fee;
            $order->save();

            PickupRequest::query()
                ->where('order_id', $order->id)
                ->update(['payment_status' => 'paid']);

            $intent->status = 'succeeded';
            $intent->raw_payload = array_merge($intent->raw_payload ?? [], [
                'mpesa_receipt' => $receipt,
                'captured_at' => now()->toIso8601String(),
            ]);
            $intent->save();

            NotificationWriter::notify(
                $user->id,
                'Payment received',
                'Your payment of '.$gross.' '.$order->currency.' for order '.$order->public_id.' is held in escrow.',
                'paymentCaptured',
            );

            $seller = User::query()->find($order->seller_user_id);
            if ($seller !== null) {
                NotificationWriter::notify(
                    $seller->id,
                    'Order funded',
                    'Order '.$order->public_id.' has been paid and is in escrow.',
                    'orderFunded',
                );
            }
        });

        $intent->refresh();
        $job = $intent->order_id !== null
            ? PickupJob::query()->where('order_id', $intent->order_id)->first()
            : null;
        if ($job !== null) {
            OrderLifecycle::syncLinkedOrder($job);
        }
    }

    public static function releaseEscrowIfDue(Order $order): void
    {
        if ($order->escrow_status !== 'held' || $order->escrow_amount === null) {
            return;
        }

        $status = MarketplaceOrderStatus::tryFrom($order->status);
        if ($status !== MarketplaceOrderStatus::Completed) {
            return;
        }

        $seller = User::query()->find($order->seller_user_id);
        if ($seller === null) {
            return;
        }

        $gross = (string) $order->escrow_amount;
        $fee = (string) ($order->platform_fee_amount ?? '0');
        $net = bcsub($gross, $fee, 2);
        if (bccomp($net, '0', 2) < 0) {
            $net = '0';
        }

        $key = 'escrow-release-order-'.$order->id;

        $prToNotify = null;

        DB::transaction(function () use ($order, $seller, $net, $key, &$prToNotify): void {
            /** @var Order $order */
            $order = Order::query()->lockForUpdate()->findOrFail($order->id);

            if ($order->escrow_status !== 'held') {
                return;
            }

            WalletLedgerService::creditUserAccount(
                $seller,
                $net,
                'escrow_release',
                'Payout for order '.$order->public_id.' (after platform fee)',
                $key,
                $order->id,
                $order->public_id,
            );

            $order->escrow_status = 'released';
            $order->save();

            $pr = PickupRequest::query()->where('order_id', $order->id)->first();
            if ($pr !== null && $pr->receipt_id === null) {
                $rid = 'rec-'.strtolower((string) Str::ulid());
                $pr->receipt_id = $rid;
                $pr->receipt_issued_at = now();
                $pr->save();
                $order->receipt_id = $pr->receipt_id;
                $order->receipt_issued_at = $pr->receipt_issued_at;
                $order->save();
                $prToNotify = $pr->fresh();
            }

            NotificationWriter::notify(
                $seller->id,
                'Escrow released',
                'You received '.$net.' '.$order->currency.' for order '.$order->public_id.'.',
                'escrowReleased',
            );
        });

        if ($prToNotify !== null) {
            ReceiptEmailNotifier::send($prToNotify);
        }
    }

    /**
     * Return held escrow to the buyer wallet when an order is cancelled (idempotent).
     */
    public static function refundEscrowIfCancelled(Order $order): void
    {
        if ($order->escrow_status !== 'held' || $order->escrow_amount === null) {
            return;
        }

        $buyer = User::query()->find($order->buyer_user_id);
        if ($buyer === null) {
            return;
        }

        $gross = (string) $order->escrow_amount;
        $key = 'escrow-refund-order-'.$order->id;

        DB::transaction(function () use ($order, $buyer, $gross, $key): void {
            /** @var Order $order */
            $order = Order::query()->lockForUpdate()->findOrFail($order->id);

            if ($order->escrow_status !== 'held' || $order->escrow_amount === null) {
                return;
            }

            WalletLedgerService::creditUserAccount(
                $buyer,
                $gross,
                'escrow_refund',
                'Refund for cancelled order '.$order->public_id,
                $key,
                $order->id,
                $order->public_id,
            );

            $order->escrow_status = 'refunded';
            $order->save();

            AuditLogger::recordSystem(
                $buyer,
                'order.escrow_refunded',
                Order::class,
                $order->id,
                ['amount' => $gross],
                RequestFacade::ip(),
            );
        });

        NotificationWriter::notify(
            $buyer->id,
            'Order cancelled',
            'Your payment of '.$gross.' '.$order->currency.' for order '.$order->public_id.' was refunded to your wallet.',
            'escrowRefunded',
        );
    }

    public static function markIntentFailed(PaymentIntent $intent, string $reason): void
    {
        $intent->update([
            'status' => 'failed',
            'raw_payload' => array_merge($intent->raw_payload ?? [], [
                'failure' => $reason,
                'failed_at' => now()->toIso8601String(),
            ]),
        ]);

        NotificationWriter::notify(
            $intent->user_id,
            'Payment failed',
            $reason,
            'paymentFailed',
        );
    }
}
