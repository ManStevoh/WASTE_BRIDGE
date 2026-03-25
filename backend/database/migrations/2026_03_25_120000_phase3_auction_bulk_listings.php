<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('waste_listings', function (Blueprint $table) {
            $table->decimal('bulk_min_quantity_kg', 12, 3)->nullable()->after('listing_mode');
            $table->timestamp('auction_ends_at')->nullable()->after('bulk_min_quantity_kg');
            $table->decimal('starting_bid', 14, 2)->nullable()->after('auction_ends_at');
            $table->decimal('reserve_price', 14, 2)->nullable()->after('starting_bid');
            $table->decimal('current_bid_amount', 14, 2)->nullable()->after('reserve_price');
            $table->foreignId('current_highest_bidder_id')->nullable()->after('current_bid_amount')->constrained('users')->nullOnDelete();
            $table->string('auction_status', 32)->nullable()->after('current_highest_bidder_id');
        });

        Schema::create('listing_bids', function (Blueprint $table) {
            $table->id();
            $table->string('public_id', 36)->unique();
            $table->foreignId('waste_listing_id')->constrained('waste_listings')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->decimal('amount', 14, 2);
            $table->timestamps();

            $table->index(['waste_listing_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('listing_bids');

        Schema::table('waste_listings', function (Blueprint $table) {
            $table->dropForeign(['current_highest_bidder_id']);
            $table->dropColumn([
                'bulk_min_quantity_kg',
                'auction_ends_at',
                'starting_bid',
                'reserve_price',
                'current_bid_amount',
                'current_highest_bidder_id',
                'auction_status',
            ]);
        });
    }
};
