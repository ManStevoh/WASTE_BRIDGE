<?php

namespace App\Services;

use App\Mail\ReceiptIssuedMail;
use App\Models\PickupRequest;
use Illuminate\Support\Facades\Mail;

final class ReceiptEmailNotifier
{
    public static function send(PickupRequest $pickupRequest): void
    {
        if (! config('waste_bridge.receipts.email_enabled')) {
            return;
        }

        if ($pickupRequest->receipt_id === null) {
            return;
        }

        $pickupRequest->loadMissing(['generator', 'order.buyer', 'order.seller']);

        $order = $pickupRequest->order;
        $url = url('/api/v1/receipts/'.$pickupRequest->receipt_id);

        $emails = array_unique(array_filter([
            $pickupRequest->generator?->email,
            $order?->buyer?->email,
            $order?->seller?->email,
        ]));

        foreach ($emails as $email) {
            Mail::to($email)->send(new ReceiptIssuedMail($pickupRequest, $url));
        }
    }
}
