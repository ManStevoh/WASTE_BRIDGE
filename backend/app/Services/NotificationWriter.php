<?php

namespace App\Services;

use App\Models\AppNotification;

final class NotificationWriter
{
    public static function notify(int $userId, string $title, string $message, string $type): void
    {
        AppNotification::query()->create([
            'user_id' => $userId,
            'title' => $title,
            'message' => $message,
            'type' => $type,
        ]);
    }
}
