<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('refresh_tokens', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('token_hash', 64)->unique();
            $table->timestamp('expires_at');
            $table->timestamp('revoked_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'expires_at']);
        });

        Schema::table('kyc_submissions', function (Blueprint $table) {
            $table->string('public_id', 36)->nullable()->unique()->after('id');
        });

        foreach (DB::table('kyc_submissions')->orderBy('id')->cursor() as $row) {
            DB::table('kyc_submissions')
                ->where('id', $row->id)
                ->update(['public_id' => (string) Str::ulid()]);
        }
    }

    public function down(): void
    {
        Schema::table('kyc_submissions', function (Blueprint $table) {
            $table->dropColumn('public_id');
        });

        Schema::dropIfExists('refresh_tokens');
    }
};
