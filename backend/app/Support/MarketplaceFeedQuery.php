<?php

namespace App\Support;

use App\Models\WasteListing;
use App\Services\AuctionListingService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Phase 3 marketplace listing query: filters, distance, sort modes.
 *
 * @param  Builder<WasteListing>  $query
 */
final class MarketplaceFeedQuery
{
    /** SQLite-safe line total for sorting/filtering. */
    private const EFFECTIVE_PRICE_SQL = '(CASE '
        ."WHEN waste_listings.listing_mode = 'auction' THEN COALESCE(waste_listings.current_bid_amount, waste_listings.starting_bid, 0) "
        .'WHEN waste_listings.total_price IS NOT NULL THEN waste_listings.total_price '
        .'ELSE (waste_listings.unit_price_per_kg * waste_listings.quantity_kg) END)';

    /**
     * @param  Builder<WasteListing>  $query
     */
    public static function apply(Builder $query, Request $request): void
    {
        AuctionListingService::closeExpiredBatch();

        $query->where('waste_listings.status', 'active');

        $mode = $request->query('listingMode') ?? $request->query('listing_mode');
        if (is_string($mode) && $mode !== '') {
            if (! in_array($mode, ['fixed_price', 'bulk_contract', 'auction'], true)) {
                throw ValidationException::withMessages([
                    'listingMode' => ['Invalid listingMode. Use fixed_price, bulk_contract, or auction.'],
                ]);
            }
            $query->where('waste_listings.listing_mode', $mode);
            if ($mode === 'auction') {
                $query->whereIn('waste_listings.auction_status', ['open', 'ended']);
            }
        } else {
            $query->where(function (Builder $q): void {
                $q->whereIn('waste_listings.listing_mode', ['fixed_price', 'bulk_contract'])
                    ->orWhere(function (Builder $q2): void {
                        $q2->where('waste_listings.listing_mode', 'auction')
                            ->whereIn('waste_listings.auction_status', ['open', 'ended']);
                    });
            });
        }

        $wasteType = $request->query('wasteType') ?? $request->query('waste_type');
        if (is_string($wasteType) && $wasteType !== '') {
            $query->where('waste_listings.waste_type', $wasteType);
        }

        $minPrice = $request->query('minPrice') ?? $request->query('min_price');
        if ($minPrice !== null && $minPrice !== '') {
            $min = (float) $minPrice;
            $query->whereRaw('('.self::EFFECTIVE_PRICE_SQL.') >= CAST(? AS REAL)', [$min]);
        }
        $maxPrice = $request->query('maxPrice') ?? $request->query('max_price');
        if ($maxPrice !== null && $maxPrice !== '') {
            $max = (float) $maxPrice;
            $query->whereRaw('('.self::EFFECTIVE_PRICE_SQL.') <= CAST(? AS REAL)', [$max]);
        }

        if ($request->filled('minQuantityKg')) {
            $query->where('waste_listings.quantity_kg', '>=', (float) $request->query('minQuantityKg'));
        }
        if ($request->filled('maxQuantityKg')) {
            $query->where('waste_listings.quantity_kg', '<=', (float) $request->query('maxQuantityKg'));
        }

        $sort = (string) $request->query('sort', 'newest');

        if ($sort === 'nearest') {
            $lat = $request->query('latitude');
            $lng = $request->query('longitude');
            if ($lat === null || $lat === '' || $lng === null || $lng === '') {
                throw ValidationException::withMessages([
                    'latitude' => ['latitude and longitude are required when sort=nearest.'],
                    'longitude' => ['latitude and longitude are required when sort=nearest.'],
                ]);
            }
            $latF = (float) $lat;
            $lngF = (float) $lng;

            $query->whereNotNull('waste_listings.latitude')->whereNotNull('waste_listings.longitude');

            if ($request->filled('maxDistanceKm')) {
                GeoHaversine::whereWithinKm(
                    $query,
                    'waste_listings.latitude',
                    'waste_listings.longitude',
                    $latF,
                    $lngF,
                    (float) $request->query('maxDistanceKm'),
                );
            }

            GeoHaversine::orderByDistanceKm($query, 'waste_listings.latitude', 'waste_listings.longitude', $latF, $lngF, 'asc');
            $query->orderByDesc('waste_listings.id');

            return;
        }

        if ($request->filled('maxDistanceKm')) {
            $lat = $request->query('latitude');
            $lng = $request->query('longitude');
            if ($lat === null || $lat === '' || $lng === null || $lng === '') {
                throw ValidationException::withMessages([
                    'latitude' => ['latitude and longitude are required when maxDistanceKm is set.'],
                    'longitude' => ['longitude is required when maxDistanceKm is set.'],
                ]);
            }
            $query->whereNotNull('waste_listings.latitude')->whereNotNull('waste_listings.longitude');
            GeoHaversine::whereWithinKm(
                $query,
                'waste_listings.latitude',
                'waste_listings.longitude',
                (float) $lat,
                (float) $lng,
                (float) $request->query('maxDistanceKm'),
            );
        }

        match ($sort) {
            'price_desc' => $query->orderByRaw(self::EFFECTIVE_PRICE_SQL.' DESC'),
            'price_asc' => $query->orderByRaw(self::EFFECTIVE_PRICE_SQL.' ASC'),
            'newest' => $query->latest('waste_listings.created_at'),
            default => throw ValidationException::withMessages([
                'sort' => ['Invalid sort. Use newest, price_desc, price_asc, or nearest.'],
            ]),
        };
    }
}
