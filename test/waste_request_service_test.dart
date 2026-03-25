import 'package:flutter_test/flutter_test.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/waste_request.dart';

void main() {
  group('WasteRequest JSON (v1 API shape)', () {
    test('parses list item from GET /requests', () {
      final r = WasteRequest.fromJson({
        'id': 'wr-01hzabc',
        'wasteType': 'Plastic',
        'quantityKg': 10,
        'location': 'Yaba',
        'status': 'pending',
        'createdAt': '2025-03-24T12:00:00.000',
        'paymentStatus': 'unpaid',
        'isDisputed': false,
        'co2SavedKg': 18,
      });

      expect(r.status, RequestStatus.pending);
      expect(r.paymentStatus, PaymentStatus.unpaid);
      expect(r.co2SavedKg, 18);
    });
  });
}
