<?php

namespace App\Http\Controllers\Api\V1;

use App\Domain\Enums\MarketplaceOrderStatus;
use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\PickupJob;
use App\Models\PickupRequest;
use App\Models\WasteListing;
use App\Services\AuctionListingService;
use App\Services\AuditLogger;
use App\Services\NotificationWriter;
use App\Support\OrderLifecycle;
use App\Support\PickupPricing;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Recycler (buyer) purchases another user's marketplace listing — creates order + pickup pipeline.
 */
class MarketplacePurchaseController extends Controller
{
    use RespondsWithJson;

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'listingPublicId' => ['required', 'string', 'max:64'],
            'quantityKg' => ['nullable', 'numeric', 'min:0.001'],
        ]);

        $listing = WasteListing::query()
            ->where('public_id', $validated['listingPublicId'])
            ->first();

        if ($listing === null) {
            return response()->json(['message' => 'Listing not found.'], 404);
        }

        if ($listing->user_id === $user->id) {
            return response()->json(['message' => 'You cannot purchase your own listing.'], 422);
        }

        if ($listing->status !== 'active') {
            return response()->json(['message' => 'Listing is not available for purchase.'], 422);
        }

        AuctionListingService::closeExpiredForListing($listing);
        $listing->refresh();

        $mode = $listing->listing_mode;

        if ($mode === 'auction') {
            if ($listing->auction_status !== 'ended') {
                return response()->json([
                    'message' => 'You can only purchase after the auction ends and you are the winning bidder.',
                ], 422);
            }
            if ($listing->current_highest_bidder_id !== $user->id) {
                return response()->json(['message' => 'Only the winning bidder can complete this purchase.'], 422);
            }
            if ($listing->current_bid_amount === null) {
                return response()->json(['message' => 'Listing has no winning bid.'], 422);
            }
            $subtotal = round((float) $listing->current_bid_amount, 2);
            $purchaseQty = (float) $listing->quantity_kg;
        } elseif ($mode === 'bulk_contract') {
            if ($validated['quantityKg'] === null) {
                return response()->json(['message' => 'quantityKg is required for bulk listings.'], 422);
            }
            $purchaseQty = (float) $validated['quantityKg'];
            $min = (float) ($listing->bulk_min_quantity_kg ?? 0);
            $max = (float) $listing->quantity_kg;
            if ($purchaseQty < $min || $purchaseQty > $max) {
                return response()->json([
                    'message' => 'quantityKg must be between the bulk minimum and listed quantity.',
                    'minQuantityKg' => $min,
                    'maxQuantityKg' => $max,
                ], 422);
            }
            if ($listing->unit_price_per_kg !== null) {
                $subtotal = round($purchaseQty * (float) $listing->unit_price_per_kg, 2);
            } elseif ($listing->total_price !== null) {
                $subtotal = round($purchaseQty / $max * (float) $listing->total_price, 2);
            } else {
                return response()->json(['message' => 'Listing has no price.'], 422);
            }
        } else {
            if ($mode !== 'fixed_price') {
                return response()->json(['message' => 'Listing is not available for purchase.'], 422);
            }
            $subtotal = $listing->total_price;
            if ($subtotal === null && $listing->unit_price_per_kg !== null) {
                $subtotal = round((float) $listing->unit_price_per_kg * (float) $listing->quantity_kg, 2);
            }
            if ($subtotal === null) {
                return response()->json(['message' => 'Listing has no price.'], 422);
            }
            $purchaseQty = (float) $listing->quantity_kg;
        }

        $blocking = [
            MarketplaceOrderStatus::Created->value,
            MarketplaceOrderStatus::Accepted->value,
            MarketplaceOrderStatus::InTransit->value,
            MarketplaceOrderStatus::Delivered->value,
            MarketplaceOrderStatus::Disputed->value,
        ];

        $already = Order::query()
            ->where('listing_id', $listing->id)
            ->whereIn('status', $blocking)
            ->exists();

        if ($already) {
            return response()->json([
                'message' => 'This listing already has an active order. Try again after it completes.',
            ], 422);
        }

        $wasteType = $listing->waste_type;
        $quantity = $purchaseQty;
        $location = $listing->location_text;

        $distanceKm = PickupPricing::estimateDistanceKm($location);
        $unitPrice = PickupPricing::unitPricePerKg($wasteType, $distanceKm);
        $totalAmount = round($unitPrice * $quantity, 2);
        $co2 = PickupPricing::co2SavedKg($wasteType, $quantity);
        $suggested = PickupPricing::suggestCollectorName($wasteType, $quantity);
        $earning = PickupPricing::collectorEarning($totalAmount);

        $sellerId = $listing->user_id;
        $isAuction = $mode === 'auction';

        $pickup = DB::transaction(function () use (
            $user,
            $listing,
            $subtotal,
            $wasteType,
            $quantity,
            $location,
            $distanceKm,
            $unitPrice,
            $totalAmount,
            $co2,
            $suggested,
            $earning,
            $sellerId,
            $isAuction,
        ): PickupRequest {
            $order = Order::create([
                'seller_user_id' => $sellerId,
                'buyer_user_id' => $user->id,
                'listing_id' => $listing->id,
                'status' => MarketplaceOrderStatus::Created->value,
                'subtotal_amount' => $subtotal,
                'currency' => 'KES',
            ]);

            $pr = PickupRequest::create([
                'generator_user_id' => $sellerId,
                'listing_id' => $listing->id,
                'order_id' => $order->id,
                'waste_type' => $wasteType,
                'quantity_kg' => $quantity,
                'location' => $location,
                'latitude' => $listing->latitude,
                'longitude' => $listing->longitude,
                'status' => 'pending',
                'scheduled_at' => null,
                'distance_km' => $distanceKm,
                'unit_price_per_kg' => $unitPrice,
                'total_amount' => $totalAmount,
                'payment_status' => 'unpaid',
                'suggested_collector_name' => $suggested,
                'estimated_eta_minutes' => 25,
                'co2_saved_kg' => $co2,
            ]);

            $job = PickupJob::create([
                'pickup_request_id' => $pr->id,
                'order_id' => $order->id,
                'pickup_location' => $pr->location,
                'waste_type' => $pr->waste_type,
                'quantity_kg' => $pr->quantity_kg,
                'earning' => $earning,
                'status' => 'open',
            ]);

            OrderLifecycle::syncLinkedOrder($job);

            if ($isAuction) {
                $listing->status = 'inactive';
                $listing->auction_status = 'purchased';
                $listing->save();
            }

            return $pr->fresh();
        });

        $order = Order::query()
            ->with(['seller', 'buyer', 'listing', 'pickupRequests.pickupJob'])
            ->findOrFail($pickup->order_id);

        NotificationWriter::notify(
            $user->id,
            'Order created',
            'Pay '.$subtotal.' KES to fund order '.$order->public_id.'.',
            'orderCreated',
        );

        NotificationWriter::notify(
            $sellerId,
            'Listing purchased',
            'Your listing '.$listing->public_id.' was purchased. A pickup job is open.',
            'orderFunded',
        );

        AuditLogger::record($request, $user, 'marketplace.purchase', WasteListing::class, $listing->id, [
            'order_public_id' => $order->public_id,
        ]);

        return $this->success([
            'order' => $order->toDetailArray(),
        ]);
    }
}
