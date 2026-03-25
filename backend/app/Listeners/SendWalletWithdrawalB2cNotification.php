<?php

namespace App\Listeners;

use App\Events\WalletWithdrawalB2cFinalized;
use App\Services\NotificationWriter;

final class SendWalletWithdrawalB2cNotification
{
    public function handle(WalletWithdrawalB2cFinalized $event): void
    {
        $title = match ($event->outcome) {
            'completed' => 'Withdrawal completed',
            'failed' => 'Withdrawal failed',
            'timeout' => 'Withdrawal pending',
            default => 'Withdrawal update',
        };

        NotificationWriter::notify(
            $event->userId,
            $title,
            $event->detail,
            $event->notificationType,
        );
    }
}
