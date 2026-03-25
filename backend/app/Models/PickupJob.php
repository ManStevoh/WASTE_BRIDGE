<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class PickupJob extends Model
{
    protected $table = 'pickup_jobs';

    protected $fillable = [
        'public_id',
        'pickup_request_id',
        'collector_user_id',
        'pickup_location',
        'waste_type',
        'quantity_kg',
        'earning',
        'status',
        'order_id',
    ];

    protected function casts(): array
    {
        return [
            'quantity_kg' => 'float',
            'earning' => 'float',
        ];
    }

    public function getRouteKeyName(): string
    {
        return 'public_id';
    }

    protected static function booted(): void
    {
        static::creating(function (PickupJob $row): void {
            if (empty($row->public_id)) {
                $row->public_id = 'job-'.strtolower((string) Str::ulid());
            }
        });
    }

    public function pickupRequest(): BelongsTo
    {
        return $this->belongsTo(PickupRequest::class, 'pickup_request_id');
    }

    public function collector(): BelongsTo
    {
        return $this->belongsTo(User::class, 'collector_user_id');
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }

    /**
     * @return array<string, mixed>
     */
    public function toJobArray(): array
    {
        $pr = $this->pickupRequest;

        return [
            'id' => $this->public_id,
            'requestId' => $pr->public_id,
            'pickupLocation' => $this->pickup_location,
            'wasteType' => $this->waste_type,
            'quantityKg' => (float) $this->quantity_kg,
            'earning' => (float) $this->earning,
            'status' => $this->status,
            'orderId' => $this->order?->public_id,
            'latitude' => $pr->latitude !== null ? (float) $pr->latitude : null,
            'longitude' => $pr->longitude !== null ? (float) $pr->longitude : null,
        ];
    }
}
