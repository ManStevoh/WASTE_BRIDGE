<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('wallet_ledger_entries', function (Blueprint $table) {
            $table->string('payout_status', 32)->nullable()->after('provider_reference');
            $table->timestamp('payout_completed_at')->nullable()->after('payout_status');
            $table->string('payout_receipt', 64)->nullable()->after('payout_completed_at');
            $table->string('originator_conversation_id', 64)->nullable()->after('payout_receipt');

            $table->index('provider_reference');
            $table->index('originator_conversation_id');
            $table->index(['category', 'payout_status']);
        });
    }

    public function down(): void
    {
        Schema::table('wallet_ledger_entries', function (Blueprint $table) {
            $table->dropIndex(['category', 'payout_status']);
            $table->dropIndex(['originator_conversation_id']);
            $table->dropIndex(['provider_reference']);
            $table->dropColumn([
                'payout_status',
                'payout_completed_at',
                'payout_receipt',
                'originator_conversation_id',
            ]);
        });
    }
};
