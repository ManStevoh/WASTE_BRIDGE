<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Http\Request;

final class AuditLogger
{
    /**
     * @param  array<string, mixed>  $metadata
     */
    public static function record(
        Request $request,
        ?User $actor,
        string $action,
        ?string $subjectType = null,
        ?int $subjectId = null,
        array $metadata = [],
    ): void {
        AuditLog::query()->create([
            'actor_user_id' => $actor?->id,
            'action' => $action,
            'subject_type' => $subjectType,
            'subject_id' => $subjectId,
            'metadata' => $metadata === [] ? null : $metadata,
            'ip_address' => $request->ip(),
            'created_at' => now(),
        ]);
    }

    /**
     * @param  array<string, mixed>  $metadata
     */
    public static function recordSystem(
        ?User $actor,
        string $action,
        ?string $subjectType = null,
        ?int $subjectId = null,
        array $metadata = [],
        ?string $ipAddress = null,
    ): void {
        $ip = $ipAddress ?? request()?->ip();

        AuditLog::query()->create([
            'actor_user_id' => $actor?->id,
            'action' => $action,
            'subject_type' => $subjectType,
            'subject_id' => $subjectId,
            'metadata' => $metadata === [] ? null : $metadata,
            'ip_address' => $ip,
            'created_at' => now(),
        ]);
    }
}
