<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    use RespondsWithJson;

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'token' => ['required', 'string', 'max:512'],
            'platform' => ['nullable', 'string', 'max:32'],
        ]);

        DeviceToken::query()->updateOrCreate(
            [
                'user_id' => $user->id,
                'token' => $validated['token'],
            ],
            [
                'platform' => $validated['platform'] ?? null,
            ]
        );

        return $this->success(['registered' => true]);
    }

    public function destroy(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'token' => ['required', 'string', 'max:512'],
        ]);

        DeviceToken::query()
            ->where('user_id', $user->id)
            ->where('token', $validated['token'])
            ->delete();

        return $this->success(['removed' => true]);
    }
}
