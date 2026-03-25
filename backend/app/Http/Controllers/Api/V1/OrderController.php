<?php

namespace App\Http\Controllers\Api\V1;

use App\Domain\Enums\MarketplaceOrderStatus;
use App\Http\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Services\AuditLogger;
use App\Services\EscrowService;
use App\Services\NotificationWriter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class OrderController extends Controller
{
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'scope' => ['sometimes', 'string', 'in:buyer,seller,all'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);

        $scope = $validated['scope'] ?? 'all';

        $query = Order::query()
            ->with(['seller', 'buyer', 'listing', 'pickupRequests.pickupJob'])
            ->latest();

        if ($scope === 'buyer') {
            $query->where('buyer_user_id', $user->id);
        } elseif ($scope === 'seller') {
            $query->where('seller_user_id', $user->id);
        } else {
            $query->where(function ($q) use ($user): void {
                $q->where('buyer_user_id', $user->id)
                    ->orWhere('seller_user_id', $user->id);
            });
        }

        $paginator = $query->paginate(perPage: min((int) $request->query('per_page', 20), 100));

        $items = $paginator->getCollection()->map(fn (Order $o) => $o->toDetailArray())->values();

        return $this->success([
            'items' => $items,
            'page' => $paginator->currentPage(),
            'per_page' => $paginator->perPage(),
            'total' => $paginator->total(),
        ]);
    }

    public function show(Request $request, Order $order): JsonResponse
    {
        $user = $request->user();

        if ($order->seller_user_id !== $user->id && $order->buyer_user_id !== $user->id) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }

        $order->load(['seller', 'buyer', 'listing', 'pickupRequests.pickupJob']);

        return $this->success($order->toDetailArray());
    }

    public function cancel(Request $request, Order $order): JsonResponse
    {
        $user = $request->user();

        if ($order->seller_user_id !== $user->id && $order->buyer_user_id !== $user->id) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }

        $current = MarketplaceOrderStatus::tryFrom($order->status);
        if ($current === null) {
            return response()->json(['message' => 'Invalid order state.'], 422);
        }

        if (! in_array($current, [MarketplaceOrderStatus::Created, MarketplaceOrderStatus::Accepted], true)) {
            return response()->json(['message' => 'This order cannot be cancelled.'], 422);
        }

        $order->load('pickupRequests.pickupJob');
        $pr = $order->pickupRequests->first();
        if ($pr !== null) {
            $job = $pr->pickupJob;
            if ($job !== null && ! in_array($job->status, ['open', 'accepted'], true)) {
                return response()->json(['message' => 'Job is in progress; cancellation is not available.'], 422);
            }
        }

        EscrowService::refundEscrowIfCancelled($order);
        $order->refresh();

        DB::transaction(function () use ($order, $pr, $user, $request): void {
            $o = Order::query()->lockForUpdate()->findOrFail($order->id);
            if ($o->status === MarketplaceOrderStatus::Cancelled->value) {
                return;
            }
            $o->status = MarketplaceOrderStatus::Cancelled->value;
            $o->save();

            if ($pr !== null) {
                $pr = $pr->fresh();
                $pr->status = 'cancelled';
                $pr->cancelled_at = now();
                $pr->save();
                $jb = $pr->pickupJob;
                if ($jb !== null) {
                    $jb->status = 'cancelled';
                    $jb->save();
                }
            }

            AuditLogger::record($request, $user, 'order.cancelled', Order::class, $o->id, [
                'public_id' => $o->public_id,
            ]);
        });

        $order->refresh()->load(['seller', 'buyer', 'listing', 'pickupRequests.pickupJob']);

        $otherPartyId = $order->buyer_user_id === $user->id ? $order->seller_user_id : $order->buyer_user_id;
        if ($otherPartyId !== null) {
            NotificationWriter::notify(
                $otherPartyId,
                'Order cancelled',
                'Order '.$order->public_id.' was cancelled.',
                'orderCancelled',
            );
        }

        return $this->success([
            'order' => $order->toDetailArray(),
        ]);
    }
}
