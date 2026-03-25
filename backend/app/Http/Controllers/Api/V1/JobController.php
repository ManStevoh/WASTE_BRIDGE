<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\PickupJob;
use App\Services\AuditLogger;
use App\Services\NotificationWriter;
use App\Support\OrderLifecycle;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class JobController extends Controller
{
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $paginator = PickupJob::query()
            ->with(['pickupRequest', 'order'])
            ->where(function ($q) use ($user) {
                $q->where('status', 'open')
                    ->orWhere('collector_user_id', $user->id);
            })
            ->latest()
            ->paginate(perPage: min((int) $request->query('per_page', 20), 100));

        $items = $paginator->getCollection()->map(fn (PickupJob $j) => $j->toJobArray())->values();

        return $this->success(
            ['items' => $items],
            [
                'page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ]
        );
    }

    public function accept(Request $request, PickupJob $pickupJob): JsonResponse
    {
        $user = $request->user();

        if ($pickupJob->status === 'cancelled') {
            return response()->json(['message' => 'Job was cancelled.'], 422);
        }

        if ($pickupJob->status !== 'open') {
            return response()->json(['message' => 'Job is not open for acceptance.'], 422);
        }

        $pickupJob->collector_user_id = $user->id;
        $pickupJob->status = 'accepted';
        $pickupJob->save();

        $this->syncPickupRequestFromJob($pickupJob);
        $pickupJob->refresh();
        OrderLifecycle::syncLinkedOrder($pickupJob);

        $pickupJob->load('pickupRequest');
        $generatorId = $pickupJob->pickupRequest->generator_user_id;
        NotificationWriter::notify(
            $generatorId,
            'Pickup Assigned',
            'A collector accepted request '.$pickupJob->pickupRequest->public_id.'.',
            'pickupAssigned',
        );
        AuditLogger::record($request, $user, 'job.accepted', PickupJob::class, $pickupJob->id, [
            'pickup_request_public_id' => $pickupJob->pickupRequest->public_id,
        ]);

        return $this->success($pickupJob->fresh(['pickupRequest', 'order'])->toJobArray());
    }

    /**
     * Plan alias for {@see accept()}: accepts JSON `{ "jobPublicId": "..." }` instead of a route param.
     */
    public function acceptByPublicId(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'jobPublicId' => ['required', 'string', 'max:36'],
        ]);

        $pickupJob = PickupJob::query()->where('public_id', $validated['jobPublicId'])->firstOrFail();

        return $this->accept($request, $pickupJob);
    }

    public function update(Request $request, PickupJob $pickupJob): JsonResponse
    {
        $user = $request->user();

        if ($pickupJob->collector_user_id !== $user->id) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }

        $validated = $request->validate([
            'status' => ['required', 'string', Rule::in(['arrived', 'picked', 'delivered'])],
        ]);

        $next = $validated['status'];

        if (! $this->canTransition($pickupJob->status, $next)) {
            return response()->json([
                'message' => 'Invalid status transition from '.$pickupJob->status.' to '.$next.'.',
            ], 422);
        }

        $pickupJob->status = $next;
        $pickupJob->save();

        $this->syncPickupRequestFromJob($pickupJob);
        $pickupJob->refresh();
        OrderLifecycle::syncLinkedOrder($pickupJob);

        $pickupJob->load('pickupRequest');
        $generatorId = $pickupJob->pickupRequest->generator_user_id;
        $reqPublicId = $pickupJob->pickupRequest->public_id;
        $type = match ($next) {
            'delivered' => 'deliveryCompleted',
            default => 'collectorArriving',
        };
        $title = match ($next) {
            'delivered' => 'Delivery Completed',
            default => 'Collector Status Updated',
        };
        NotificationWriter::notify(
            $generatorId,
            $title,
            'Request '.$reqPublicId.' is now '.$next.'.',
            $type,
        );
        AuditLogger::record($request, $user, 'job.status_updated', PickupJob::class, $pickupJob->id, [
            'status' => $next,
            'pickup_request_public_id' => $reqPublicId,
        ]);

        return $this->success($pickupJob->fresh(['pickupRequest', 'order'])->toJobArray());
    }

    private function canTransition(string $from, string $to): bool
    {
        return match ($from) {
            'accepted' => $to === 'arrived',
            'arrived' => $to === 'picked',
            'picked' => $to === 'delivered',
            default => false,
        };
    }

    private function syncPickupRequestFromJob(PickupJob $job): void
    {
        $req = $job->pickupRequest;
        $req->assigned_collector_user_id = $job->collector_user_id;

        switch ($job->status) {
            case 'accepted':
                $req->status = 'accepted';
                $req->accepted_at = $req->accepted_at ?? now();
                break;
            case 'arrived':
                $req->status = 'accepted';
                break;
            case 'picked':
                $req->status = 'pickedUp';
                $req->picked_up_at = now();
                break;
            case 'delivered':
                $req->status = 'completed';
                $req->completed_at = now();
                if ($req->payment_status !== 'paid') {
                    $req->payment_status = 'pending';
                }
                break;
        }

        $req->save();
    }
}
