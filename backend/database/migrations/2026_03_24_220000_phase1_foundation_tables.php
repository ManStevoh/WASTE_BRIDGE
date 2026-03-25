<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('waste_listings', function (Blueprint $table) {
            $table->id();
            $table->string('public_id', 36)->unique();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('waste_type', 64);
            $table->decimal('quantity_kg', 12, 3);
            $table->decimal('unit_price_per_kg', 14, 2)->nullable();
            $table->decimal('total_price', 14, 2)->nullable();
            $table->string('location_text', 512);
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('status', 32)->default('active');
            $table->string('listing_mode', 32)->default('fixed_price');
            $table->timestamps();
            $table->softDeletes();

            $table->index(['status', 'created_at']);
            $table->index(['user_id']);
            $table->index(['waste_type', 'status']);
        });

        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->string('public_id', 36)->unique();
            $table->foreignId('seller_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('buyer_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('listing_id')->nullable()->constrained('waste_listings')->nullOnDelete();
            $table->string('status', 32);
            $table->decimal('subtotal_amount', 14, 2)->nullable();
            $table->decimal('platform_fee_amount', 14, 2)->nullable();
            $table->decimal('tax_amount', 14, 2)->nullable();
            $table->decimal('escrow_amount', 14, 2)->nullable();
            $table->string('escrow_status', 24)->nullable();
            $table->char('currency', 3)->default('KES');
            $table->timestamps();

            $table->index(['buyer_user_id', 'status']);
            $table->index(['seller_user_id', 'status']);
            $table->index(['status', 'created_at']);
        });

        Schema::create('kyc_submissions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('status', 32);
            $table->string('document_type', 64);
            $table->string('storage_path', 512);
            $table->foreignId('reviewed_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->text('rejection_reason')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'created_at']);
            $table->index('status');
        });

        Schema::create('ratings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('pickup_request_id')->constrained('pickup_requests')->cascadeOnDelete();
            $table->foreignId('job_id')->nullable()->constrained('pickup_jobs')->nullOnDelete();
            $table->foreignId('rater_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('ratee_user_id')->constrained('users')->cascadeOnDelete();
            $table->decimal('score', 3, 2);
            $table->text('comment')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->unique(['pickup_request_id', 'rater_user_id']);
            $table->index(['ratee_user_id', 'created_at']);
        });

        Schema::create('referrals', function (Blueprint $table) {
            $table->id();
            $table->foreignId('referrer_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('code', 32)->unique();
            $table->unsignedInteger('max_redemptions')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();
        });

        Schema::create('referral_redemptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('referral_id')->constrained('referrals')->cascadeOnDelete();
            $table->foreignId('referee_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('reward_ledger_entry_id')->nullable()->constrained('wallet_ledger_entries')->nullOnDelete();
            $table->string('idempotency_key', 64)->unique();
            $table->timestamps();

            $table->unique(['referral_id', 'referee_user_id']);
        });

        Schema::create('payment_intents', function (Blueprint $table) {
            $table->id();
            $table->string('public_id', 36)->unique();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('order_id')->nullable()->constrained('orders')->nullOnDelete();
            $table->decimal('amount', 14, 2);
            $table->char('currency', 3)->default('KES');
            $table->string('provider', 32)->default('mpesa');
            $table->string('provider_checkout_id', 128)->nullable();
            $table->string('status', 32)->default('created');
            $table->string('idempotency_key', 64)->unique();
            $table->json('raw_payload')->nullable();
            $table->timestamps();
        });

        Schema::table('pickup_requests', function (Blueprint $table) {
            $table->foreignId('listing_id')->nullable()->after('generator_user_id')->constrained('waste_listings')->nullOnDelete();
            $table->foreignId('order_id')->nullable()->after('listing_id')->constrained('orders')->nullOnDelete();
            $table->index('order_id');
        });

        Schema::table('pickup_jobs', function (Blueprint $table) {
            $table->foreignId('order_id')->nullable()->after('pickup_request_id')->constrained('orders')->nullOnDelete();
            $table->index('order_id');
        });

        Schema::table('wallet_ledger_entries', function (Blueprint $table) {
            $table->foreignId('order_id')->nullable()->after('pickup_job_id')->constrained('orders')->nullOnDelete();
            $table->index('order_id');
        });
    }

    public function down(): void
    {
        Schema::table('wallet_ledger_entries', function (Blueprint $table) {
            $table->dropConstrainedForeignId('order_id');
        });

        Schema::table('pickup_jobs', function (Blueprint $table) {
            $table->dropConstrainedForeignId('order_id');
        });

        Schema::table('pickup_requests', function (Blueprint $table) {
            $table->dropConstrainedForeignId('listing_id');
            $table->dropConstrainedForeignId('order_id');
        });

        Schema::dropIfExists('payment_intents');
        Schema::dropIfExists('referral_redemptions');
        Schema::dropIfExists('referrals');
        Schema::dropIfExists('ratings');
        Schema::dropIfExists('kyc_submissions');
        Schema::dropIfExists('orders');
        Schema::dropIfExists('waste_listings');
    }
};
