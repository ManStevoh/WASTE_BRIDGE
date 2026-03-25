<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\WalletB2cPayoutCompletionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Safaricom Daraja B2C ResultURL and QueueTimeOutURL (no auth; idempotent).
 */
class MpesaB2cWebhookController extends Controller
{
    public function result(Request $request): JsonResponse
    {
        WalletB2cPayoutCompletionService::handle($request->all(), 'result');

        return response()->json([
            'ResultCode' => 0,
            'ResultDesc' => 'Accepted',
        ]);
    }

    public function timeout(Request $request): JsonResponse
    {
        WalletB2cPayoutCompletionService::handle($request->all(), 'timeout');

        return response()->json([
            'ResultCode' => 0,
            'ResultDesc' => 'Accepted',
        ]);
    }
}
