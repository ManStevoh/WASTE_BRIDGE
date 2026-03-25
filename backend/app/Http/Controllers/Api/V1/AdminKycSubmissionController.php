<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\KycSubmission;
use App\Services\AuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AdminKycSubmissionController extends Controller
{
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        $paginator = KycSubmission::query()
            ->with('user')
            ->latest()
            ->paginate(perPage: min((int) $request->query('per_page', 20), 100));

        $items = $paginator->getCollection()->map(fn (KycSubmission $k) => $k->toAdminArray())->values();

        return $this->success(
            ['items' => $items],
            [
                'page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ]
        );
    }

    public function review(Request $request, KycSubmission $kycSubmission): JsonResponse
    {
        $admin = $request->user();

        $validated = $request->validate([
            'status' => ['required', 'string', Rule::in(['approved', 'rejected'])],
            'rejectionReason' => ['required_if:status,rejected', 'nullable', 'string', 'max:2000'],
        ]);

        $kycSubmission->update([
            'status' => $validated['status'] === 'approved' ? 'approved' : 'rejected',
            'reviewed_by_user_id' => $admin->id,
            'reviewed_at' => now(),
            'rejection_reason' => $validated['status'] === 'rejected' ? ($validated['rejectionReason'] ?? null) : null,
        ]);

        $user = $kycSubmission->user;
        if ($validated['status'] === 'approved') {
            $user->update([
                'kyc_status' => 'verified',
                'is_verified' => true,
            ]);
        } else {
            $user->update([
                'kyc_status' => 'rejected',
            ]);
        }

        AuditLogger::record($request, $admin, 'kyc.reviewed', KycSubmission::class, $kycSubmission->id, [
            'target_user_id' => $user->id,
            'status' => $validated['status'],
        ]);

        return $this->success($kycSubmission->fresh()->toAdminArray());
    }
}
