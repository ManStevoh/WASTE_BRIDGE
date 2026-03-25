import 'package:flutter_test/flutter_test.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/app_user.dart';

void main() {
  group('AppUser JSON (v1 API shape)', () {
    test('parses backend /auth/me payload', () {
      final user = AppUser.fromJson({
        'id': '01HZTESTUSER000000000000000',
        'name': 'Amina Yusuf',
        'email': 'amina@example.com',
        'role': 'generator',
        'kycStatus': 'verified',
        'isVerified': true,
        'subscriptionPlan': 'Free',
        'referralCode': 'REF-1',
      });

      expect(user.id, '01HZTESTUSER000000000000000');
      expect(user.role, UserRole.generator);
      expect(user.kycStatus, KycStatus.verified);
      expect(user.isVerified, isTrue);
    });
  });
}
