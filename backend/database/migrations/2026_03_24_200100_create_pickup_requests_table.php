<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pickup_requests', function (Blueprint $table) {
            $table->id();
            $table->string('public_id', 36)->unique();
            $table->foreignId('generator_user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('assigned_collector_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('waste_type', 64);
            $table->decimal('quantity_kg', 12, 3);
            $table->string('location', 512);
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('status', 32);
            $table->timestamp('accepted_at')->nullable();
            $table->timestamp('picked_up_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamp('scheduled_at')->nullable();
            $table->timestamp('rescheduled_at')->nullable();
            $table->string('suggested_collector_name', 255)->nullable();
            $table->unsignedInteger('estimated_eta_minutes')->nullable();
            $table->decimal('distance_km', 10, 3)->nullable();
            $table->decimal('unit_price_per_kg', 14, 2)->nullable();
            $table->decimal('total_amount', 14, 2)->nullable();
            $table->string('payment_status', 16)->default('unpaid');
            $table->string('before_pickup_photo_url', 1024)->nullable();
            $table->string('after_pickup_photo_url', 1024)->nullable();
            $table->decimal('generator_rating', 3, 2)->nullable();
            $table->decimal('collector_rating', 3, 2)->nullable();
            $table->boolean('is_disputed')->default(false);
            $table->text('dispute_reason')->nullable();
            $table->string('receipt_id', 64)->nullable();
            $table->timestamp('receipt_issued_at')->nullable();
            $table->decimal('co2_saved_kg', 12, 4)->default(0);
            $table->timestamps();
            $table->softDeletes();

            $table->index(['generator_user_id', 'created_at']);
            $table->index(['assigned_collector_user_id', 'status']);
            $table->index(['status', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pickup_requests');
    }
};
