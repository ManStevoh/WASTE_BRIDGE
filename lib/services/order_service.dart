import 'package:dio/dio.dart';
import 'package:waste_bridge/models/marketplace_order_detail.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

class OrderService {
  OrderService(this._dio);
  final Dio _dio;

  Future<OrderListPage> listOrders({
    String scope = 'all',
    int perPage = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.orders,
      queryParameters: <String, dynamic>{
        'scope': scope,
        'per_page': perPage,
      },
    );
    final data = response.data;
    if (data == null) {
      return const OrderListPage(items: [], page: 1, perPage: 20, total: 0);
    }
    return OrderListPage.fromJson(data);
  }

  Future<MarketplaceOrderDetail> getOrder(String orderPublicId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.order(orderPublicId),
    );
    final data = response.data;
    if (data == null) {
      throw StateError('Empty order response');
    }
    return MarketplaceOrderDetail.fromJson(data);
  }

  Future<MarketplaceOrderDetail> purchaseListing({
    required String listingPublicId,
    double? quantityKg,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.marketplacePurchase,
      data: <String, dynamic>{
        'listingPublicId': listingPublicId,
        if (quantityKg != null) 'quantityKg': quantityKg,
      },
    );
    final data = response.data;
    final order = data?['order'];
    if (order is! Map<String, dynamic>) {
      throw StateError('Invalid purchase response');
    }
    return MarketplaceOrderDetail.fromJson(order);
  }

  /// Place a bid on an open auction listing (recycler).
  Future<void> placeBid({
    required String listingPublicId,
    required double amount,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.marketplaceBid(listingPublicId),
      data: <String, dynamic>{'amount': amount},
    );
  }

  Future<MarketplaceOrderDetail> cancelOrder(String orderPublicId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.orderCancel(orderPublicId),
    );
    final data = response.data;
    final order = data?['order'];
    if (order is! Map<String, dynamic>) {
      throw StateError('Invalid cancel response');
    }
    return MarketplaceOrderDetail.fromJson(order);
  }
}
