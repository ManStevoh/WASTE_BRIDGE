<?php

namespace App\Services\Sms;

use App\Contracts\SmsSender;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

final class TwilioSmsSender implements SmsSender
{
    public function __construct(
        private readonly string $accountSid,
        private readonly string $authToken,
        private readonly string $fromNumber,
        private readonly int $timeoutSeconds = 15,
    ) {}

    public function send(string $toE164, string $body): void
    {
        $url = sprintf(
            'https://api.twilio.com/2010-04-01/Accounts/%s/Messages.json',
            $this->accountSid,
        );

        $response = Http::timeout($this->timeoutSeconds)
            ->withBasicAuth($this->accountSid, $this->authToken)
            ->asForm()
            ->post($url, [
                'From' => $this->fromNumber,
                'To' => $toE164,
                'Body' => $body,
            ]);

        if (! $response->successful()) {
            Log::warning('sms.twilio.failed', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);

            throw new RuntimeException('SMS provider rejected the request.');
        }
    }
}
