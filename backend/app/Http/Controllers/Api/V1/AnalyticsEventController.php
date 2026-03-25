<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AnalyticsEventController extends Controller
{
    use RespondsWithJson;

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:128'],
            'properties' => ['nullable', 'array'],
            'platform' => ['nullable', 'string', 'max:32'],
            'appVersion' => ['nullable', 'string', 'max:32'],
        ]);

        DB::table('analytics_events')->insert([
            'user_id' => $user->id,
            'name' => $validated['name'],
            'properties' => isset($validated['properties'])
                ? json_encode($validated['properties'], JSON_THROW_ON_ERROR)
                : null,
            'platform' => $validated['platform'] ?? null,
            'app_version' => $validated['appVersion'] ?? null,
            'created_at' => now(),
        ]);

        return $this->success(['recorded' => true]);
    }
}
