<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Str;

class WasteListing extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'public_id',
        'user_id',
        'waste_type',
        'quantity_kg',
        'unit_price_per_kg',
        'total_price',
        'location_text',
        'latitude',
        'longitude',
        'status',
        'listing_mode',
        'bulk_min_quantity_kg',
        'auction_ends_at',
        'starting_bid',
        'reserve_price',
        'current_bid_amount',
        'current_highest_bidder_id',
        'auction_status',
    ];

    protected function casts(): array
    {
        return [
            'quantity_kg' => 'float',
            'unit_price_per_kg' => 'float',
            'total_price' => 'float',
            'latitude' => 'float',
            'longitude' => 'float',
            'bulk_min_quantity_kg' => 'float',
            'auction_ends_at' => 'datetime',
            'starting_bid' => 'float',
            'reserve_price' => 'float',
            'current_bid_amount' => 'float',
        ];
    }

    public function getRouteKeyName(): string
    {
        return 'public_id';
    }

    protected static function booted(): void
    {
        static::creating(function (WasteListing $row): void {
            if (empty($row->public_id)) {
                $row->public_id = 'wl-'.strtolower((string) Str::ulid());
            }
        });
    }

    public function seller(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class, 'listing_id');
    }

    /**
     * @return HasMany<ListingBid, $this>
     */
    public function bids(): HasMany
    {
        return $this->hasMany(ListingBid::class, 'waste_listing_id');
    }

    public function currentHighestBidder(): BelongsTo
    {
        return $this->belongsTo(User::class, 'current_highest_bidder_id');
    }

    /**
     * @return array<string, mixed>
     */
    public function toMarketplaceArray(): array
    {
        return [
            'id' => $this->public_id,
            'wasteType' => $this->waste_type,
            'quantityKg' => (float) $this->quantity_kg,
            'unitPricePerKg' => $this->unit_price_per_kg !== null ? (float) $this->unit_price_per_kg : null,
            'totalPrice' => $this->total_price !== null ? (float) $this->total_price : null,
            'locationText' => $this->location_text,
            'latitude' => $this->latitude !== null ? (float) $this->latitude : null,
            'longitude' => $this->longitude !== null ? (float) $this->longitude : null,
            'status' => $this->status,
            'listingMode' => $this->listing_mode,
            'sellerUserId' => $this->seller?->public_id,
            'createdAt' => $this->created_at?->toIso8601String(),
            'bulkMinQuantityKg' => $this->bulk_min_quantity_kg !== null ? (float) $this->bulk_min_quantity_kg : null,
            'auctionEndsAt' => $this->auction_ends_at?->toIso8601String(),
            'startingBid' => $this->starting_bid !== null ? (float) $this->starting_bid : null,
            'reservePrice' => $this->reserve_price !== null ? (float) $this->reserve_price : null,
            'currentBidAmount' => $this->current_bid_amount !== null ? (float) $this->current_bid_amount : null,
            'currentHighestBidderUserId' => $this->currentHighestBidder?->public_id,
            'auctionStatus' => $this->auction_status,
        ];
    }
}
