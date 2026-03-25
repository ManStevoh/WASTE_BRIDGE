<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wallet_ledger_entries', function (Blueprint $table) {
            $table->id();
            $table->string('public_id', 36)->unique();
            $table->foreignId('wallet_id')->constrained('wallets')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->decimal('amount', 14, 2);
            $table->string('entry_type', 16);
            $table->string('status', 24)->default('posted');
            $table->string('category', 48);
            $table->string('material', 128)->nullable();
            $table->decimal('quantity_kg', 12, 3)->nullable();
            $table->text('description')->nullable();
            $table->decimal('balance_after', 14, 2)->nullable();
            $table->foreignId('pickup_request_id')->nullable()->constrained('pickup_requests')->nullOnDelete();
            $table->foreignId('pickup_job_id')->nullable()->constrained('pickup_jobs')->nullOnDelete();
            $table->string('idempotency_key', 64)->nullable()->unique();
            $table->string('provider_reference', 128)->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['wallet_id', 'created_at']);
            $table->index(['user_id', 'created_at']);
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallet_ledger_entries');
    }
};
