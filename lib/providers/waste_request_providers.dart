import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/models/waste_request.dart';
import 'package:waste_bridge/providers/notification_providers.dart';
import 'package:waste_bridge/providers/service_providers.dart';
import 'package:waste_bridge/services/waste_request_service.dart';

class RequestNotifier extends StateNotifier<AsyncValue<List<WasteRequest>>> {
  RequestNotifier(this._ref, this._service) : super(const AsyncValue.loading()) {
    fetch();
  }

  final Ref _ref;
  final WasteRequestService _service;

  Future<void> fetch() async {
    state = await AsyncValue.guard(_service.getRequests);
  }

  Future<void> addRequest({
    required String wasteType,
    required double quantityKg,
    required String location,
    DateTime? scheduledAt,
  }) async {
    await _service.requestPickup(
      wasteType: wasteType,
      quantityKg: quantityKg,
      location: location,
      scheduledAt: scheduledAt,
    );
    await _ref.read(notificationsProvider.notifier).fetch();
    await fetch();
  }

  Future<void> uploadProof({
    required String requestId,
    required bool isBeforePickup,
    required String filePath,
  }) async {
    await _service.uploadPhotoProof(
      requestId: requestId,
      beforeFilePath: isBeforePickup ? filePath : null,
      afterFilePath: isBeforePickup ? null : filePath,
    );
    await _ref.read(notificationsProvider.notifier).fetch();
    await fetch();
  }

  Future<void> submitRatings({
    required String requestId,
    double? generatorRating,
    double? collectorRating,
  }) async {
    await _service.submitRatings(
      requestId: requestId,
      generatorRating: generatorRating,
      collectorRating: collectorRating,
    );
    await _ref.read(notificationsProvider.notifier).fetch();
    await fetch();
  }

  Future<void> reportDispute({
    required String requestId,
    required String reason,
  }) async {
    await _service.reportDispute(requestId: requestId, reason: reason);
    await fetch();
  }

  Future<void> resolveDispute({required String requestId}) async {
    await _service.resolveDispute(requestId: requestId);
    await fetch();
  }
}

final requestNotifierProvider =
    StateNotifierProvider<RequestNotifier, AsyncValue<List<WasteRequest>>>((ref) {
      return RequestNotifier(
        ref,
        ref.read(wasteRequestServiceProvider),
      );
    });
