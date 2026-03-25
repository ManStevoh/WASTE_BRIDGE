import 'package:dio/dio.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:waste_bridge/core/constants/app_constants.dart';

import 'package:waste_bridge/models/app_enums.dart';

import 'package:waste_bridge/models/app_user.dart';

import 'package:waste_bridge/services/api_endpoints.dart';



class AuthService {

  AuthService(this._dio);

  final Dio _dio;



  Future<AppUser?> getSavedUser() async {

    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString(AppConstants.authAccessTokenKey);

    if (token == null || token.isEmpty) return null;

    try {

      final response = await _dio.get(ApiEndpoints.me);

      return AppUser.fromJson(response.data as Map<String, dynamic>);

    } on DioException catch (e) {

      if (e.response?.statusCode == 401) {

        final refreshed = await refreshAccessToken();

        if (refreshed) {

          final retry = await _dio.get(ApiEndpoints.me);

          return AppUser.fromJson(retry.data as Map<String, dynamic>);

        }

        await _clearTokens();

      }

      return null;

    }

  }



  Future<AppUser> login({

    required String email,

    required String password,

    required UserRole role,

  }) async {

    final response = await _dio.post(

      ApiEndpoints.login,

      data: {

        'email': email,

        'password': password,

        'role': role.toString().split('.').last,

      },

    );

    final data = response.data as Map<String, dynamic>;

    final token = data['access_token'] as String;

    final refresh = data['refresh_token'] as String?;

    await _saveTokens(accessToken: token, refreshToken: refresh);

    return AppUser.fromJson(data['user'] as Map<String, dynamic>);

  }



  /// Optional [phone] + [phoneVerificationToken] must both be set after OTP verify
  /// (`POST /auth/otp/verify`); see [verifyOtp].
  Future<AppUser> register({

    required String name,

    required String email,

    required String password,

    required UserRole role,

    String? phone,

    String? phoneVerificationToken,

  }) async {

    final body = <String, dynamic>{

      'name': name,

      'email': email,

      'password': password,

      'role': role.toString().split('.').last,

    };

    if (phone != null &&

        phoneVerificationToken != null &&

        phone.isNotEmpty &&

        phoneVerificationToken.isNotEmpty) {

      body['phone'] = phone;

      body['phoneVerificationToken'] = phoneVerificationToken;

    }

    final response = await _dio.post(

      ApiEndpoints.register,

      data: body,

    );

    final data = response.data as Map<String, dynamic>;

    final token = data['access_token'] as String;

    final refresh = data['refresh_token'] as String?;

    await _saveTokens(accessToken: token, refreshToken: refresh);

    return AppUser.fromJson(data['user'] as Map<String, dynamic>);

  }

  /// Public route: `POST /auth/otp/request` — sends SMS (or logs in local env).
  Future<void> requestOtp({required String phone}) async {
    await _dio.post(
      ApiEndpoints.otpRequest,
      data: {'phone': phone.trim()},
    );
  }

  /// Public route: `POST /auth/otp/verify` — returns a token to send with [register].
  Future<({String verificationToken, String phone})> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.otpVerify,
      data: {
        'phone': phone.trim(),
        'code': code.trim(),
      },
    );
    final data = response.data as Map<String, dynamic>;
    return (
      verificationToken: data['verificationToken'] as String,
      phone: data['phone'] as String,
    );
  }

  /// Exchanges a refresh token for a new access + refresh pair (server rotates refresh tokens).

  Future<bool> refreshAccessToken() async {

    final prefs = await SharedPreferences.getInstance();

    final refresh = prefs.getString(AppConstants.authRefreshTokenKey);

    if (refresh == null || refresh.isEmpty) return false;

    try {

      final response = await _dio.post(

        ApiEndpoints.authRefresh,

        data: {'refresh_token': refresh},

      );

      final data = response.data as Map<String, dynamic>;

      final token = data['access_token'] as String;

      final nextRefresh = data['refresh_token'] as String?;

      await _saveTokens(accessToken: token, refreshToken: nextRefresh);

      return true;

    } on DioException {

      return false;

    }

  }



  Future<void> logout() async {

    try {

      await _dio.post(ApiEndpoints.logout);

    } catch (_) {}

    await _clearTokens();

  }



  Future<void> logoutAll() async {

    try {

      await _dio.post(ApiEndpoints.logoutAll);

    } catch (_) {}

    await _clearTokens();

  }



  /// PATCH `/auth/me` — e.g. [collectorAvailable] for collectors.

  Future<AppUser> updateProfile({
    String? name,
    bool? collectorAvailable,
    String? phone,
    bool includePhone = false,
  }) async {

    final body = <String, dynamic>{};

    if (name != null) body['name'] = name;

    if (includePhone) {
      final p = phone?.trim();
      body['phone'] = (p == null || p.isEmpty) ? null : p;
    }

    if (collectorAvailable != null) {

      body['collectorAvailable'] = collectorAvailable;

    }

    final response = await _dio.patch(ApiEndpoints.me, data: body);

    final data = response.data as Map<String, dynamic>;

    return AppUser.fromJson(data);

  }



  Future<void> _saveTokens({

    required String accessToken,

    String? refreshToken,

  }) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(AppConstants.authAccessTokenKey, accessToken);

    if (refreshToken != null) {

      await prefs.setString(AppConstants.authRefreshTokenKey, refreshToken);

    }

  }



  Future<void> _clearTokens() async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(AppConstants.authAccessTokenKey);

    await prefs.remove(AppConstants.authRefreshTokenKey);

  }

}

