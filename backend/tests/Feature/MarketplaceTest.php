<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\WasteListing;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MarketplaceTest extends TestCase
{
    use RefreshDatabase;

    public function test_marketplace_lists_active_listings(): void
    {
        $seller = User::factory()->create(['role' => 'generator']);
        WasteListing::create([
            'user_id' => $seller->id,
            'waste_type' => 'Plastic',
            'quantity_kg' => 10,
            'total_price' => 100.0,
            'location_text' => 'Demo City',
            'status' => 'active',
            'listing_mode' => 'fixed_price',
        ]);

        $viewer = User::factory()->create(['role' => 'recycler']);
        Sanctum::actingAs($viewer);

        $response = $this->getJson('/api/v1/marketplace');

        $response->assertOk();
        $response->assertJsonPath('data.items.0.wasteType', 'Plastic');
        $response->assertJsonPath('data.page', 1);
    }

    public function test_marketplace_filters_by_min_price_and_waste_type(): void
    {
        $seller = User::factory()->create(['role' => 'generator']);
        WasteListing::create([
            'user_id' => $seller->id,
            'waste_type' => 'Plastic',
            'quantity_kg' => 5,
            'total_price' => 50.0,
            'location_text' => 'A',
            'status' => 'active',
            'listing_mode' => 'fixed_price',
        ]);
        WasteListing::create([
            'user_id' => $seller->id,
            'waste_type' => 'Metal',
            'quantity_kg' => 2,
            'total_price' => 200.0,
            'location_text' => 'B',
            'status' => 'active',
            'listing_mode' => 'fixed_price',
        ]);

        $viewer = User::factory()->create(['role' => 'recycler']);
        Sanctum::actingAs($viewer);

        $response = $this->withHeader('Accept', 'application/json')->call('GET', '/api/v1/marketplace', [
            'minPrice' => 100,
            'wasteType' => 'Metal',
        ]);

        $response->assertOk();
        $response->assertJsonPath('data.total', 1);
        $items = $response->json('data.items');
        $this->assertIsArray($items);
        $this->assertCount(1, $items);
        $this->assertSame('Metal', $items[0]['wasteType'] ?? null);
    }

    public function test_marketplace_sort_nearest_requires_coordinates(): void
    {
        $viewer = User::factory()->create(['role' => 'recycler']);
        Sanctum::actingAs($viewer);

        $response = $this->getJson('/api/v1/marketplace?sort=nearest');

        $response->assertStatus(422);
    }

    public function test_marketplace_sort_nearest_orders_by_distance(): void
    {
        $seller = User::factory()->create(['role' => 'generator']);
        WasteListing::create([
            'user_id' => $seller->id,
            'waste_type' => 'Paper',
            'quantity_kg' => 1,
            'total_price' => 10.0,
            'location_text' => 'Far',
            'latitude' => -1.2921,
            'longitude' => 36.8219,
            'status' => 'active',
            'listing_mode' => 'fixed_price',
        ]);
        WasteListing::create([
            'user_id' => $seller->id,
            'waste_type' => 'Paper',
            'quantity_kg' => 1,
            'total_price' => 10.0,
            'location_text' => 'Near',
            'latitude' => -1.2920,
            'longitude' => 36.8219,
            'status' => 'active',
            'listing_mode' => 'fixed_price',
        ]);

        $viewer = User::factory()->create(['role' => 'recycler']);
        Sanctum::actingAs($viewer);

        $response = $this->getJson(
            '/api/v1/marketplace?sort=nearest&latitude=-1.2920&longitude=36.8219'
        );

        $response->assertOk();
        $response->assertJsonPath('data.items.0.locationText', 'Near');
    }
}
