<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\ListingBid;
use App\Models\WasteListing;
use App\Services\AuctionListingService;
use App\Services\AuditLogger;
use App\Services\NotificationWriter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MarketplaceBidController extends Controller
{
    use RespondsWithJson;

    public function store(Request $request, WasteListing $wasteListing): JsonResponse
    {
        $user = $request->user();

        AuctionListingService::closeExpiredForListing($wasteListing);
        $wasteListing->refresh();

        if ($wasteListing->listing_mode !== 'auction') {
            return response()->json(['message' => 'This listing is not an auction.'], 422);
        }

        if ($wasteListing->status !== 'active' || $wasteListing->auction_status !== 'open') {
            return response()->json(['message' => 'This auction is not accepting bids.'], 422);
        }

        if ($wasteListing->user_id === $user->id) {
            return response()->json(['message' => 'You cannot bid on your own listing.'], 422);
        }

        if ($wasteListing->auction_ends_at === null || $wasteListing->auction_ends_at->isPast()) {
            return response()->json(['message' => 'This auction has ended.'], 422);
        }

        $validated = $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01'],
        ]);

        $amount = round((float) $validated['amount'], 2);
        $increment = max(0.01, (float) config('waste_bridge.auctions.min_increment_kes', 10));

        $starting = (float) ($wasteListing->starting_bid ?? 0);
        $current = $wasteListing->current_bid_amount !== null ? (float) $wasteListing->current_bid_amount : null;

        $minBid = $current === null
            ? $starting
            : round($current + $increment, 2);

        if ($amount < $minBid - 0.0001) {
            return response()->json([
                'message' => 'Bid too low.',
                'minBidAmount' => $minBid,
            ], 422);
        }

        $bid = ListingBid::query()->create([
            'waste_listing_id' => $wasteListing->id,
            'user_id' => $user->id,
            'amount' => (string) $amount,
        ]);

        $wasteListing->current_bid_amount = (string) $amount;
        $wasteListing->current_highest_bidder_id = $user->id;
        $wasteListing->save();

        AuditLogger::record($request, $user, 'marketplace.bid', WasteListing::class, $wasteListing->id, [
            'amount' => $amount,
            'bid_public_id' => $bid->public_id,
        ]);

        $seller = $wasteListing->seller;
        if ($seller !== null) {
            NotificationWriter::notify(
                $seller->id,
                'New bid',
                'Your auction '.$wasteListing->public_id.' received a bid of '.$amount.' KES.',
                'auctionBid',
            );
        }

        $wasteListing->load('seller');

        return $this->success([
            'bid' => [
                'publicId' => $bid->public_id,
                'amount' => $amount,
                'createdAt' => $bid->created_at?->toIso8601String(),
            ],
            'listing' => $wasteListing->toMarketplaceArray(),
        ]);
    }
}
