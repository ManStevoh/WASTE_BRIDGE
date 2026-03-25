<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class ListingBid extends Model
{
    protected $fillable = [
        'public_id',
        'waste_listing_id',
        'user_id',
        'amount',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (ListingBid $row): void {
            if (empty($row->public_id)) {
                $row->public_id = 'bid-'.strtolower((string) Str::ulid());
            }
        });
    }

    public function listing(): BelongsTo
    {
        return $this->belongsTo(WasteListing::class, 'waste_listing_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
