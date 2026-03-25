import 'package:dio/dio.dart';
import 'package:waste_bridge/models/user_rating.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

class RatingsService {
  RatingsService(this._dio);

  final Dio _dio;

  Future<List<UserRating>> getUserRatings(String userPublicId) async {
    final response = await _dio.get(ApiEndpoints.userRatings(userPublicId));
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => UserRating.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
