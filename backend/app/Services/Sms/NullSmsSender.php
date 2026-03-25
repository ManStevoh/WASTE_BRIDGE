<?php

namespace App\Services\Sms;

use App\Contracts\SmsSender;

/** No-op sender (e.g. staging without SMS credentials). */
final class NullSmsSender implements SmsSender
{
    public function send(string $toE164, string $body): void
    {
        // Intentionally empty.
    }
}
