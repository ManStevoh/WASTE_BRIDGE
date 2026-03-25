<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\AuditLogger;
use App\Services\RefreshTokenService;
use App\Support\PhoneE164;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class AuthController extends Controller
{
    use RespondsWithJson;

    public function __construct(
        private readonly RefreshTokenService $refreshTokens,
    ) {}

    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8'],
            'role' => ['required', 'string', Rule::in(['generator', 'collector', 'recycler'])],
            'phone' => ['nullable', 'required_with:phoneVerificationToken', 'string', 'max:32'],
            'phoneVerificationToken' => ['nullable', 'required_with:phone', 'string', 'max:128'],
        ]);

        $phone = isset($validated['phone']) ? PhoneE164::normalize($validated['phone']) : null;
        if ($phone !== null && $phone !== '' && ! empty($validated['phoneVerificationToken'])) {
            $cached = Cache::get('otp_verified:'.$validated['phoneVerificationToken']);
            if ($cached !== $phone) {
                return response()->json([
                    'message' => 'Invalid or expired phone verification.',
                ], 422);
            }
            Cache::forget('otp_verified:'.$validated['phoneVerificationToken']);
        }

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => $validated['password'],
            'role' => $validated['role'],
            'phone' => $phone,
        ]);

        $user->tokens()->delete();
        $token = $user->createToken('mobile')->plainTextToken;
        $refresh = $this->refreshTokens->issue($user);

        AuditLogger::record($request, $user, 'auth.register', User::class, $user->id);

        return $this->success([
            'access_token' => $token,
            'token_type' => 'Bearer',
            'refresh_token' => $refresh['plain'],
            'refresh_expires_at' => $refresh['expires_at']->toIso8601String(),
            'user' => $user->toAppUserArray(),
        ]);
    }

    public function login(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
            'role' => ['required', 'string', Rule::in(['generator', 'collector', 'recycler', 'admin'])],
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (! $user || ! Hash::check($validated['password'], $user->password)) {
            return response()->json([
                'message' => 'Invalid credentials.',
            ], 401);
        }

        if ($user->role !== $validated['role']) {
            return response()->json([
                'message' => 'Role does not match this account.',
            ], 403);
        }

        $this->refreshTokens->revokeAllForUser($user);
        $user->tokens()->delete();
        $token = $user->createToken('mobile')->plainTextToken;
        $refresh = $this->refreshTokens->issue($user);

        AuditLogger::record($request, $user, 'auth.login', User::class, $user->id);

        return $this->success([
            'access_token' => $token,
            'token_type' => 'Bearer',
            'refresh_token' => $refresh['plain'],
            'refresh_expires_at' => $refresh['expires_at']->toIso8601String(),
            'user' => $user->toAppUserArray(),
        ]);
    }

    public function refresh(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'refresh_token' => ['required', 'string', 'min:32'],
        ]);

        $pair = $this->refreshTokens->rotate($validated['refresh_token']);

        if ($pair === null) {
            return response()->json([
                'message' => 'Invalid or expired refresh token.',
            ], 401);
        }

        AuditLogger::record($request, $pair['user'], 'auth.token_refreshed', User::class, $pair['user']->id);

        return $this->success([
            'access_token' => $pair['access_token'],
            'token_type' => 'Bearer',
            'refresh_token' => $pair['refresh_token'],
            'refresh_expires_at' => $pair['refresh_expires_at'],
            'user' => $pair['user']->toAppUserArray(),
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        return $this->success($request->user()->toAppUserArray());
    }

    public function updateMe(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:32'],
            'collectorAvailable' => ['sometimes', 'boolean'],
        ]);

        if (array_key_exists('collectorAvailable', $validated) && $user->role !== 'collector') {
            return response()->json(['message' => 'Only collectors can set availability.'], 403);
        }

        $updates = [];
        if (isset($validated['name'])) {
            $updates['name'] = $validated['name'];
        }
        if (array_key_exists('phone', $validated)) {
            $raw = $validated['phone'];
            $updates['phone'] = ($raw !== null && $raw !== '')
                ? PhoneE164::normalize($raw)
                : null;
        }
        if (isset($validated['collectorAvailable'])) {
            $updates['collector_available'] = $validated['collectorAvailable'];
        }

        if ($updates !== []) {
            $user->update($updates);
        }

        return $this->success($user->fresh()->toAppUserArray());
    }

    public function logout(Request $request): JsonResponse
    {
        $user = $request->user();
        AuditLogger::record($request, $user, 'auth.logout', User::class, $user->id);
        $user->currentAccessToken()->delete();

        return $this->success(null);
    }

    public function logoutAll(Request $request): JsonResponse
    {
        $user = $request->user();
        AuditLogger::record($request, $user, 'auth.logout_all', User::class, $user->id);
        $user->tokens()->delete();
        $this->refreshTokens->revokeAllForUser($user);

        return $this->success(null);
    }
}
