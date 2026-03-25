import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:waste_bridge/services/api_endpoints.dart';

/// Registers FCM token with `POST /auth/device-token`.
class PushRegistrationService {
  PushRegistrationService(this._dio);
  final Dio _dio;

  static Future<void> setupFirebaseMessaging(Dio dio) async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await PushRegistrationService(dio).registerToken(token);
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        PushRegistrationService(dio).registerToken(t);
      });
    } catch (_) {
      // Firebase not configured or permission denied
    }
  }

  Future<void> registerToken(String token) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.authDeviceToken,
        data: <String, dynamic>{
          'token': token,
          'platform': defaultTargetPlatform.name,
        },
      );
    } catch (_) {}
  }

  Future<void> unregisterToken(String token) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        ApiEndpoints.authDeviceToken,
        data: <String, dynamic>{'token': token},
      );
    } catch (_) {}
  }
}
