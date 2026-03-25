<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\User;
use App\Models\WasteListing;
use App\Services\AuctionListingService;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class Phase3ListingTypesTest extends TestCase
{
    use RefreshDatabase;

    public function test_recycler_can_place_bid_and_win_auction_then_purchase(): void
    {
        $seller = User::factory()->create(['role' => 'generator']);
        $listing = WasteListing::create([
            'user_id' => $seller->id,
            'waste_type' => 'Plastic',
            'quantity_kg' => 10,
            'location_text' => 'Nairobi',
            'status' => 'active',
            'listing_mode' => 'auction',
            'auction_ends_at' => Carbon::now()->addHour(),
            'starting_bid' => 100,
            'auction_status' => 'open',
        ]);

        $buyer = User::factory()->create(['role' => 'recycler']);
        Sanctum::actingAs($buyer);

        $this->postJson('/api/v1/marketplace/listings/'.$listing->public_id.'/bid', [
            'amount' => 100,
        ])->assertOk();

        $listing->refresh();
        $this->assertSame('open', $listing->auction_status);
        $this->assertEquals(100.0, (float) $listing->current_bid_amount);

        $listing->auction_ends_at = Carbon::now()->subMinute();
        $listing->save();

        AuctionListingService::closeExpiredForListing($listing->fresh());
        $listing->refresh();
        $this->assertSame('ended', $listing->auction_status);

        $response = $this->postJson('/api/v1/marketplace/purchase', [
            'listingPublicId' => $listing->public_id,
        ]);

        $response->assertOk();
        $response->assertJsonPath('data.order.subtotalAmount', 100);

        $listing->refresh();
        $this->assertSame('inactive', $listing->status);
    }

    public function test_bulk_purchase_uses_quantity_kg_for_subtotal(): void
    {
        $seller = User::factory()->create(['role' => 'generator']);
        $listing = WasteListing::create([
            'user_id' => $seller->id,
            'waste_type' => 'Plastic',
            'quantity_kg' => 200,
            'unit_price_per_kg' => 10,
            'total_price' => 2000,
            'location_text' => 'Nairobi',
            'status' => 'active',
            'listing_mode' => 'bulk_contract',
            'bulk_min_quantity_kg' => 50,
        ]);

        $buyer = User::factory()->create(['role' => 'recycler']);
        Sanctum::actingAs($buyer);

        $response = $this->postJson('/api/v1/marketplace/purchase', [
            'listingPublicId' => $listing->public_id,
            'quantityKg' => 100,
        ]);

        $response->assertOk();
        $response->assertJsonPath('data.order.subtotalAmount', 1000);
    }

    public function test_buyer_can_cancel_order_before_job_moves(): void
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

        $order = Order::create([
            'seller_user_id' => $seller->id,
            'buyer_user_id' => $buyer->id,
            'listing_id' => $listing->id,
            'status' => 'created',
            'subtotal_amount' => 100,
            'currency' => 'KES',
        ]);

        Sanctum::actingAs($buyer);

        $response = $this->postJson('/api/v1/orders/'.$order->public_id.'/cancel');

        $response->assertOk();
        $response->assertJsonPath('data.order.status', 'cancelled');

        $this->assertDatabaseHas('orders', [
            'id' => $order->id,
            'status' => 'cancelled',
        ]);
    }
}
