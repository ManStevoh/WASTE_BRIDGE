import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/models/marketplace_listing.dart';
import 'package:waste_bridge/models/marketplace_order_detail.dart';
import 'package:waste_bridge/providers/service_providers.dart';

final transactionsProvider = FutureProvider((ref) {
  return ref.read(transactionServiceProvider).getTransactions();
});

/// Sort: `newest`, `price_desc`, `price_asc`, `nearest` (with GPS).
final marketplaceSortProvider = StateProvider<String>((ref) => 'newest');

/// Optional: `fixed_price`, `bulk_contract`, `auction`, or null for all.
final marketplaceListingModeProvider = StateProvider<String?>((ref) => null);

/// Recycler marketplace browse (Phase 3). Refetch after auth changes.
final marketplaceFeedProvider =
    FutureProvider.autoDispose<MarketplaceFeedPage>((ref) {
      final sort = ref.watch(marketplaceSortProvider);
      final mode = ref.watch(marketplaceListingModeProvider);
      return ref.read(marketplaceServiceProvider).getFeed(
            sort: sort,
            listingMode: mode,
          );
    });

/// Orders where the current user is the buyer (recycler purchases).
final buyerOrdersProvider = FutureProvider.autoDispose<OrderListPage>((ref) {
  return ref.read(orderServiceProvider).listOrders(scope: 'buyer');
});

final orderDetailProvider = FutureProvider.autoDispose
    .family<MarketplaceOrderDetail, String>((ref, orderPublicId) {
      return ref.read(orderServiceProvider).getOrder(orderPublicId);
    });
