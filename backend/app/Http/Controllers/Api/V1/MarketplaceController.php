<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\WasteListing;
use App\Support\MarketplaceFeedQuery;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MarketplaceController extends Controller
{
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'wasteType' => ['sometimes', 'string', 'max:64'],
            'listingMode' => ['sometimes', 'string', 'in:fixed_price,bulk_contract,auction'],
            'minPrice' => ['sometimes', 'numeric', 'min:0'],
            'maxPrice' => ['sometimes', 'numeric', 'min:0'],
            'minQuantityKg' => ['sometimes', 'numeric', 'min:0'],
            'maxQuantityKg' => ['sometimes', 'numeric', 'min:0'],
            'sort' => ['sometimes', 'string', 'in:newest,price_desc,price_asc,nearest'],
            'latitude' => ['sometimes', 'numeric', 'between:-90,90'],
            'longitude' => ['sometimes', 'numeric', 'between:-180,180'],
            'maxDistanceKm' => ['sometimes', 'numeric', 'min:0.001', 'max:20000'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);

        $query = WasteListing::query()->with(['seller', 'currentHighestBidder']);

        MarketplaceFeedQuery::apply($query, $request);

        $paginator = $query->paginate(perPage: min((int) $request->query('per_page', 20), 100));

        $items = $paginator->getCollection()->map(fn (WasteListing $l) => $l->toMarketplaceArray())->values();

        return $this->success([
            'items' => $items,
            'page' => $paginator->currentPage(),
            'per_page' => $paginator->perPage(),
            'total' => $paginator->total(),
        ]);
    }
}
