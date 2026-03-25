<?php

namespace Tests\Feature;

use App\Models\PickupJob;
use App\Models\PickupRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class Phase5Test extends TestCase
{
    use RefreshDatabase;

    public function test_unavailable_collector_does_not_see_open_jobs(): void
    {
        $generator = User::factory()->create(['role' => 'generator']);
        $pr = PickupRequest::query()->create([
            'generator_user_id' => $generator->id,
            'waste_type' => 'plastic',
            'quantity_kg' => 10,
            'location' => 'Nairobi',
            'status' => 'pending',
        ]);
        PickupJob::query()->create([
            'pickup_request_id' => $pr->id,
            'pickup_location' => $pr->location,
            'waste_type' => $pr->waste_type,
            'quantity_kg' => $pr->quantity_kg,
            'earning' => 100.0,
            'status' => 'open',
        ]);

        $collector = User::factory()->create([
            'role' => 'collector',
            'collector_available' => false,
        ]);
        Sanctum::actingAs($collector);

        $response = $this->getJson('/api/v1/jobs');

        $response->assertOk();
        $items = $response->json('data.items');
        $this->assertIsArray($items);
        $this->assertCount(0, $items);
    }

    public function test_route_plan_orders_stops_nearest_neighbor_from_start(): void
    {
        $generator = User::factory()->create(['role' => 'generator']);
        $collector = User::factory()->create(['role' => 'collector', 'collector_available' => true]);

        $far = PickupRequest::query()->create([
            'generator_user_id' => $generator->id,
            'waste_type' => 'plastic',
            'quantity_kg' => 5,
            'location' => 'Far',
            'latitude' => -1.35,
            'longitude' => 36.90,
            'status' => 'accepted',
        ]);
        $near = PickupRequest::query()->create([
            'generator_user_id' => $generator->id,
            'waste_type' => 'plastic',
            'quantity_kg' => 5,
            'location' => 'Near',
            'latitude' => -1.2921,
            'longitude' => 36.8219,
            'status' => 'accepted',
        ]);

        PickupJob::query()->create([
            'pickup_request_id' => $far->id,
            'collector_user_id' => $collector->id,
            'pickup_location' => $far->location,
            'waste_type' => $far->waste_type,
            'quantity_kg' => $far->quantity_kg,
            'earning' => 50.0,
            'status' => 'accepted',
        ]);
        PickupJob::query()->create([
            'pickup_request_id' => $near->id,
            'collector_user_id' => $collector->id,
            'pickup_location' => $near->location,
            'waste_type' => $near->waste_type,
            'quantity_kg' => $near->quantity_kg,
            'earning' => 50.0,
            'status' => 'accepted',
        ]);

        Sanctum::actingAs($collector);

        $response = $this->getJson('/api/v1/jobs/route-plan?latitude=-1.2921&longitude=36.8219');

        $response->assertOk();
        $stops = $response->json('data.stops');
        $this->assertIsArray($stops);
        $this->assertCount(2, $stops);
        $this->assertSame($near->public_id, $stops[0]['job']['requestId']);
        $this->assertSame($far->public_id, $stops[1]['job']['requestId']);
        $this->assertSame('nearest_neighbor', $response->json('data.algorithm'));
        $this->assertNotNull($stops[1]['legDistanceKm']);
    }

    public function test_proof_gps_rejects_coordinates_too_far_from_pickup(): void
    {
        config(['waste_bridge.logistics.proof_gps_max_distance_km' => 1.0]);

        $generator = User::factory()->create(['role' => 'generator']);
        $pr = PickupRequest::query()->create([
            'generator_user_id' => $generator->id,
            'waste_type' => 'plastic',
            'quantity_kg' => 10,
            'location' => 'Nairobi',
            'latitude' => -1.2921,
            'longitude' => 36.8219,
            'status' => 'pending',
        ]);

        Sanctum::actingAs($generator);

        $response = $this->postJson('/api/v1/requests/'.$pr->public_id.'/proof', [
            'proof_latitude' => 0.0,
            'proof_longitude' => 0.0,
        ]);

        $response->assertStatus(422);
        $response->assertJsonPath('code', 'PROOF_GPS_TOO_FAR');
    }
}
