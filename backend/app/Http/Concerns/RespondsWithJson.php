<?php

namespace App\Http\Concerns;

use Illuminate\Http\JsonResponse;

trait RespondsWithJson
{
    protected function success(mixed $data, ?array $meta = null, ?string $message = null): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $data,
            'message' => $message,
            'meta' => $meta,
        ]);
    }
}
