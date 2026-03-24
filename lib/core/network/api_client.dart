import 'package:dio/dio.dart';
import 'package:waste_bridge/core/constants/app_constants.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

class ApiClient {
  ApiClient() : dio = Dio(_options) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: _mockPayload(options.path),
            ),
          );
        },
      ),
    );
  }

  static final _options = BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: const {'Content-Type': 'application/json'},
  );

  final Dio dio;

  Map<String, dynamic> _mockPayload(String path) {
    switch (path) {
      case ApiEndpoints.login:
      case ApiEndpoints.register:
      case ApiEndpoints.requestPickup:
      case ApiEndpoints.acceptJob:
      case ApiEndpoints.updateStatus:
        return {'success': true};
      case ApiEndpoints.requests:
      case ApiEndpoints.jobs:
        return {'items': []};
      default:
        return {'ok': true};
    }
  }
}
