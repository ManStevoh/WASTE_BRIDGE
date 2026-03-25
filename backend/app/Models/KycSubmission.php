<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class KycSubmission extends Model
{
    protected $fillable = [
        'public_id',
        'user_id',
        'status',
        'document_type',
        'storage_path',
        'reviewed_by_user_id',
        'reviewed_at',
        'rejection_reason',
    ];

    protected function casts(): array
    {
        return [
            'reviewed_at' => 'datetime',
        ];
    }

    public function getRouteKeyName(): string
    {
        return 'public_id';
    }

    protected static function booted(): void
    {
        static::creating(function (KycSubmission $row): void {
            if (empty($row->public_id)) {
                $row->public_id = (string) Str::ulid();
            }
        });
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function reviewedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by_user_id');
    }

    /**
     * @return array<string, mixed>
     */
    public function toClientArray(): array
    {
        return [
            'publicId' => $this->public_id,
            'status' => $this->status,
            'documentType' => $this->document_type,
            'createdAt' => $this->created_at?->toIso8601String(),
            'reviewedAt' => $this->reviewed_at?->toIso8601String(),
            'rejectionReason' => $this->rejection_reason,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function toAdminArray(): array
    {
        return [
            ...$this->toClientArray(),
            'userId' => $this->user?->public_id,
            'userEmail' => $this->user?->email,
            'storagePath' => $this->storage_path,
            'reviewedByUserId' => $this->reviewedBy?->public_id,
        ];
    }
}
