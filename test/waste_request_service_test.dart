import 'package:flutter_test/flutter_test.dart';
import 'package:waste_bridge/core/network/api_client.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/services/mock_data.dart';
import 'package:waste_bridge/services/waste_request_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WasteRequestService lifecycle', () {
    test('request pickup computes scheduling, pricing, and impact', () async {
      final service = WasteRequestService(ApiClient().dio);
      final scheduledAt = DateTime.now().add(const Duration(hours: 5));

      final request = await service.requestPickup(
        wasteType: 'Plastic',
        quantityKg: 10,
        location: 'Lekki',
        scheduledAt: scheduledAt,
      );

      expect(request.status, RequestStatus.pending);
      expect(request.scheduledAt, isNotNull);
      expect(request.unitPricePerKg, isNotNull);
      expect(request.totalAmount, isNotNull);
      expect(request.co2SavedKg, greaterThan(0));
    });

    test('dispute can be reported and resolved', () async {
      final service = WasteRequestService(ApiClient().dio);
      final target = MockData.requests.first;

      await service.reportDispute(
        requestId: target.id,
        reason: 'Collector arrived late',
      );
      final afterReport = MockData.requests.firstWhere((r) => r.id == target.id);
      expect(afterReport.isDisputed, isTrue);
      expect(afterReport.disputeReason, 'Collector arrived late');

      await service.resolveDispute(requestId: target.id);
      final afterResolve = MockData.requests.firstWhere((r) => r.id == target.id);
      expect(afterResolve.isDisputed, isFalse);
      expect(afterResolve.paymentStatus, PaymentStatus.paid);
      expect(afterResolve.receiptId, isNotNull);
      expect(afterResolve.receiptIssuedAt, isNotNull);
    });
  });
}
