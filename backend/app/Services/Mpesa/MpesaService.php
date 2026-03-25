<?php

namespace App\Services\Mpesa;

use App\Models\PaymentIntent;
use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Safaricom Daraja: OAuth + STK Push. Callback validation is done by matching
 * CheckoutRequestID to {@see PaymentIntent::provider_checkout_id}.
 */
final class MpesaService
{
    public static function isConfigured(): bool
    {
        $c = config('waste_bridge.mpesa');

        return (bool) ($c['enabled'] ?? false)
            && $c['consumer_key'] !== ''
            && $c['consumer_secret'] !== ''
            && $c['shortcode'] !== ''
            && $c['passkey'] !== '';
    }

    public static function callbackUrl(): string
    {
        $explicit = config('waste_bridge.mpesa.callback_url');
        if (is_string($explicit) && $explicit !== '') {
            return $explicit;
        }

        return rtrim((string) config('app.url'), '/').'/api/v1/webhooks/mpesa/callback';
    }

    /**
     * @return array{access_token: string, expires_in: int}
     */
    public static function fetchAccessToken(): array
    {
        $base = rtrim((string) config('waste_bridge.mpesa.base_url'), '/');
        $key = (string) config('waste_bridge.mpesa.consumer_key');
        $secret = (string) config('waste_bridge.mpesa.consumer_secret');
        $timeout = (int) config('waste_bridge.mpesa.timeout_seconds', 30);

        $response = Http::timeout($timeout)
            ->withBasicAuth($key, $secret)
            ->acceptJson()
            ->get($base.'/oauth/v1/generate', ['grant_type' => 'client_credentials']);

        if (! $response->successful()) {
            Log::warning('mpesa.oauth.failed', ['status' => $response->status(), 'body' => $response->body()]);

            throw new RuntimeException('M-Pesa OAuth failed.');
        }

        $data = $response->json();
        if (! is_array($data) || empty($data['access_token'])) {
            throw new RuntimeException('M-Pesa OAuth response missing access_token.');
        }

        return [
            'access_token' => (string) $data['access_token'],
            'expires_in' => (int) ($data['expires_in'] ?? 3600),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public static function initiateStkPush(User $user, PaymentIntent $intent, string $phoneDigits): array
    {
        $amountInt = max(1, (int) round((float) $intent->amount));
        $phone = self::normalizeKenyanMsisdn($phoneDigits);
        $shortcode = (string) config('waste_bridge.mpesa.shortcode');
        $passkey = (string) config('waste_bridge.mpesa.passkey');
        $base = rtrim((string) config('waste_bridge.mpesa.base_url'), '/');
        $timeout = (int) config('waste_bridge.mpesa.timeout_seconds', 30);

        $timestamp = now()->format('YmdHis');
        $password = base64_encode($shortcode.$passkey.$timestamp);

        $token = self::fetchAccessToken()['access_token'];

        $accountRef = substr(preg_replace('/[^A-Za-z0-9]/', '', $intent->public_id) ?: 'WB', 0, 12);

        $body = [
            'BusinessShortCode' => (int) $shortcode,
            'Password' => $password,
            'Timestamp' => $timestamp,
            'TransactionType' => 'CustomerPayBillOnline',
            'Amount' => $amountInt,
            'PartyA' => (int) $phone,
            'PartyB' => (int) $shortcode,
            'PhoneNumber' => (int) $phone,
            'CallBackURL' => self::callbackUrl(),
            'AccountReference' => $accountRef,
            'TransactionDesc' => 'WasteBridge',
        ];

        $response = Http::timeout($timeout)
            ->withToken($token)
            ->acceptJson()
            ->post($base.'/mpesa/stkpush/v1/processrequest', $body);

        $json = $response->json();
        if (! is_array($json)) {
            Log::warning('mpesa.stk.invalid_json', ['body' => $response->body()]);

            throw new RuntimeException('M-Pesa STK response was not JSON.');
        }

        if (! $response->successful()) {
            Log::warning('mpesa.stk.http_error', ['status' => $response->status(), 'json' => $json]);

            throw new RuntimeException((string) ($json['errorMessage'] ?? 'M-Pesa STK request failed.'));
        }

        $inner = $json['ResponseCode'] ?? '';
        if ((string) $inner !== '0') {
            $msg = (string) ($json['CustomerMessage'] ?? $json['errorMessage'] ?? 'STK rejected');

            throw new RuntimeException($msg);
        }

        return [
            'MerchantRequestID' => $json['MerchantRequestID'] ?? null,
            'CheckoutRequestID' => $json['CheckoutRequestID'] ?? null,
            'CustomerMessage' => $json['CustomerMessage'] ?? null,
            'ResponseCode' => $json['ResponseCode'] ?? null,
            'raw' => $json,
        ];
    }

    public static function normalizeKenyanMsisdn(string $input): string
    {
        $digits = preg_replace('/\D+/', '', $input) ?? '';
        if ($digits === '') {
            throw new RuntimeException('Phone number is required for M-Pesa.');
        }

        if (str_starts_with($digits, '0')) {
            $digits = '254'.substr($digits, 1);
        }

        if (str_starts_with($digits, '7') && strlen($digits) === 9) {
            $digits = '254'.$digits;
        }

        if (! str_starts_with($digits, '254') || strlen($digits) < 12) {
            throw new RuntimeException('Use a Kenyan number in international format (e.g. 2547XXXXXXXX).');
        }

        return $digits;
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array{checkout_request_id: ?string, merchant_request_id: ?string, result_code: int, result_desc: string, receipt: ?string, amount: ?string, phone: ?string}
     */
    public static function parseStkCallback(array $payload): array
    {
        $stk = $payload['Body']['stkCallback'] ?? null;
        if (! is_array($stk)) {
            return [
                'checkout_request_id' => null,
                'merchant_request_id' => null,
                'result_code' => -1,
                'result_desc' => 'Invalid callback body',
                'receipt' => null,
                'amount' => null,
                'phone' => null,
            ];
        }

        $meta = [];
        $items = $stk['CallbackMetadata']['Item'] ?? [];
        if (is_array($items)) {
            foreach ($items as $row) {
                if (is_array($row) && isset($row['Name'], $row['Value'])) {
                    $meta[(string) $row['Name']] = $row['Value'];
                }
            }
        }

        return [
            'checkout_request_id' => isset($stk['CheckoutRequestID']) ? (string) $stk['CheckoutRequestID'] : null,
            'merchant_request_id' => isset($stk['MerchantRequestID']) ? (string) $stk['MerchantRequestID'] : null,
            'result_code' => (int) ($stk['ResultCode'] ?? -1),
            'result_desc' => (string) ($stk['ResultDesc'] ?? ''),
            'receipt' => isset($meta['MpesaReceiptNumber']) ? (string) $meta['MpesaReceiptNumber'] : null,
            'amount' => isset($meta['Amount']) ? (string) $meta['Amount'] : null,
            'phone' => isset($meta['PhoneNumber']) ? (string) $meta['PhoneNumber'] : null,
        ];
    }
}
