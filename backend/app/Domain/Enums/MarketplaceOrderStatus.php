<?php

namespace App\Domain\Enums;

use App\Support\OrderLifecycle;

/**
 * Commercial / escrow order lifecycle (Phase 1.5).
 *
 * Maps to DB `orders.status` and {@see OrderLifecycle} transitions.
 */
enum MarketplaceOrderStatus: string
{
    case Created = 'created';
    case Accepted = 'accepted';
    case InTransit = 'in_transit';
    case Delivered = 'delivered';
    case Completed = 'completed';
    case Cancelled = 'cancelled';
    case Disputed = 'disputed';
}
