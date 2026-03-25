<?php

namespace App\Services\Mpesa;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Safaricom Daraja B2C (Business → Customer) payout for wallet withdrawals.
 *
 * @see https://developer.safaricom.co.ke/APIs/MpesaB2C
 */
final class MpesaB2cService
{
    public static function isConfigured(): bool
    {
        $c = config('waste_bridge.mpesa_b2c');

        return (bool) ($c['enabled'] ?? false)
            && MpesaService::isConfigured()
            && ($c['initiator_name'] ?? '') !== ''
            && ($c['security_credential'] ?? '') !== ''
            && ($c['result_url'] ?? '') !== ''
            && ($c['timeout_url'] ?? '') !== '';
    }

    /**
     * @return array{ConversationID: string, OriginatorConversationID?: string, ResponseCode: string, ResponseDescription: string, raw: array}
     */
    public static function requestPayout(
        string $phoneDigits,
        string $amountKes,
        string $remarks,
    ): array {
        $phone = MpesaService::normalizeKenyanMsisdn($phoneDigits);
        $amountInt = max(1, (int) round((float) $amountKes));
        $base = rtrim((string) config('waste_bridge.mpesa.base_url'), '/');
        $timeout = (int) config('waste_bridge.mpesa.timeout_seconds', 30);

        $shortcode = (string) (config('waste_bridge.mpesa_b2c.shortcode') ?: config('waste_bridge.mpesa.shortcode'));
        $initiator = (string) config('waste_bridge.mpesa_b2c.initiator_name');
        $credential = (string) config('waste_bridge.mpesa_b2c.security_credential');
        $resultUrl = (string) config('waste_bridge.mpesa_b2c.result_url');
        $timeoutUrl = (string) config('waste_bridge.mpesa_b2c.timeout_url');
        $command = (string) config('waste_bridge.mpesa_b2c.command_id', 'BusinessPayment');

        $token = MpesaService::fetchAccessToken()['access_token'];

        $body = [
            'InitiatorName' => $initiator,
            'SecurityCredential' => $credential,
            'CommandID' => $command,
            'Amount' => (string) $amountInt,
            'PartyA' => $shortcode,
            'PartyB' => $phone,
            'Remarks' => Str::limit($remarks, 100, ''),
            'QueueTimeOutURL' => $timeoutUrl,
            'ResultURL' => $resultUrl,
            'Occasion' => Str::limit($remarks, 100, ''),
        ];

        $response = Http::timeout($timeout)
            ->withToken($token)
            ->acceptJson()
            ->post($base.'/mpesa/b2c/v1/paymentrequest', $body);

        $json = $response->json();
        if (! is_array($json)) {
            Log::warning('mpesa.b2c.invalid_json', ['body' => $response->body()]);

            throw new RuntimeException('M-Pesa B2C response was not JSON.');
        }

        if (! $response->successful()) {
            Log::warning('mpesa.b2c.http_error', ['status' => $response->status(), 'json' => $json]);

            throw new RuntimeException((string) ($json['errorMessage'] ?? 'M-Pesa B2C request failed.'));
        }

        $code = (string) ($json['ResponseCode'] ?? '');
        if ($code !== '0') {
            throw new RuntimeException((string) ($json['ResponseDescription'] ?? 'M-Pesa B2C rejected.'));
        }

        $conv = (string) ($json['ConversationID'] ?? '');
        if ($conv === '') {
            throw new RuntimeException('M-Pesa B2C response missing ConversationID.');
        }

        return [
            'ConversationID' => $conv,
            'OriginatorConversationID' => isset($json['OriginatorConversationID']) ? (string) $json['OriginatorConversationID'] : null,
            'ResponseCode' => $code,
            'ResponseDescription' => (string) ($json['ResponseDescription'] ?? ''),
            'raw' => $json,
        ];
    }
}
