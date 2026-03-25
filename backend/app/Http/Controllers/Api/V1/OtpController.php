<?php

namespace App\Http\Controllers\Api\V1;

use App\Contracts\SmsSender;
use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Support\PhoneE164;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class OtpController extends Controller
{
    use RespondsWithJson;

    public function __construct(
        private readonly SmsSender $sms,
    ) {}

    public function requestOtp(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'phone' => ['required', 'string', 'max:32'],
        ]);

        $phone = PhoneE164::normalize($validated['phone']);
        if (strlen($phone) < 10) {
            return response()->json(['message' => 'Invalid phone number.'], 422);
        }

        $code = sprintf('%06d', random_int(0, 999_999));
        $hash = hash('sha256', $phone.'|'.$code);

        Cache::put(
            'otp_pending:'.$phone,
            ['hash' => $hash, 'attempts' => 0],
            now()->addMinutes((int) config('waste_bridge.otp.ttl_minutes', 5)),
        );

        $message = sprintf(
            'Your %s verification code is: %s',
            config('app.name'),
            $code,
        );

        try {
            $this->deliverOtp($phone, $message);
        } catch (\Throwable $e) {
            Cache::forget('otp_pending:'.$phone);
            Log::error('otp.delivery_failed', ['phone' => $phone, 'error' => $e->getMessage()]);

            return response()->json([
                'message' => 'Could not send verification SMS. Please try again shortly.',
            ], 503);
        }

        return $this->success([
            'expiresIn' => (int) config('waste_bridge.otp.ttl_minutes', 5) * 60,
            'message' => app()->environment('local')
                ? 'OTP logged for local development.'
                : 'If this number can receive SMS, a verification code was sent.',
        ]);
    }

    public function verifyOtp(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'phone' => ['required', 'string', 'max:32'],
            'code' => ['required', 'string', 'regex:/^[0-9]{6}$/'],
        ]);

        $phone = PhoneE164::normalize($validated['phone']);
        if (strlen($phone) < 10) {
            return response()->json(['message' => 'Invalid phone number.'], 422);
        }

        $expectedHash = hash('sha256', $phone.'|'.$validated['code']);
        $pending = Cache::get('otp_pending:'.$phone);

        if ($pending === null || ! hash_equals((string) ($pending['hash'] ?? ''), $expectedHash)) {
            return response()->json(['message' => 'Invalid or expired code.'], 422);
        }

        Cache::forget('otp_pending:'.$phone);

        $verificationToken = Str::random(48);
        Cache::put(
            'otp_verified:'.$verificationToken,
            $phone,
            now()->addMinutes((int) config('waste_bridge.otp.verification_token_ttl_minutes', 15)),
        );

        return $this->success([
            'verificationToken' => $verificationToken,
            'expiresIn' => (int) config('waste_bridge.otp.verification_token_ttl_minutes', 15) * 60,
            'phone' => $phone,
        ]);
    }

    private function deliverOtp(string $phoneE164, string $message): void
    {
        if (app()->environment('local')) {
            Log::info('otp.delivery', ['phone' => $phoneE164, 'message' => $message]);

            return;
        }

        $this->sms->send($phoneE164, $message);
    }
}
