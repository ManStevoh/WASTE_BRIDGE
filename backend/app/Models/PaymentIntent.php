<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class PaymentIntent extends Model
{
    protected $fillable = [
        'public_id',
        'user_id',
        'order_id',
        'amount',
        'currency',
        'provider',
        'provider_checkout_id',
        'status',
        'idempotency_key',
        'raw_payload',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'raw_payload' => 'array',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (PaymentIntent $row): void {
            if (empty($row->public_id)) {
                $row->public_id = 'pi-'.strtolower((string) Str::ulid());
            }
        });
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }

    /**
     * @return array<string, mixed>
     */
    public function toClientArray(): array
    {
        return [
            'paymentIntentId' => $this->public_id,
            'status' => $this->status,
            'amount' => (float) $this->amount,
            'currency' => $this->currency,
            'provider' => $this->provider,
            'providerCheckoutId' => $this->provider_checkout_id,
        ];
    }
}
