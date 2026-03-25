import 'package:dio/dio.dart';
import 'package:waste_bridge/models/waste_request.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

class WasteRequestService {
  WasteRequestService(this._dio);
  final Dio _dio;

  Future<List<WasteRequest>> getRequests() async {
    final response = await _dio.get(ApiEndpoints.requests);
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => WasteRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WasteRequest> requestPickup({
    required String wasteType,
    required double quantityKg,
    required String location,
    DateTime? scheduledAt,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.requests,
      data: {
        'wasteType': wasteType,
        'quantityKg': quantityKg,
        'location': location,
        if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
      },
    );
    return WasteRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> reportDispute({
    required String requestId,
    required String reason,
  }) async {
    await _dio.post(
      ApiEndpoints.requestDispute(requestId),
      data: {'reason': reason},
    );
  }

  Future<void> resolveDispute({
    required String requestId,
  }) async {
    await _dio.post(ApiEndpoints.requestDisputeResolve(requestId));
  }

  /// Uploads proof images via multipart (`before_photo` / `after_photo`) or falls back to URL strings.
  Future<WasteRequest> uploadPhotoProof({
    required String requestId,
    String? beforeFilePath,
    String? afterFilePath,
    String? beforePickupPhotoUrl,
    String? afterPickupPhotoUrl,
  }) async {
    if (beforeFilePath != null || afterFilePath != null) {
      final map = <String, dynamic>{};
      if (beforeFilePath != null) {
        map['before_photo'] = await MultipartFile.fromFile(
          beforeFilePath,
          filename: beforeFilePath.split(RegExp(r'[/\\]')).last,
        );
      }
      if (afterFilePath != null) {
        map['after_photo'] = await MultipartFile.fromFile(
          afterFilePath,
          filename: afterFilePath.split(RegExp(r'[/\\]')).last,
        );
      }
      final response = await _dio.post(
        ApiEndpoints.requestProof(requestId),
        data: FormData.fromMap(map),
      );
      return WasteRequest.fromJson(response.data as Map<String, dynamic>);
    }

    final response = await _dio.post(
      ApiEndpoints.requestProof(requestId),
      data: {
        if (beforePickupPhotoUrl != null)
          'beforePickupPhotoUrl': beforePickupPhotoUrl,
        if (afterPickupPhotoUrl != null)
          'afterPickupPhotoUrl': afterPickupPhotoUrl,
      },
    );
    return WasteRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WasteRequest> submitRatings({
    required String requestId,
    double? generatorRating,
    double? collectorRating,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.requestRatings(requestId),
      data: {
        if (generatorRating != null) 'generatorRating': generatorRating,
        if (collectorRating != null) 'collectorRating': collectorRating,
      },
    );
    return WasteRequest.fromJson(response.data as Map<String, dynamic>);
  }
}
