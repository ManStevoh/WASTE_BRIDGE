<?php

use App\Models\User;
use App\Models\Wallet;
use Illuminate\Database\Migrations\Migration;

return new class extends Migration
{
    public function up(): void
    {
        User::query()->chunkById(100, function ($users): void {
            foreach ($users as $user) {
                Wallet::query()->firstOrCreate(
                    ['user_id' => $user->id],
                    ['currency' => 'KES', 'balance' => 0],
                );
            }
        });
    }

    public function down(): void
    {
        // Intentionally empty — do not delete user wallets on rollback.
    }
};
