import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waste_bridge/core/constants/app_constants.dart';

class ApiClient {
  ApiClient() : dio = Dio() {
    dio.options = BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(AppConstants.authAccessTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.data is! FormData) {
            options.headers['Content-Type'] = 'application/json';
          } else {
            options.headers.remove('Content-Type');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          final data = response.data;
          if (data is Map<String, dynamic> &&
              data['success'] == true &&
              data.containsKey('data')) {
            response.data = data['data'];
          }
          handler.next(response);
        },
      ),
    );
  }

  final Dio dio;
}
