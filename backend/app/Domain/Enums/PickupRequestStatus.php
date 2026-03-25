<?php

namespace App\Domain\Enums;

/**
 * Operational pickup request states (aligned with API / Flutter).
 */
enum PickupRequestStatus: string
{
    case Pending = 'pending';
    case Accepted = 'accepted';
    case PickedUp = 'pickedUp';
    case Completed = 'completed';
    case Cancelled = 'cancelled';
}
