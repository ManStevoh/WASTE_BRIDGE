<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class AppNotification extends Model
{
    protected $table = 'app_notifications';

    protected $fillable = [
        'public_id',
        'user_id',
        'title',
        'message',
        'type',
        'read_at',
    ];

    protected function casts(): array
    {
        return [
            'read_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (AppNotification $row): void {
            if (empty($row->public_id)) {
                $row->public_id = 'n-'.strtolower((string) Str::ulid());
            }
        });
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * @return array<string, mixed>
     */
    public function toApiArray(): array
    {
        return [
            'id' => $this->public_id,
            'title' => $this->title,
            'message' => $this->message,
            'type' => $this->type,
            'createdAt' => $this->created_at?->toIso8601String(),
        ];
    }
}
