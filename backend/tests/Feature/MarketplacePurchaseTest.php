<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\User;
use App\Models\WasteListing;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MarketplacePurchaseTest extends TestCase
{
    use RefreshDatabase;

    public function test_recycler_can_purchase_listing_and_creates_order_with_buyer(): void
    {
        $seller = User::factory()->create(['role' => 'generator']);
        $listing = WasteListing::create([
            'user_id' => $seller->id,
            'waste_type' => 'Plastic',
            'quantity_kg' => 10,
            'total_price' => 500.0,
            'location_text' => 'Nairobi Central',
            'status' => 'active',
            'listing_mode' => 'fixed_price',
        ]);

        $buyer = User::factory()->create(['role' => 'recycler']);
        Sanctum::actingAs($buyer);

        $response = $this->postJson('/api/v1/marketplace/purchase', [
            'listingPublicId' => $listing->public_id,
        ]);

        $response->assertOk();
        $response->assertJsonPath('data.order.buyerUserId', $buyer->public_id);
        $response->assertJsonPath('data.order.sellerUserId', $seller->public_id);
        $this->assertEquals(500.0, $response->json('data.order.subtotalAmount'));
        $this->assertNotNull($response->json('data.order.pickupRequest.id'));

        $this->assertDatabaseHas('orders', [
            'listing_id' => $listing->id,
            'buyer_user_id' => $buyer->id,
            'seller_user_id' => $seller->id,
        ]);
    }

    public function test_cannot_purchase_own_listing(): void
    {
        $seller = User::factory()->create(['role' => 'recycler']);
        $listing = WasteListing::create([
            'user_id' => $seller->id,
            'waste_type' => 'Plastic',
            'quantity_kg' => 5,
            'total_price' => 100.0,
            'location_text' => 'A',
            'status' => 'active',
            'listing_mode' => 'fixed_price',
        ]);

        Sanctum::actingAs($seller);

        $response = $this->postJson('/api/v1/marketplace/purchase', [
            'listingPublicId' => $listing->public_id,
        ]);

        $response->assertStatus(422);
    }

    public function test_generator_cannot_call_purchase_endpoint(): void
    {
        $seller = User::factory()->create(['role' => 'generator']);
        $buyer = User::factory()->create(['role' => 'generator']);
        $listing = WasteListing::create([
            'user_id' => $seller->id,
            'waste_type' => 'Plastic',
            'quantity_kg' => 5,
            'total_price' => 100.0,
            'location_text' => 'A',
            'status' => 'active',
            'listing_mode' => 'fixed_price',
        ]);

        Sanctum::actingAs($buyer);

        $response = $this->postJson('/api/v1/marketplace/purchase', [
            'listingPublicId' => $listing->public_id,
        ]);

        $response->assertForbidden();
    }

    public function test_orders_index_scopes_buyer(): void
    {
        $seller = User::factory()->create(['role' => 'generator']);
        $buyer = User::factory()->create(['role' => 'recycler']);
        $listing = WasteListing::create([
            'user_id' => $seller->id,
            'waste_type' => 'Plastic',
            'quantity_kg' => 5,
            'total_price' => 100.0,
            'location_text' => 'A',
            'status' => 'active',
            'listing_mode' => 'fixed_price',
        ]);

        Order::create([
            'seller_user_id' => $seller->id,
            'buyer_user_id' => $buyer->id,
            'listing_id' => $listing->id,
            'status' => 'created',
            'subtotal_amount' => 100,
            'currency' => 'KES',
        ]);

        Sanctum::actingAs($buyer);

        $response = $this->getJson('/api/v1/orders?scope=buyer');

        $response->assertOk();
        $response->assertJsonPath('data.total', 1);
    }
}
