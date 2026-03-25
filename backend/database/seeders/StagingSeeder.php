<?php

namespace Database\Seeders;

use App\Models\PickupJob;
use App\Models\PickupRequest;
use App\Models\User;
use App\Models\WasteListing;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * Deterministic staging/demo data (Phase 0.6). Never run in production.
 *
 * Password for all staging users: Staging-Demo-2025!
 */
class StagingSeeder extends Seeder
{
    private const STAGING_PASSWORD = 'Staging-Demo-2025!';

    public function run(): void
    {
        if (app()->environment('production')) {
            if ($this->command !== null) {
                $this->command->error('StagingSeeder refuses to run in production.');
            }

            return;
        }

        if (! config('waste_bridge.allow_staging_seed')) {
            if ($this->command !== null) {
                $this->command->warn('Set STAGING_SEED=true in .env to enable staging seed.');
            }

            return;
        }

        $demoEmails = [];

        DB::transaction(function () use (&$demoEmails): void {
            $generator = User::query()->updateOrCreate(
                ['email' => 'generator@staging.wastebridge.test'],
                [
                    'name' => 'Staging Generator',
                    'password' => self::STAGING_PASSWORD,
                    'role' => 'generator',
                    'kyc_status' => 'verified',
                    'is_verified' => true,
                    'subscription_plan' => 'Free',
                ],
            );

            $collector = User::query()->updateOrCreate(
                ['email' => 'collector@staging.wastebridge.test'],
                [
                    'name' => 'Staging Collector',
                    'password' => self::STAGING_PASSWORD,
                    'role' => 'collector',
                    'kyc_status' => 'verified',
                    'is_verified' => true,
                    'subscription_plan' => 'Free',
                ],
            );

            $recycler = User::query()->updateOrCreate(
                ['email' => 'recycler@staging.wastebridge.test'],
                [
                    'name' => 'Staging Recycler',
                    'password' => self::STAGING_PASSWORD,
                    'role' => 'recycler',
                    'kyc_status' => 'pending',
                    'is_verified' => false,
                    'subscription_plan' => 'Free',
                ],
            );

            User::query()->updateOrCreate(
                ['email' => 'admin@staging.wastebridge.test'],
                [
                    'name' => 'Staging Admin',
                    'password' => self::STAGING_PASSWORD,
                    'role' => 'admin',
                    'kyc_status' => 'verified',
                    'is_verified' => true,
                    'subscription_plan' => 'Free',
                ],
            );

            WasteListing::query()->updateOrCreate(
                ['public_id' => 'wl-staging-demo-001'],
                [
                    'user_id' => $generator->id,
                    'waste_type' => 'Plastic',
                    'quantity_kg' => 25,
                    'unit_price_per_kg' => 350,
                    'total_price' => 8750,
                    'location_text' => 'Staging District, Demo City',
                    'status' => 'active',
                    'listing_mode' => 'fixed_price',
                ],
            );

            // Idempotent demo pickups (fixed public_ids)
            $pr1 = PickupRequest::query()->updateOrCreate(
                ['public_id' => 'wr-staging-demo-001'],
                [
                    'generator_user_id' => $generator->id,
                    'waste_type' => 'Plastic',
                    'quantity_kg' => 12,
                    'location' => 'Staging District, Demo City',
                    'status' => 'pending',
                    'payment_status' => 'unpaid',
                    'suggested_collector_name' => 'Staging Collector',
                    'estimated_eta_minutes' => 25,
                    'distance_km' => 5.0,
                    'unit_price_per_kg' => 400,
                    'total_amount' => 4800,
                    'co2_saved_kg' => 21.6,
                ],
            );

            PickupJob::query()->updateOrCreate(
                ['public_id' => 'job-staging-demo-001'],
                [
                    'pickup_request_id' => $pr1->id,
                    'pickup_location' => $pr1->location,
                    'waste_type' => $pr1->waste_type,
                    'quantity_kg' => $pr1->quantity_kg,
                    'earning' => 2000,
                    'status' => 'open',
                ],
            );

            $pr2 = PickupRequest::query()->updateOrCreate(
                ['public_id' => 'wr-staging-demo-002'],
                [
                    'generator_user_id' => $generator->id,
                    'waste_type' => 'Organic',
                    'quantity_kg' => 8,
                    'location' => 'Staging District, Demo City',
                    'status' => 'accepted',
                    'payment_status' => 'pending',
                    'assigned_collector_user_id' => $collector->id,
                    'accepted_at' => now()->subHour(),
                    'suggested_collector_name' => 'Staging Collector',
                    'estimated_eta_minutes' => 30,
                    'distance_km' => 9.0,
                    'unit_price_per_kg' => 180,
                    'total_amount' => 1440,
                    'co2_saved_kg' => 5.6,
                ],
            );

            PickupJob::query()->updateOrCreate(
                ['public_id' => 'job-staging-demo-002'],
                [
                    'pickup_request_id' => $pr2->id,
                    'collector_user_id' => $collector->id,
                    'pickup_location' => $pr2->location,
                    'waste_type' => $pr2->waste_type,
                    'quantity_kg' => $pr2->quantity_kg,
                    'earning' => 1500,
                    'status' => 'accepted',
                ],
            );

            $demoEmails = [
                $generator->email,
                $collector->email,
                $recycler->email,
            ];
        });

        if ($this->command !== null) {
            $this->command->info('Staging seed complete. Log in as: '.implode(', ', $demoEmails).' — password: '.self::STAGING_PASSWORD);
        }
    }
}
