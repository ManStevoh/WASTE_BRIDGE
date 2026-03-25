<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('collector_available')->default(true)->after('locale');
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->string('receipt_id', 64)->nullable()->after('currency');
            $table->timestamp('receipt_issued_at')->nullable()->after('receipt_id');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('collector_available');
        });

        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['receipt_id', 'receipt_issued_at']);
        });
    }
};
