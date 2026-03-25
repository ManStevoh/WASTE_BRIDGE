<?php

namespace App\Models;

use App\Domain\Enums\MarketplaceOrderStatus;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class Order extends Model
{
    protected $fillable = [
        'public_id',
        'seller_user_id',
        'buyer_user_id',
        'listing_id',
        'status',
        'subtotal_amount',
        'platform_fee_amount',
        'tax_amount',
        'escrow_amount',
        'escrow_status',
        'currency',
        'receipt_id',
        'receipt_issued_at',
    ];

    protected function casts(): array
    {
        return [
            'subtotal_amount' => 'decimal:2',
            'platform_fee_amount' => 'decimal:2',
            'tax_amount' => 'decimal:2',
            'escrow_amount' => 'decimal:2',
            'receipt_issued_at' => 'datetime',
        ];
    }

    public function getRouteKeyName(): string
    {
        return 'public_id';
    }

    protected static function booted(): void
    {
        static::creating(function (Order $row): void {
            if (empty($row->public_id)) {
                $row->public_id = 'ord-'.strtolower((string) Str::ulid());
            }
            if (empty($row->status)) {
                $row->status = MarketplaceOrderStatus::Created->value;
            }
        });
    }

    public function seller(): BelongsTo
    {
        return $this->belongsTo(User::class, 'seller_user_id');
    }

    public function buyer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'buyer_user_id');
    }

    public function listing(): BelongsTo
    {
        return $this->belongsTo(WasteListing::class, 'listing_id');
    }

    public function pickupRequests(): HasMany
    {
        return $this->hasMany(PickupRequest::class, 'order_id');
    }

    /**
     * @return array<string, mixed>
     */
    public function toSummaryArray(): array
    {
        return [
            'id' => $this->public_id,
            'status' => $this->status,
            'sellerUserId' => $this->seller?->public_id,
            'buyerUserId' => $this->buyer?->public_id,
            'listingId' => $this->listing?->public_id,
            'subtotalAmount' => $this->subtotal_amount !== null ? (float) $this->subtotal_amount : null,
            'escrowAmount' => $this->escrow_amount !== null ? (float) $this->escrow_amount : null,
            'escrowStatus' => $this->escrow_status,
            'currency' => $this->currency,
            'createdAt' => $this->created_at?->toIso8601String(),
            'receiptId' => $this->receipt_id,
            'receiptIssuedAt' => $this->receipt_issued_at?->toIso8601String(),
        ];
    }

    /**
     * Order + linked pickup request/job for marketplace clients (Phase 3).
     *
     * @return array<string, mixed>
     */
    public function toDetailArray(): array
    {
        $this->loadMissing(['seller', 'buyer', 'listing', 'pickupRequests.pickupJob']);

        $pr = $this->pickupRequests->first();
        $job = $pr?->pickupJob;

        return array_merge($this->toSummaryArray(), [
            'pickupRequest' => $pr?->toWasteRequestArray(),
            'jobPublicId' => $job?->public_id,
            'jobStatus' => $job?->status,
        ]);
    }
}
