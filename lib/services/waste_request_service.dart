import 'dart:async';

import 'package:dio/dio.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/waste_request.dart';
import 'package:waste_bridge/services/api_endpoints.dart';
import 'package:waste_bridge/services/mock_data.dart';

class WasteRequestService {
  WasteRequestService(this._dio);
  final Dio _dio;

  Future<List<WasteRequest>> getRequests() async {
    await _dio.get(ApiEndpoints.requests);
    return List<WasteRequest>.from(MockData.requests);
  }

  Future<WasteRequest> requestPickup({
    required String wasteType,
    required double quantityKg,
    required String location,
    DateTime? scheduledAt,
  }) async {
    await _dio.post(
      ApiEndpoints.requestPickup,
      data: {
        'wasteType': wasteType,
        'quantityKg': quantityKg,
        'location': location,
        'scheduledAt': scheduledAt?.toIso8601String(),
      },
    );
    final distanceKm = _estimateDistanceKm(location);
    final unitPricePerKg = _priceFor(wasteType, distanceKm);
    final totalAmount = unitPricePerKg * quantityKg;
    final request = WasteRequest(
      id: 'wr-${DateTime.now().millisecondsSinceEpoch}',
      wasteType: wasteType,
      quantityKg: quantityKg,
      location: location,
      status: RequestStatus.pending,
      createdAt: DateTime.now(),
      suggestedCollectorName: _suggestCollector(wasteType, quantityKg),
      estimatedEtaMinutes: 25,
      scheduledAt: scheduledAt,
      distanceKm: distanceKm,
      unitPricePerKg: unitPricePerKg,
      totalAmount: totalAmount,
      co2SavedKg: _estimateCo2Savings(wasteType, quantityKg),
    );
    MockData.requests.insert(0, request);
    return request;
  }

  Future<void> reportDispute({
    required String requestId,
    required String reason,
  }) async {
    await _dio.post('/requests/$requestId/dispute', data: {'reason': reason});
    final index = MockData.requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;
    MockData.requests[index] = MockData.requests[index].copyWith(
      isDisputed: true,
      disputeReason: reason,
    );
  }

  Future<void> resolveDispute({
    required String requestId,
  }) async {
    await _dio.post('/requests/$requestId/dispute/resolve');
    final index = MockData.requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;
    MockData.requests[index] = MockData.requests[index].copyWith(
      isDisputed: false,
      disputeReason: null,
      paymentStatus: PaymentStatus.paid,
      receiptId: MockData.requests[index].receiptId ?? 'RCPT-${requestId.toUpperCase()}',
      receiptIssuedAt: DateTime.now(),
    );
  }

  Future<WasteRequest> updateRequestStatus({
    required String requestId,
    required RequestStatus status,
  }) async {
    await _dio.post(
      ApiEndpoints.updateStatus,
      data: {'requestId': requestId, 'status': status.name},
    );
    final index = MockData.requests.indexWhere((r) => r.id == requestId);
    if (index < 0) throw Exception('Request not found');
    final now = DateTime.now();
    final current = MockData.requests[index];
    final updated = current.copyWith(
      status: status,
      acceptedAt: status == RequestStatus.accepted ? now : current.acceptedAt,
      pickedUpAt: status == RequestStatus.pickedUp ? now : current.pickedUpAt,
      completedAt: status == RequestStatus.completed ? now : current.completedAt,
      cancelledAt: status == RequestStatus.cancelled ? now : current.cancelledAt,
    );
    MockData.requests[index] = updated;
    return updated;
  }

  Future<WasteRequest> uploadPhotoProof({
    required String requestId,
    String? beforePickupPhotoUrl,
    String? afterPickupPhotoUrl,
  }) async {
    await _dio.post(
      ApiEndpoints.updateStatus,
      data: {
        'requestId': requestId,
        'beforePickupPhotoUrl': beforePickupPhotoUrl,
        'afterPickupPhotoUrl': afterPickupPhotoUrl,
      },
    );
    final index = MockData.requests.indexWhere((r) => r.id == requestId);
    if (index < 0) throw Exception('Request not found');
    final current = MockData.requests[index];
    final updated = current.copyWith(
      beforePickupPhotoUrl: beforePickupPhotoUrl ?? current.beforePickupPhotoUrl,
      afterPickupPhotoUrl: afterPickupPhotoUrl ?? current.afterPickupPhotoUrl,
    );
    MockData.requests[index] = updated;
    return updated;
  }

  Future<WasteRequest> submitRatings({
    required String requestId,
    double? generatorRating,
    double? collectorRating,
  }) async {
    await _dio.post(
      ApiEndpoints.updateStatus,
      data: {
        'requestId': requestId,
        'generatorRating': generatorRating,
        'collectorRating': collectorRating,
      },
    );
    final index = MockData.requests.indexWhere((r) => r.id == requestId);
    if (index < 0) throw Exception('Request not found');
    final current = MockData.requests[index];
    final updated = current.copyWith(
      generatorRating: generatorRating ?? current.generatorRating,
      collectorRating: collectorRating ?? current.collectorRating,
    );
    MockData.requests[index] = updated;
    return updated;
  }

  double _priceFor(String wasteType, double distanceKm) {
    final type = wasteType.toLowerCase();
    final base = switch (type) {
      'plastic' => 420,
      'paper' => 260,
      'metal' => 520,
      'organic' => 180,
      _ => 220,
    };
    return base - (distanceKm * 2);
  }

  double _estimateDistanceKm(String location) {
    return location.toLowerCase().contains('lekki') ? 9.5 : 5.0;
  }

  double _estimateCo2Savings(String wasteType, double quantityKg) {
    final factor = switch (wasteType.toLowerCase()) {
      'plastic' => 1.8,
      'paper' => 1.2,
      'metal' => 2.6,
      'organic' => 0.7,
      _ => 1.0,
    };
    return quantityKg * factor;
  }

  String _suggestCollector(String wasteType, double quantityKg) {
    final type = wasteType.toLowerCase();
    if (type.contains('organic')) return 'BioCycle Team';
    if (quantityKg >= 20) return 'HeavyLift Collectors';
    if (type.contains('metal')) return 'IronLoop Riders';
    return 'Kola Rider';
  }
}
