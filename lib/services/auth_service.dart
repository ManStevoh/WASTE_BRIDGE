import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/app_user.dart';
import 'package:waste_bridge/services/api_endpoints.dart';
import 'package:waste_bridge/services/mock_data.dart';

class AuthService {
  AuthService(this._dio);
  final Dio _dio;

  static const _userKey = 'current_user_email';
  static const _roleKey = 'selected_role';

  Future<AppUser?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_userKey);
    final roleName = prefs.getString(_roleKey);
    if (email == null || roleName == null) return null;
    return MockData.users.firstWhere(
      (u) => u.email == email && u.role.toString().split('.').last == roleName,
      orElse: () => MockData.users.first,
    );
  }

  Future<AppUser> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await _dio.post(ApiEndpoints.login, data: {
      'email': email,
      'password': password,
      'role': role.toString().split('.').last,
    });
    final user = MockData.users.firstWhere(
      (u) => u.role == role,
      orElse: () => AppUser(id: 'new', name: 'Demo User', email: email, role: role),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, user.email);
    await prefs.setString(_roleKey, role.toString().split('.').last);
    return user;
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await _dio.post(ApiEndpoints.register, data: {
      'name': name,
      'email': email,
      'password': password,
      'role': role.toString().split('.').last,
    });
    final newUser = AppUser(
      id: 'u-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      role: role,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, email);
    await prefs.setString(_roleKey, role.toString().split('.').last);
    return newUser;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_roleKey);
  }
}
