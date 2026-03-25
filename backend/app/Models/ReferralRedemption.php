<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ReferralRedemption extends Model
{
    protected $fillable = [
        'referral_id',
        'referee_user_id',
        'reward_ledger_entry_id',
        'idempotency_key',
    ];

    public function referral(): BelongsTo
    {
        return $this->belongsTo(Referral::class, 'referral_id');
    }

    public function referee(): BelongsTo
    {
        return $this->belongsTo(User::class, 'referee_user_id');
    }

    public function rewardLedgerEntry(): BelongsTo
    {
        return $this->belongsTo(WalletLedgerEntry::class, 'reward_ledger_entry_id');
    }
}
