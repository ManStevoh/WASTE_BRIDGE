import 'package:dio/dio.dart';
import 'package:waste_bridge/models/app_notification.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

class NotificationService {
  NotificationService(this._dio);
  final Dio _dio;

  Future<List<AppNotification>> getNotifications() async {
    final response = await _dio.get(ApiEndpoints.notifications);
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
