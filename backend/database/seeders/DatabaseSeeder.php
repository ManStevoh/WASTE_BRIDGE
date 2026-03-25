<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     *
     * Staging/demo data (Phase 0.6) runs only when STAGING_SEED=true — see DOCS/PROGRAM_SETUP.md.
     */
    public function run(): void
    {
        if (config('waste_bridge.allow_staging_seed') && ! app()->environment('production')) {
            $this->call(StagingSeeder::class);
        }
    }
}
