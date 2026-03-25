import 'package:flutter/foundation.dart';

class AppConstants {
  static const appName = 'Waste Bridge';

  /// Override with `--dart-define=API_BASE_URL=https://.../api/v1`.
  /// Default host: Android emulator uses `10.0.2.2`; other platforms use `127.0.0.1`.
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    final host = switch (defaultTargetPlatform) {
      TargetPlatform.android => '10.0.2.2',
      _ => '127.0.0.1',
    };
    return 'http://$host:8000/api/v1';
  }

  static const authAccessTokenKey = 'auth_access_token';

  static const authRefreshTokenKey = 'auth_refresh_token';

  /// Matches Laravel `password` validation on `POST /auth/register` (`min:8`).
  static const int minRegisterPasswordLength = 8;
}
