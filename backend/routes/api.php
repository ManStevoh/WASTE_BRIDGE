<?php

use App\Http\Controllers\Api\V1\AdminKycSubmissionController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\JobController;
use App\Http\Controllers\Api\V1\KycSubmissionController;
use App\Http\Controllers\Api\V1\MarketplaceBidController;
use App\Http\Controllers\Api\V1\MarketplaceController;
use App\Http\Controllers\Api\V1\MarketplacePurchaseController;
use App\Http\Controllers\Api\V1\MpesaWebhookController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\OrderController;
use App\Http\Controllers\Api\V1\OtpController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\PickupRequestController;
use App\Http\Controllers\Api\V1\RatingController;
use App\Http\Controllers\Api\V1\ReceiptController;
use App\Http\Controllers\Api\V1\WalletController;
use App\Http\Controllers\Api\V1\WasteListingController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::post('auth/register', [AuthController::class, 'register'])
        ->middleware('throttle:auth-register');
    Route::post('auth/login', [AuthController::class, 'login'])
        ->middleware('throttle:auth-login');
    Route::post('auth/refresh', [AuthController::class, 'refresh'])
        ->middleware('throttle:auth-refresh');
    Route::post('auth/otp/request', [OtpController::class, 'requestOtp'])
        ->middleware('throttle:auth-otp-request');
    Route::post('auth/otp/verify', [OtpController::class, 'verifyOtp'])
        ->middleware('throttle:auth-otp-verify');

    Route::post('webhooks/mpesa/callback', [MpesaWebhookController::class, 'callback'])
        ->middleware('throttle:mpesa-webhook');

    Route::middleware(['auth:sanctum', 'throttle:api'])->group(function () {
        Route::get('auth/me', [AuthController::class, 'me']);
        Route::patch('auth/me', [AuthController::class, 'updateMe']);
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::post('auth/logout-all', [AuthController::class, 'logoutAll'])
            ->middleware('throttle:api-sensitive');

        Route::get('notifications', [NotificationController::class, 'index']);

        Route::get('marketplace', [MarketplaceController::class, 'index']);

        Route::get('orders', [OrderController::class, 'index']);
        Route::get('orders/{order}', [OrderController::class, 'show']);
        Route::post('orders/{order}/cancel', [OrderController::class, 'cancel'])
            ->middleware('throttle:api-sensitive');

        Route::middleware('role:recycler')->group(function () {
            Route::post('marketplace/purchase', [MarketplacePurchaseController::class, 'store'])
                ->middleware('throttle:api-sensitive');
            Route::post('marketplace/listings/{waste_listing}/bid', [MarketplaceBidController::class, 'store'])
                ->middleware('throttle:api-sensitive');
        });

        Route::get('users/{userPublicId}/ratings', [RatingController::class, 'index']);

        Route::get('wallet', [WalletController::class, 'show']);
        Route::get('user/wallet', [WalletController::class, 'show']);
        Route::get('wallet/transactions', [WalletController::class, 'transactions']);
        Route::post('wallet/withdraw', [WalletController::class, 'withdraw'])
            ->middleware('throttle:api-sensitive');

        Route::get('receipts/{receiptId}/pdf', [ReceiptController::class, 'pdf']);
        Route::get('receipts/{receiptId}', [ReceiptController::class, 'show']);

        Route::post('payment/initiate', [PaymentController::class, 'initiate'])
            ->middleware('throttle:api-sensitive');

        Route::get('kyc/submissions', [KycSubmissionController::class, 'index']);
        Route::post('kyc/submissions', [KycSubmissionController::class, 'store'])
            ->middleware('throttle:api-upload');
        Route::get('kyc/submissions/{kyc_submission}', [KycSubmissionController::class, 'show']);

        Route::middleware('role:admin')->group(function () {
            Route::get('admin/kyc/submissions', [AdminKycSubmissionController::class, 'index']);
            Route::patch('admin/kyc/submissions/{kyc_submission}', [AdminKycSubmissionController::class, 'review'])
                ->middleware('throttle:api-sensitive');
        });

        Route::middleware('role:generator')->group(function () {
            Route::post('waste/create', [WasteListingController::class, 'store']);
            Route::post('pickup/request', [PickupRequestController::class, 'store']);
            Route::get('requests', [PickupRequestController::class, 'index']);
            Route::post('requests', [PickupRequestController::class, 'store']);
            Route::post('requests/{pickup_request}/proof', [PickupRequestController::class, 'uploadProof'])
                ->middleware('throttle:api-upload');
            Route::post('requests/{pickup_request}/ratings', [PickupRequestController::class, 'submitRatings']);
            Route::post('requests/{pickup_request}/dispute', [PickupRequestController::class, 'dispute'])
                ->middleware('throttle:api-sensitive');
            Route::post('requests/{pickup_request}/dispute/resolve', [PickupRequestController::class, 'resolveDispute'])
                ->middleware('throttle:api-sensitive');
        });

        Route::middleware('role:collector')->group(function () {
            Route::post('pickup/accept', [JobController::class, 'acceptByPublicId']);
            Route::get('jobs', [JobController::class, 'index']);
            Route::post('jobs/{pickup_job}/accept', [JobController::class, 'accept']);
            Route::patch('jobs/{pickup_job}', [JobController::class, 'update']);
        });
    });
});
