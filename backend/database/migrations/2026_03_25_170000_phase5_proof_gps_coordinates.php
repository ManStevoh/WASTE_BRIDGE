<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('pickup_requests', function (Blueprint $table) {
            $table->decimal('proof_latitude', 10, 7)->nullable()->after('after_pickup_photo_url');
            $table->decimal('proof_longitude', 10, 7)->nullable()->after('proof_latitude');
        });
    }

    public function down(): void
    {
        Schema::table('pickup_requests', function (Blueprint $table) {
            $table->dropColumn(['proof_latitude', 'proof_longitude']);
        });
    }
};
