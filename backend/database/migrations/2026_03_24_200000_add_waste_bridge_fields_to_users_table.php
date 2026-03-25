<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('public_id', 36)->unique()->after('id');
            $table->string('phone', 32)->nullable()->after('email');
            $table->string('role', 32)->default('generator')->after('password');
            $table->string('kyc_status', 32)->default('notSubmitted')->after('role');
            $table->boolean('is_verified')->default(false)->after('kyc_status');
            $table->string('subscription_plan', 64)->default('Free')->after('is_verified');
            $table->string('referral_code', 32)->nullable()->unique()->after('subscription_plan');
            $table->foreignId('referred_by_user_id')->nullable()->constrained('users')->nullOnDelete()->after('referral_code');
            $table->char('locale', 5)->default('en')->after('referred_by_user_id');
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropForeign(['referred_by_user_id']);
            $table->dropColumn([
                'public_id',
                'phone',
                'role',
                'kyc_status',
                'is_verified',
                'subscription_plan',
                'referral_code',
                'referred_by_user_id',
                'locale',
                'deleted_at',
            ]);
        });
    }
};
