import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

/// Client analytics (`POST /analytics/events`). Best-effort; never throws to callers.
class AnalyticsService {
  AnalyticsService(this._dio);
  final Dio _dio;

  Future<void> logEvent(
    String name, {
    Map<String, Object?>? properties,
    String? platform,
  }) async {
    try {
      final info = await PackageInfo.fromPlatform();
      await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.analyticsEvents,
        data: <String, dynamic>{
          'name': name,
          if (properties != null) 'properties': properties,
          if (platform != null) 'platform': platform,
          'appVersion': '${info.version}+${info.buildNumber}',
        },
      );
    } catch (_) {
      // ignore
    }
  }
}
