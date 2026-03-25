<?php

namespace Tests\Feature;

use App\Models\PickupRequest;
use App\Models\Rating;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProfileAndRatingsTest extends TestCase
{
    use RefreshDatabase;

    public function test_collector_can_patch_availability(): void
    {
        $collector = User::factory()->create(['role' => 'collector', 'collector_available' => true]);

        Sanctum::actingAs($collector);

        $response = $this->patchJson('/api/v1/auth/me', [
            'collectorAvailable' => false,
        ]);

        $response->assertOk();
        $response->assertJsonPath('data.collectorAvailable', false);

        $collector->refresh();
        $this->assertFalse($collector->collector_available);
    }

    public function test_generator_cannot_set_collector_availability(): void
    {
        $user = User::factory()->create(['role' => 'generator']);

        Sanctum::actingAs($user);

        $this->patchJson('/api/v1/auth/me', [
            'collectorAvailable' => false,
        ])->assertStatus(403);
    }

    public function test_authenticated_user_can_list_ratings_for_ratee(): void
    {
        $ratee = User::factory()->create(['role' => 'collector']);
        $rater = User::factory()->create(['role' => 'generator']);

        $pr = PickupRequest::query()->create([
            'public_id' => (string) Str::ulid(),
            'generator_user_id' => $rater->id,
            'assigned_collector_user_id' => $ratee->id,
            'waste_type' => 'plastic',
            'quantity_kg' => 10,
            'location' => 'Nairobi',
            'status' => 'completed',
        ]);

        Rating::query()->create([
            'pickup_request_id' => $pr->id,
            'job_id' => null,
            'rater_user_id' => $rater->id,
            'ratee_user_id' => $ratee->id,
            'score' => 4.5,
            'comment' => 'Great',
            'created_at' => now(),
        ]);

        Sanctum::actingAs($rater);

        $response = $this->getJson('/api/v1/users/'.$ratee->public_id.'/ratings');

        $response->assertOk();
        $response->assertJsonPath('data.items.0.score', 4.5);
    }
}
