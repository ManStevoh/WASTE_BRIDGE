<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $paginator = AppNotification::query()
            ->where('user_id', $user->id)
            ->latest()
            ->paginate(perPage: min((int) $request->query('per_page', 30), 100));

        $items = $paginator->getCollection()->map(fn (AppNotification $n) => $n->toApiArray())->values();

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
