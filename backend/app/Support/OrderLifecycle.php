<?php

namespace App\Support;

use App\Domain\Enums\MarketplaceOrderStatus;
use App\Models\Order;
use App\Models\PickupJob;
use App\Models\PickupRequest;
use App\Services\EscrowService;

/**
 * Documents and enforces the commercial order state machine vs operational pickup/job state.
 *
 * Marketplace: created → accepted → in_transit → delivered → completed (+ cancelled, disputed).
 *
 * @see DOCS/IMPLEMENTATION_PLAN.md Phase 1.5
 */
final class OrderLifecycle
{
    /**
     * @return list<string>
     */
    public static function marketplaceStatuses(): array
    {
        return array_map(fn (MarketplaceOrderStatus $s) => $s->value, MarketplaceOrderStatus::cases());
    }

    /**
     * Whether a direct status change on an order is allowed (admin / system).
     *
     * @return list<string>
     */
    public static function allowedTransitions(MarketplaceOrderStatus $from): array
    {
        return match ($from) {
            MarketplaceOrderStatus::Created => [
                MarketplaceOrderStatus::Accepted->value,
                MarketplaceOrderStatus::Cancelled->value,
            ],
            MarketplaceOrderStatus::Accepted => [
                MarketplaceOrderStatus::InTransit->value,
                MarketplaceOrderStatus::Cancelled->value,
                MarketplaceOrderStatus::Disputed->value,
            ],
            MarketplaceOrderStatus::InTransit => [
                MarketplaceOrderStatus::Delivered->value,
                MarketplaceOrderStatus::Disputed->value,
            ],
            MarketplaceOrderStatus::Delivered => [
                MarketplaceOrderStatus::Completed->value,
                MarketplaceOrderStatus::Disputed->value,
            ],
            MarketplaceOrderStatus::Completed => [],
            MarketplaceOrderStatus::Cancelled => [],
            MarketplaceOrderStatus::Disputed => [
                MarketplaceOrderStatus::Completed->value,
                MarketplaceOrderStatus::Cancelled->value,
            ],
        };
    }

    public static function canTransition(MarketplaceOrderStatus $from, MarketplaceOrderStatus $to): bool
    {
        return in_array($to->value, self::allowedTransitions($from), true);
    }

    /**
     * Derive target marketplace status from operational job + request (when an order is linked).
     */
    public static function deriveMarketplaceStatus(PickupJob $job, PickupRequest $request): ?MarketplaceOrderStatus
    {
        if ($request->is_disputed) {
            return MarketplaceOrderStatus::Disputed;
        }

        return match ($job->status) {
            'open' => MarketplaceOrderStatus::Created,
            'accepted' => MarketplaceOrderStatus::Accepted,
            'arrived', 'picked' => MarketplaceOrderStatus::InTransit,
            'delivered' => $request->payment_status === 'paid'
                ? MarketplaceOrderStatus::Completed
                : MarketplaceOrderStatus::Delivered,
            default => null,
        };
    }

    public static function syncLinkedOrder(PickupJob $job): void
    {
        $job->loadMissing('pickupRequest');
        $request = $job->pickupRequest;

        if ($request === null || $request->order_id === null) {
            return;
        }

        $order = Order::query()->find($request->order_id);
        if ($order === null) {
            return;
        }

        $next = self::deriveMarketplaceStatus($job, $request);
        if ($next === null) {
            EscrowService::releaseEscrowIfDue($order);

            return;
        }

        $current = MarketplaceOrderStatus::tryFrom($order->status);
        if ($current === null) {
            $order->status = $next->value;
            $order->save();
        } elseif ($current !== $next) {
            if (self::canTransition($current, $next)) {
                $order->status = $next->value;
                $order->save();
            } elseif ($next === MarketplaceOrderStatus::Disputed) {
                $order->status = MarketplaceOrderStatus::Disputed->value;
                $order->save();
            }
        }

        EscrowService::releaseEscrowIfDue($order->fresh());
    }
}
