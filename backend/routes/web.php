<?php

use App\Http\Controllers\Api\V1\AdminWalletReconciliationController;
use App\Http\Controllers\Web\AdminAuthController;
use App\Http\Controllers\Web\AdminKycWebController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/admin/login', [AdminAuthController::class, 'showLogin'])->name('admin.login');
Route::post('/admin/login', [AdminAuthController::class, 'login']);

Route::middleware(['auth', 'web.admin'])->prefix('admin')->group(function () {
    Route::post('/logout', [AdminAuthController::class, 'logout'])->name('admin.logout');
    Route::get('/kyc', [AdminKycWebController::class, 'index'])->name('admin.kyc.index');
    Route::get('/kyc/{kycSubmission}', [AdminKycWebController::class, 'show'])->name('admin.kyc.show');
    Route::post('/kyc/{kycSubmission}/review', [AdminKycWebController::class, 'review'])->name('admin.kyc.review');
    Route::get('/wallet/export', [AdminWalletReconciliationController::class, 'export'])->name('admin.wallet.export');
});
