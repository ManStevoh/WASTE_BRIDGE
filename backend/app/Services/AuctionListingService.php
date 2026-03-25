<?php

namespace App\Services;

use App\Models\WasteListing;
use Illuminate\Support\Facades\DB;

/**
 * Close expired auctions: no bids → inactive; reserve not met → inactive; else → ended with winner.
 */
final class AuctionListingService
{
    public static function closeExpiredForListing(WasteListing $listing): void
    {
        if ($listing->listing_mode !== 'auction' || $listing->auction_status !== 'open') {
            return;
        }

        if ($listing->auction_ends_at === null || $listing->auction_ends_at->isFuture()) {
            return;
        }

        DB::transaction(function () use ($listing): void {
            /** @var WasteListing $listing */
            $listing = WasteListing::query()->lockForUpdate()->findOrFail($listing->id);

            if ($listing->listing_mode !== 'auction' || $listing->auction_status !== 'open') {
                return;
            }

            if ($listing->auction_ends_at === null || $listing->auction_ends_at->isFuture()) {
                return;
            }

            if ($listing->current_bid_amount === null || $listing->current_highest_bidder_id === null) {
                $listing->auction_status = 'no_sale';
                $listing->status = 'inactive';
                $listing->save();

                return;
            }

            $reserve = $listing->reserve_price;
            if ($reserve !== null && (float) $listing->current_bid_amount < (float) $reserve) {
                $listing->auction_status = 'no_sale';
                $listing->status = 'inactive';
                $listing->save();

                return;
            }

            $listing->auction_status = 'ended';
            $listing->save();
        });
    }

    public static function closeExpiredBatch(): void
    {
        $ids = WasteListing::query()
            ->where('listing_mode', 'auction')
            ->where('auction_status', 'open')
            ->whereNotNull('auction_ends_at')
            ->where('auction_ends_at', '<=', now())
            ->pluck('id');

        foreach ($ids as $id) {
            $l = WasteListing::query()->find($id);
            if ($l !== null) {
                self::closeExpiredForListing($l);
            }
        }
    }
}
