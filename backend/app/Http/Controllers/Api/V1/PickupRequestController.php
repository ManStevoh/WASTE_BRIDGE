<?php

namespace App\Http\Controllers\Api\V1;

use App\Contracts\FileScanner;
use App\Domain\Enums\MarketplaceOrderStatus;
use App\Exceptions\FileScanFailedException;
use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\PickupJob;
use App\Models\PickupRequest;
use App\Models\Rating;
use App\Models\WasteListing;
use App\Services\AuditLogger;
use App\Services\EscrowService;
use App\Services\NotificationWriter;
use App\Support\OrderLifecycle;
use App\Support\PickupPricing;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class PickupRequestController extends Controller
{
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $paginator = PickupRequest::query()
            ->where('generator_user_id', $user->id)
            ->latest()
            ->paginate(perPage: min((int) $request->query('per_page', 20), 100));

        $items = $paginator->getCollection()->map(fn (PickupRequest $r) => $r->toWasteRequestArray())->values();

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
            'wasteType' => ['required_without:listingPublicId', 'nullable', 'string', 'max:64'],
            'quantityKg' => ['required_without:listingPublicId', 'nullable', 'numeric', 'min:0.001'],
            'location' => ['required_without:listingPublicId', 'nullable', 'string', 'max:512'],
            'listingPublicId' => ['nullable', 'string', 'max:36'],
            'scheduledAt' => ['nullable', 'date'],
        ]);

        $listing = null;
        if (! empty($validated['listingPublicId'])) {
            $listing = WasteListing::query()
                ->where('public_id', $validated['listingPublicId'])
                ->where('user_id', $user->id)
                ->firstOrFail();
        }

        $wasteType = $listing !== null ? $listing->waste_type : (string) $validated['wasteType'];
        $quantity = $listing !== null ? (float) $listing->quantity_kg : (float) $validated['quantityKg'];
        $location = $listing !== null ? $listing->location_text : (string) $validated['location'];

        $distanceKm = PickupPricing::estimateDistanceKm($location);
        $unitPrice = PickupPricing::unitPricePerKg($wasteType, $distanceKm);
        $totalAmount = round($unitPrice * $quantity, 2);
        $co2 = PickupPricing::co2SavedKg($wasteType, $quantity);
        $suggested = PickupPricing::suggestCollectorName($wasteType, $quantity);
        $earning = PickupPricing::collectorEarning($totalAmount);

        $pickup = DB::transaction(function () use ($user, $validated, $listing, $distanceKm, $unitPrice, $totalAmount, $co2, $suggested, $earning, $quantity, $wasteType, $location) {
            $scheduled = isset($validated['scheduledAt'])
                ? new \DateTimeImmutable($validated['scheduledAt'])
                : null;

            $order = null;
            if ($listing !== null) {
                $subtotal = $listing->total_price;
                if ($subtotal === null && $listing->unit_price_per_kg !== null) {
                    $subtotal = round((float) $listing->unit_price_per_kg * (float) $listing->quantity_kg, 2);
                }
                $order = Order::create([
                    'seller_user_id' => $user->id,
                    'buyer_user_id' => null,
                    'listing_id' => $listing->id,
                    'status' => MarketplaceOrderStatus::Created->value,
                    'subtotal_amount' => $subtotal,
                    'currency' => 'KES',
                ]);
            }

            $pr = PickupRequest::create([
                'generator_user_id' => $user->id,
                'listing_id' => $listing?->id,
                'order_id' => $order?->id,
                'waste_type' => $wasteType,
                'quantity_kg' => $quantity,
                'location' => $location,
                'status' => 'pending',
                'scheduled_at' => $scheduled?->format('Y-m-d H:i:s'),
                'distance_km' => $distanceKm,
                'unit_price_per_kg' => $unitPrice,
                'total_amount' => $totalAmount,
                'payment_status' => 'unpaid',
                'suggested_collector_name' => $suggested,
                'estimated_eta_minutes' => 25,
                'co2_saved_kg' => $co2,
            ]);

            $job = PickupJob::create([
                'pickup_request_id' => $pr->id,
                'order_id' => $order?->id,
                'pickup_location' => $pr->location,
                'waste_type' => $pr->waste_type,
                'quantity_kg' => $pr->quantity_kg,
                'earning' => $earning,
                'status' => 'open',
            ]);

            OrderLifecycle::syncLinkedOrder($job);

            return $pr->fresh();
        });

        NotificationWriter::notify(
            $user->id,
            'Pickup Requested',
            'Request '.$pickup->public_id.' has been created and is pending assignment.',
            'pickupAssigned',
        );
        AuditLogger::record($request, $user, 'pickup_request.created', PickupRequest::class, $pickup->id);

        return $this->success($pickup->toWasteRequestArray());
    }

    public function uploadProof(Request $request, PickupRequest $pickupRequest): JsonResponse
    {
        $user = $request->user();
        $this->authorizePickup($user->id, $pickupRequest);

        $validated = $request->validate([
            'before_photo' => ['nullable', 'file', 'image', 'max:5120'],
            'after_photo' => ['nullable', 'file', 'image', 'max:5120'],
            'beforePickupPhotoUrl' => ['nullable', 'string', 'max:1024'],
            'afterPickupPhotoUrl' => ['nullable', 'string', 'max:1024'],
        ]);

        $scanner = app(FileScanner::class);
        $storedForScan = [];

        try {
            if ($request->hasFile('before_photo')) {
                $path = $request->file('before_photo')->store(
                    'pickup-proofs/'.$pickupRequest->id,
                    'public',
                );
                $storedForScan[] = $path;
                $scanner->assertClean(Storage::disk('public')->path($path));
                $pickupRequest->before_pickup_photo_url = url(Storage::disk('public')->url($path));
            } elseif (array_key_exists('beforePickupPhotoUrl', $validated) && $validated['beforePickupPhotoUrl'] !== null) {
                $pickupRequest->before_pickup_photo_url = $validated['beforePickupPhotoUrl'];
            }

            if ($request->hasFile('after_photo')) {
                $path = $request->file('after_photo')->store(
                    'pickup-proofs/'.$pickupRequest->id,
                    'public',
                );
                $storedForScan[] = $path;
                $scanner->assertClean(Storage::disk('public')->path($path));
                $pickupRequest->after_pickup_photo_url = url(Storage::disk('public')->url($path));
            } elseif (array_key_exists('afterPickupPhotoUrl', $validated) && $validated['afterPickupPhotoUrl'] !== null) {
                $pickupRequest->after_pickup_photo_url = $validated['afterPickupPhotoUrl'];
            }
        } catch (FileScanFailedException) {
            foreach ($storedForScan as $p) {
                Storage::disk('public')->delete($p);
            }

            return response()->json(['message' => 'File failed security scan.'], 422);
        }

        $pickupRequest->save();

        AuditLogger::record(
            $request,
            $user,
            'pickup_request.proof_uploaded',
            PickupRequest::class,
            $pickupRequest->id,
            ['public_id' => $pickupRequest->public_id],
        );

        return $this->success($pickupRequest->fresh()->toWasteRequestArray());
    }

    public function submitRatings(Request $request, PickupRequest $pickupRequest): JsonResponse
    {
        $user = $request->user();
        $this->authorizePickup($user->id, $pickupRequest);

        $validated = $request->validate([
            'generatorRating' => ['nullable', 'numeric', 'between:0,5'],
            'collectorRating' => ['nullable', 'numeric', 'between:0,5'],
        ]);

        $pickupRequest->fill([
            'generator_rating' => $validated['generatorRating'] ?? $pickupRequest->generator_rating,
            'collector_rating' => $validated['collectorRating'] ?? $pickupRequest->collector_rating,
        ]);
        $pickupRequest->save();

        $pickupRequest->loadMissing('pickupJob');
        if (isset($validated['generatorRating']) && $pickupRequest->assigned_collector_user_id !== null) {
            Rating::query()->updateOrCreate(
                [
                    'pickup_request_id' => $pickupRequest->id,
                    'rater_user_id' => $user->id,
                ],
                [
                    'job_id' => $pickupRequest->pickupJob?->id,
                    'ratee_user_id' => $pickupRequest->assigned_collector_user_id,
                    'score' => (float) $validated['generatorRating'],
                    'comment' => null,
                    'created_at' => now(),
                ],
            );
        }

        return $this->success($pickupRequest->fresh()->toWasteRequestArray());
    }

    public function dispute(Request $request, PickupRequest $pickupRequest): JsonResponse
    {
        $user = $request->user();
        $this->authorizePickup($user->id, $pickupRequest);

        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:2000'],
        ]);

        $pickupRequest->update([
            'is_disputed' => true,
            'dispute_reason' => $validated['reason'],
        ]);

        if ($pickupRequest->order_id !== null) {
            $order = Order::query()->find($pickupRequest->order_id);
            if ($order !== null) {
                $order->status = MarketplaceOrderStatus::Disputed->value;
                if ($order->escrow_status === 'held') {
                    $order->escrow_status = 'disputed';
                }
                $order->save();
            }
        }

        AuditLogger::record(
            $request,
            $user,
            'pickup_request.dispute_opened',
            PickupRequest::class,
            $pickupRequest->id,
            ['public_id' => $pickupRequest->public_id],
        );

        return $this->success($pickupRequest->fresh()->toWasteRequestArray());
    }

    public function resolveDispute(Request $request, PickupRequest $pickupRequest): JsonResponse
    {
        $user = $request->user();
        if ($user->role !== 'generator' || $pickupRequest->generator_user_id !== $user->id) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }

        $pickupRequest->update([
            'is_disputed' => false,
            'dispute_reason' => null,
            'payment_status' => 'paid',
            'receipt_id' => $pickupRequest->receipt_id ?? 'RCPT-'.strtoupper($pickupRequest->public_id),
            'receipt_issued_at' => now(),
        ]);

        if ($pickupRequest->order_id !== null) {
            $order = Order::query()->find($pickupRequest->order_id);
            if ($order !== null) {
                $order->status = MarketplaceOrderStatus::Completed->value;
                if ($order->escrow_status === 'disputed' && $order->escrow_amount !== null) {
                    $order->escrow_status = 'held';
                }
                $order->save();
                EscrowService::releaseEscrowIfDue($order->fresh());
            }
        }

        AuditLogger::record(
            $request,
            $user,
            'pickup_request.dispute_resolved',
            PickupRequest::class,
            $pickupRequest->id,
            ['public_id' => $pickupRequest->public_id],
        );

        return $this->success($pickupRequest->fresh()->toWasteRequestArray());
    }

    private function authorizePickup(int $userId, PickupRequest $pickupRequest): void
    {
        if ($pickupRequest->generator_user_id !== $userId) {
            abort(403, 'Forbidden.');
        }
    }
}
