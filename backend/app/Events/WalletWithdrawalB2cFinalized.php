<?php

namespace App\Events;

use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Dispatched when a B2C withdrawal reaches a terminal or timeout state (Phase 4.4).
 */
final class WalletWithdrawalB2cFinalized
{
    use Dispatchable;
    use SerializesModels;

    /**
     * @param  'completed'|'failed'|'timeout'  $outcome
     */
    public function __construct(
        public readonly int $userId,
        public readonly string $outcome,
        public readonly string $amount,
        public readonly string $currency,
        public readonly string $conversationId,
        public readonly ?string $mpesaReceipt,
        public readonly string $detail,
        public readonly string $notificationType,
    ) {}
}
