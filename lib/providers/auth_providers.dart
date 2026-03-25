import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/app_user.dart';
import 'package:waste_bridge/providers/service_providers.dart';
import 'package:waste_bridge/services/auth_service.dart';

final selectedRoleProvider = StateProvider<UserRole>(
  (ref) => UserRole.generator,
);

class AuthNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  AuthNotifier(this._authService) : super(const AsyncValue.data(null)) {
    loadSavedUser();
  }

  final AuthService _authService;

  Future<void> loadSavedUser() async {
    final user = await _authService.getSavedUser();
    state = AsyncValue.data(user);
  }

  Future<void> login(String email, String password, UserRole role) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _authService.login(email: email, password: password, role: role),
    );
  }

  Future<void> register(
    String name,
    String email,
    String password,
    UserRole role, {
    String? phone,
    String? phoneVerificationToken,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _authService.register(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
        phoneVerificationToken: phoneVerificationToken,
      ),
    );
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AsyncValue.data(null);
  }

  /// Reload `/auth/me` (e.g. after KYC submit).
  Future<void> refreshFromServer() async {
    final user = await _authService.getSavedUser();
    state = AsyncValue.data(user);
  }

  /// PATCH `/auth/me` — name and optional collector availability.
  Future<AppUser> updateProfile({
    String? name,
    bool? collectorAvailable,
    String? phone,
    bool includePhone = false,
  }) async {
    final user = await _authService.updateProfile(
      name: name,
      collectorAvailable: collectorAvailable,
      phone: phone,
      includePhone: includePhone,
    );
    state = AsyncValue.data(user);
    return user;
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AppUser?>>((ref) {
      return AuthNotifier(ref.read(authServiceProvider));
    });
