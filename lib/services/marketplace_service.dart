import 'package:dio/dio.dart';
import 'package:waste_bridge/models/marketplace_listing.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

/// Phase 3 marketplace feed (filters/sort match backend query params).
class MarketplaceService {
  MarketplaceService(this._dio);
  final Dio _dio;

  Future<MarketplaceFeedPage> getFeed({
    String? wasteType,
    double? minPrice,
    double? maxPrice,
    double? minQuantityKg,
    double? maxQuantityKg,
    String sort = 'newest',
    double? latitude,
    double? longitude,
    double? maxDistanceKm,
    int perPage = 20,
  }) async {
    final query = <String, dynamic>{
      if (wasteType != null) 'wasteType': wasteType,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      if (minQuantityKg != null) 'minQuantityKg': minQuantityKg,
      if (maxQuantityKg != null) 'maxQuantityKg': maxQuantityKg,
      'sort': sort,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (maxDistanceKm != null) 'maxDistanceKm': maxDistanceKm,
      'per_page': perPage,
    };

    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.marketplace,
      queryParameters: query,
    );
    final data = response.data;
    if (data == null) {
      return const MarketplaceFeedPage(items: [], page: 1, perPage: 20, total: 0);
    }
    return MarketplaceFeedPage.fromJson(data);
  }
}
