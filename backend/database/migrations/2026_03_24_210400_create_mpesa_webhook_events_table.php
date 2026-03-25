<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Idempotent store for M-Pesa callbacks (STK / C2B) before full PSP integration.
     */
    public function up(): void
    {
        Schema::create('mpesa_webhook_events', function (Blueprint $table) {
            $table->id();
            $table->string('idempotency_key', 128)->unique();
            $table->string('event_type', 32)->default('stk_callback');
            $table->json('payload');
            $table->string('processing_status', 24)->default('received');
            $table->text('processing_error')->nullable();
            $table->timestamp('processed_at')->nullable();
            $table->timestamps();

            $table->index(['processing_status', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('mpesa_webhook_events');
    }
};
