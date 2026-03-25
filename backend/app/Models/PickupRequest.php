<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Str;

class PickupRequest extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'public_id',
        'generator_user_id',
        'assigned_collector_user_id',
        'waste_type',
        'quantity_kg',
        'location',
        'latitude',
        'longitude',
        'status',
        'accepted_at',
        'picked_up_at',
        'completed_at',
        'cancelled_at',
        'scheduled_at',
        'rescheduled_at',
        'suggested_collector_name',
        'estimated_eta_minutes',
        'distance_km',
        'unit_price_per_kg',
        'total_amount',
        'payment_status',
        'before_pickup_photo_url',
        'after_pickup_photo_url',
        'proof_latitude',
        'proof_longitude',
        'generator_rating',
        'collector_rating',
        'is_disputed',
        'dispute_reason',
        'receipt_id',
        'receipt_issued_at',
        'co2_saved_kg',
        'listing_id',
        'order_id',
    ];

    protected function casts(): array
    {
        return [
            'quantity_kg' => 'float',
            'latitude' => 'float',
            'longitude' => 'float',
            'accepted_at' => 'datetime',
            'picked_up_at' => 'datetime',
            'completed_at' => 'datetime',
            'cancelled_at' => 'datetime',
            'scheduled_at' => 'datetime',
            'rescheduled_at' => 'datetime',
            'distance_km' => 'float',
            'unit_price_per_kg' => 'float',
            'total_amount' => 'float',
            'generator_rating' => 'float',
            'collector_rating' => 'float',
            'is_disputed' => 'boolean',
            'receipt_issued_at' => 'datetime',
            'co2_saved_kg' => 'float',
            'proof_latitude' => 'float',
            'proof_longitude' => 'float',
        ];
    }

    public function getRouteKeyName(): string
    {
        return 'public_id';
    }

    protected static function booted(): void
    {
        static::creating(function (PickupRequest $row): void {
            if (empty($row->public_id)) {
                $row->public_id = 'wr-'.strtolower((string) Str::ulid());
            }
        });
    }

    public function generator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'generator_user_id');
    }

    public function assignedCollector(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_collector_user_id');
    }

    public function pickupJob(): HasOne
    {
        return $this->hasOne(PickupJob::class, 'pickup_request_id');
    }

    public function listing(): BelongsTo
    {
        return $this->belongsTo(WasteListing::class, 'listing_id');
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }

    /**
     * @return array<string, mixed>
     */
    public function toWasteRequestArray(): array
    {
        return [
            'id' => $this->public_id,
            'wasteType' => $this->waste_type,
            'quantityKg' => (float) $this->quantity_kg,
            'location' => $this->location,
            'status' => $this->status,
            'createdAt' => $this->created_at?->toIso8601String(),
            'acceptedAt' => $this->accepted_at?->toIso8601String(),
            'pickedUpAt' => $this->picked_up_at?->toIso8601String(),
            'completedAt' => $this->completed_at?->toIso8601String(),
            'cancelledAt' => $this->cancelled_at?->toIso8601String(),
            'suggestedCollectorName' => $this->suggested_collector_name,
            'estimatedEtaMinutes' => $this->estimated_eta_minutes,
            'beforePickupPhotoUrl' => $this->before_pickup_photo_url,
            'afterPickupPhotoUrl' => $this->after_pickup_photo_url,
            'proofLatitude' => $this->proof_latitude !== null ? (float) $this->proof_latitude : null,
            'proofLongitude' => $this->proof_longitude !== null ? (float) $this->proof_longitude : null,
            'generatorRating' => $this->generator_rating,
            'collectorRating' => $this->collector_rating,
            'scheduledAt' => $this->scheduled_at?->toIso8601String(),
            'rescheduledAt' => $this->rescheduled_at?->toIso8601String(),
            'distanceKm' => $this->distance_km !== null ? (float) $this->distance_km : null,
            'unitPricePerKg' => $this->unit_price_per_kg !== null ? (float) $this->unit_price_per_kg : null,
            'totalAmount' => $this->total_amount !== null ? (float) $this->total_amount : null,
            'paymentStatus' => $this->payment_status,
            'isDisputed' => $this->is_disputed,
            'disputeReason' => $this->dispute_reason,
            'receiptId' => $this->receipt_id,
            'receiptIssuedAt' => $this->receipt_issued_at?->toIso8601String(),
            'co2SavedKg' => (float) $this->co2_saved_kg,
            'listingId' => $this->listing?->public_id,
            'orderId' => $this->order?->public_id,
            'collectorPublicId' => $this->assignedCollector?->public_id,
        ];
    }
}
