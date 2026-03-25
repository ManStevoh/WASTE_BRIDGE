<?php

namespace App\Http\Controllers\Api\V1;

use App\Contracts\FileScanner;
use App\Exceptions\FileScanFailedException;
use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\KycSubmission;
use App\Services\AuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class KycSubmissionController extends Controller
{
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $paginator = KycSubmission::query()
            ->where('user_id', $user->id)
            ->latest()
            ->paginate(perPage: min((int) $request->query('per_page', 20), 100));

        $items = $paginator->getCollection()->map(fn (KycSubmission $k) => $k->toClientArray())->values();

        return $this->success(
            ['items' => $items],
            [
                'page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ]
        );
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'documentType' => ['required', 'string', 'max:64'],
            'document' => ['required', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:10240'],
        ]);

        $path = $request->file('document')->store('kyc/'.$user->id, 'local');
        $scanner = app(FileScanner::class);

        try {
            $scanner->assertClean(Storage::disk('local')->path($path));
        } catch (FileScanFailedException) {
            Storage::disk('local')->delete($path);

            return response()->json(['message' => 'File failed security scan.'], 422);
        }

        $submission = KycSubmission::query()->create([
            'user_id' => $user->id,
            'status' => 'pending',
            'document_type' => $validated['documentType'],
            'storage_path' => $path,
        ]);

        $user->update([
            'kyc_status' => 'pending',
        ]);

        AuditLogger::record($request, $user, 'kyc.submitted', KycSubmission::class, $submission->id, [
            'public_id' => $submission->public_id,
        ]);

        return $this->success($submission->fresh()->toClientArray());
    }

    public function show(Request $request, KycSubmission $kycSubmission): JsonResponse
    {
        $user = $request->user();

        if ($kycSubmission->user_id !== $user->id) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }

        return $this->success($kycSubmission->toClientArray());
    }
}
