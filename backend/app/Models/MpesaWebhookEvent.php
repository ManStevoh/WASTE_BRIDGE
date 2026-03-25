<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class MpesaWebhookEvent extends Model
{
    protected $fillable = [
        'idempotency_key',
        'event_type',
        'payload',
        'processing_status',
        'processing_error',
        'processed_at',
    ];

    protected function casts(): array
    {
        return [
            'payload' => 'array',
            'processed_at' => 'datetime',
        ];
    }
}
