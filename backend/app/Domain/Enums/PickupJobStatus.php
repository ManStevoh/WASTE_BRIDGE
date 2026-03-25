<?php

namespace App\Domain\Enums;

/**
 * Collector job pipeline (operational).
 */
enum PickupJobStatus: string
{
    case Open = 'open';
    case Accepted = 'accepted';
    case Arrived = 'arrived';
    case Picked = 'picked';
    case Delivered = 'delivered';
}
