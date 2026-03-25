<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\WasteListing;
use App\Services\AuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class WasteListingController extends Controller
{
    use RespondsWithJson;

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        $base = $request->validate([
            'wasteType' => ['required', 'string', 'max:64'],
            'quantityKg' => ['required', 'numeric', 'min:0.001'],
            'locationText' => ['required', 'string', 'max:512'],
            'unitPricePerKg' => ['nullable', 'numeric', 'min:0'],
            'totalPrice' => ['nullable', 'numeric', 'min:0'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
            'listingMode' => ['required', 'string', Rule::in(['fixed_price', 'auction', 'bulk_contract'])],
        ]);

        $mode = $base['listingMode'];

        $auctionEndsAt = null;
        $startingBid = null;
        $reservePrice = null;
        $bulkMin = null;

        if ($mode === 'auction') {
            $extra = $request->validate([
                'auctionEndsAt' => ['required', 'date', 'after:now'],
                'startingBid' => ['required', 'numeric', 'min:0.01'],
                'reservePrice' => ['nullable', 'numeric', 'min:0'],
            ]);
            $auctionEndsAt = new \DateTimeImmutable($extra['auctionEndsAt']);
            $startingBid = (float) $extra['startingBid'];
            $reservePrice = isset($extra['reservePrice']) ? (float) $extra['reservePrice'] : null;
        }

        if ($mode === 'bulk_contract') {
            $extra = $request->validate([
                'bulkMinQuantityKg' => ['required', 'numeric', 'min:0.001'],
            ]);
            $bulkMin = (float) $extra['bulkMinQuantityKg'];
            if ($bulkMin > (float) $base['quantityKg']) {
                return response()->json([
                    'message' => 'bulkMinQuantityKg cannot exceed quantityKg.',
                ], 422);
            }
        }

        $quantity = (float) $base['quantityKg'];
        $unit = isset($base['unitPricePerKg']) ? (float) $base['unitPricePerKg'] : null;
        $total = isset($base['totalPrice']) ? (float) $base['totalPrice'] : null;

        if ($mode === 'fixed_price' || $mode === 'bulk_contract') {
            if ($total === null && $unit === null) {
                return response()->json([
                    'message' => 'Provide unitPricePerKg and/or totalPrice for this listing.',
                ], 422);
            }
        }

        if ($total === null && $unit !== null && $mode !== 'auction') {
            $total = round($unit * $quantity, 2);
        }

        $listing = WasteListing::create([
            'user_id' => $user->id,
            'waste_type' => $base['wasteType'],
            'quantity_kg' => $quantity,
            'unit_price_per_kg' => $mode === 'auction' ? null : $unit,
            'total_price' => $mode === 'auction' ? null : $total,
            'location_text' => $base['locationText'],
            'latitude' => $base['latitude'] ?? null,
            'longitude' => $base['longitude'] ?? null,
            'status' => 'active',
            'listing_mode' => $mode,
            'bulk_min_quantity_kg' => $bulkMin,
            'auction_ends_at' => $auctionEndsAt?->format('Y-m-d H:i:s'),
            'starting_bid' => $startingBid !== null ? (string) $startingBid : null,
            'reserve_price' => $reservePrice !== null ? (string) $reservePrice : null,
            'auction_status' => $mode === 'auction' ? 'open' : null,
        ]);

        $listing->load('seller');

        AuditLogger::record($request, $user, 'waste_listing.created', WasteListing::class, $listing->id);

        return $this->success($listing->toMarketplaceArray());
    }
}
