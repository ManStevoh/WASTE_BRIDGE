<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\KycSubmission;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class AdminKycWebController extends Controller
{
    public function index(Request $request): View
    {
        $paginator = KycSubmission::query()
            ->with('user')
            ->latest()
            ->paginate(perPage: min((int) $request->query('per_page', 20), 100));

        return view('admin.kyc.index', [
            'submissions' => $paginator,
        ]);
    }

    public function show(KycSubmission $kycSubmission): View
    {
        $kycSubmission->load('user', 'reviewedBy');

        return view('admin.kyc.show', [
            'submission' => $kycSubmission,
        ]);
    }

    public function review(Request $request, KycSubmission $kycSubmission): RedirectResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', Rule::in(['approved', 'rejected'])],
            'rejectionReason' => ['required_if:status,rejected', 'nullable', 'string', 'max:2000'],
        ]);

        $admin = $request->user();

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

        return redirect()->route('admin.kyc.show', $kycSubmission)
            ->with('status', 'Submission updated.');
    }
}
