import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waste_bridge/core/network/api_client.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('login persists user and role', () async {
      final service = AuthService(ApiClient().dio);

      final user = await service.login(
        email: 'amina@generator.com',
        password: '123456',
        role: UserRole.generator,
      );

      expect(user.role, UserRole.generator);

      final saved = await service.getSavedUser();
      expect(saved, isNotNull);
      expect(saved!.role, UserRole.generator);
    });

    test('register returns selected role user', () async {
      final service = AuthService(ApiClient().dio);

      final user = await service.register(
        name: 'Phase Two User',
        email: 'phase2@test.com',
        password: 'password',
        role: UserRole.collector,
      );

      expect(user.name, 'Phase Two User');
      expect(user.role, UserRole.collector);
    });
  });
}
