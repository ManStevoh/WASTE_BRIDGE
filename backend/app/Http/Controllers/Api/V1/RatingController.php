<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\Rating;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RatingController extends Controller
{
    use RespondsWithJson;

    /**
     * Public rating history for a user (by public_id). Authenticated to reduce scraping.
     */
    public function index(Request $request, string $userPublicId): JsonResponse
    {
        $user = User::query()->where('public_id', $userPublicId)->firstOrFail();

        $paginator = Rating::query()
            ->where('ratee_user_id', $user->id)
            ->with([
                'rater:id,public_id,name',
                'pickupRequest:id,public_id',
            ])
            ->latest('created_at')
            ->paginate(perPage: min((int) $request->query('per_page', 20), 100));

        $items = $paginator->getCollection()->map(function (Rating $r) {
            return [
                'score' => (float) $r->score,
                'comment' => $r->comment,
                'createdAt' => $r->created_at?->toIso8601String(),
                'rater' => $r->rater !== null ? [
                    'id' => $r->rater->public_id,
                    'name' => $r->rater->name,
                ] : null,
                'pickupRequestId' => $r->pickupRequest?->public_id,
            ];
        })->values();

        return $this->success(
            ['items' => $items],
            [
                'page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ]
        );
    }
}
