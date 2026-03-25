<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class WalletLedgerEntry extends Model
{
    public $timestamps = false;

    protected $table = 'wallet_ledger_entries';

    protected $fillable = [
        'public_id',
        'wallet_id',
        'user_id',
        'amount',
        'entry_type',
        'status',
        'category',
        'material',
        'quantity_kg',
        'description',
        'balance_after',
        'pickup_request_id',
        'pickup_job_id',
        'order_id',
        'idempotency_key',
        'provider_reference',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'quantity_kg' => 'decimal:3',
            'balance_after' => 'decimal:2',
            'created_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (WalletLedgerEntry $row): void {
            if (empty($row->public_id)) {
                $row->public_id = 't-'.strtolower((string) Str::ulid());
            }
        });
    }

    public function wallet(): BelongsTo
    {
        return $this->belongsTo(Wallet::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }

    /**
     * @return array<string, mixed>
     */
    public function toAppTransactionArray(): array
    {
        $type = $this->entry_type === 'debit' ? 'debit' : 'credit';

        return [
            'id' => $this->public_id,
            'material' => $this->material ?? '',
            'quantityKg' => $this->quantity_kg !== null ? (float) $this->quantity_kg : 0.0,
            'amount' => (float) $this->amount,
            'createdAt' => $this->created_at?->toIso8601String(),
            'type' => $type,
            'description' => $this->description,
            'balanceAfter' => $this->balance_after !== null ? (float) $this->balance_after : null,
        ];
    }
}
