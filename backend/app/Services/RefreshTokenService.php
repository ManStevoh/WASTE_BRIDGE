<?php

namespace App\Services;

use App\Models\RefreshToken;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

final class RefreshTokenService
{
    /**
     * @return array{plain: string, expires_at: Carbon}
     */
    public function issue(User $user): array
    {
        $plain = Str::random(64);
        $ttlDays = (int) config('waste_bridge.auth.refresh_token_ttl_days', 30);
        $expires = now()->addDays($ttlDays);

        RefreshToken::query()->create([
            'user_id' => $user->id,
            'token_hash' => hash('sha256', $plain),
            'expires_at' => $expires,
        ]);

        return [
            'plain' => $plain,
            'expires_at' => $expires,
        ];
    }

    /**
     * @return array{user: User, access_token: string, refresh_token: string, refresh_expires_at: string}|null
     */
    public function rotate(string $plainRefreshToken): ?array
    {
        $hash = hash('sha256', $plainRefreshToken);
        $row = RefreshToken::query()
            ->where('token_hash', $hash)
            ->whereNull('revoked_at')
            ->where('expires_at', '>', now())
            ->first();

        if ($row === null) {
            return null;
        }

        $user = $row->user;
        $row->update(['revoked_at' => now()]);

        $user->tokens()->delete();
        $accessToken = $user->createToken('mobile')->plainTextToken;

        $next = $this->issue($user);

        return [
            'user' => $user->fresh(),
            'access_token' => $accessToken,
            'refresh_token' => $next['plain'],
            'refresh_expires_at' => $next['expires_at']->toIso8601String(),
        ];
    }

    public function revokeAllForUser(User $user): void
    {
        RefreshToken::query()->where('user_id', $user->id)->whereNull('revoked_at')->update([
            'revoked_at' => now(),
        ]);
    }
}
