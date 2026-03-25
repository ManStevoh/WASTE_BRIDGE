import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/models/marketplace_listing.dart';
import 'package:waste_bridge/models/marketplace_order_detail.dart';
import 'package:waste_bridge/providers/service_providers.dart';

final transactionsProvider = FutureProvider((ref) {
  return ref.read(transactionServiceProvider).getTransactions();
});

/// Recycler marketplace browse (Phase 3). Refetch after auth changes.
final marketplaceFeedProvider =
    FutureProvider.autoDispose<MarketplaceFeedPage>((ref) {
      return ref.read(marketplaceServiceProvider).getFeed();
    });

/// Orders where the current user is the buyer (recycler purchases).
final buyerOrdersProvider = FutureProvider.autoDispose<OrderListPage>((ref) {
  return ref.read(orderServiceProvider).listOrders(scope: 'buyer');
});

final orderDetailProvider = FutureProvider.autoDispose
    .family<MarketplaceOrderDetail, String>((ref, orderPublicId) {
      return ref.read(orderServiceProvider).getOrder(orderPublicId);
    });
