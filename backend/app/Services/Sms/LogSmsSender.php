<?php

namespace App\Services\Sms;

use App\Contracts\SmsSender;
use Illuminate\Support\Facades\Log;

/**
 * Logs SMS payloads. In local/testing, logs full body; elsewhere redacts digits.
 */
final class LogSmsSender implements SmsSender
{
    public function send(string $toE164, string $body): void
    {
        if (app()->environment('local', 'testing')) {
            Log::info('sms.delivery', ['to' => $toE164, 'body' => $body]);

            return;
        }

        Log::info('sms.delivery', [
            'to' => $toE164,
            'body_length' => strlen($body),
        ]);
    }
}
