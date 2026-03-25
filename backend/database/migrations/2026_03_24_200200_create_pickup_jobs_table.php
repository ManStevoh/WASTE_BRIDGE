<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Operational collector jobs (Laravel's `jobs` table is reserved for the queue).
     */
    public function up(): void
    {
        Schema::create('pickup_jobs', function (Blueprint $table) {
            $table->id();
            $table->string('public_id', 36)->unique();
            $table->foreignId('pickup_request_id')->constrained('pickup_requests')->cascadeOnDelete();
            $table->foreignId('collector_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('pickup_location', 512);
            $table->string('waste_type', 64);
            $table->decimal('quantity_kg', 12, 3);
            $table->decimal('earning', 14, 2);
            $table->string('status', 32);
            $table->timestamps();

            $table->unique('pickup_request_id');
            $table->index(['collector_user_id', 'status']);
            $table->index(['status', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pickup_jobs');
    }
};
