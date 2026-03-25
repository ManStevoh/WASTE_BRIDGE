<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Rating extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'pickup_request_id',
        'job_id',
        'rater_user_id',
        'ratee_user_id',
        'score',
        'comment',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'score' => 'float',
            'created_at' => 'datetime',
        ];
    }

    public function pickupRequest(): BelongsTo
    {
        return $this->belongsTo(PickupRequest::class, 'pickup_request_id');
    }

    public function job(): BelongsTo
    {
        return $this->belongsTo(PickupJob::class, 'job_id');
    }

    public function rater(): BelongsTo
    {
        return $this->belongsTo(User::class, 'rater_user_id');
    }

    public function ratee(): BelongsTo
    {
        return $this->belongsTo(User::class, 'ratee_user_id');
    }
}
