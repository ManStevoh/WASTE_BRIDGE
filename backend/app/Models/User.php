<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Str;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable, SoftDeletes;

    protected $fillable = [
        'public_id',
        'name',
        'email',
        'phone',
        'password',
        'role',
        'kyc_status',
        'is_verified',
        'subscription_plan',
        'referral_code',
        'referred_by_user_id',
        'locale',
        'collector_available',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_verified' => 'boolean',
            'collector_available' => 'boolean',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (User $user): void {
            if (empty($user->public_id)) {
                $user->public_id = (string) Str::ulid();
            }
        });

        static::created(function (User $user): void {
            Wallet::query()->firstOrCreate(
                ['user_id' => $user->id],
                ['currency' => 'KES', 'balance' => 0],
            );
        });
    }

    /**
     * @return array<string, mixed>
     */
    public function toAppUserArray(): array
    {
        return [
            'id' => $this->public_id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'role' => $this->role,
            'kycStatus' => $this->kyc_status,
            'isVerified' => $this->is_verified,
            'subscriptionPlan' => $this->subscription_plan,
            'referralCode' => $this->referral_code,
            'collectorAvailable' => $this->role === 'collector'
                ? (bool) $this->collector_available
                : null,
        ];
    }

    public function wallet(): HasOne
    {
        return $this->hasOne(Wallet::class);
    }

    /**
     * @return HasMany<AppNotification, $this>
     */
    public function appNotifications(): HasMany
    {
        return $this->hasMany(AppNotification::class);
    }

    public function pickupRequests(): HasMany
    {
        return $this->hasMany(PickupRequest::class, 'generator_user_id');
    }

    /**
     * @return HasMany<KycSubmission, $this>
     */
    public function kycSubmissions(): HasMany
    {
        return $this->hasMany(KycSubmission::class);
    }
}
