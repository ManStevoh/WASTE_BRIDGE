import 'package:json_annotation/json_annotation.dart';
import 'package:waste_bridge/models/app_enums.dart';

part 'waste_request.g.dart';

@JsonSerializable()
class WasteRequest {
  const WasteRequest({
    required this.id,
    required this.wasteType,
    required this.quantityKg,
    required this.location,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.completedAt,
    this.cancelledAt,
    this.suggestedCollectorName,
    this.estimatedEtaMinutes,
    this.beforePickupPhotoUrl,
    this.afterPickupPhotoUrl,
    this.generatorRating,
    this.collectorRating,
    this.scheduledAt,
    this.rescheduledAt,
    this.distanceKm,
    this.unitPricePerKg,
    this.totalAmount,
    this.paymentStatus = PaymentStatus.unpaid,
    this.isDisputed = false,
    this.disputeReason,
    this.receiptId,
    this.receiptIssuedAt,
    this.co2SavedKg = 0,
    this.collectorPublicId,
  });

  final String id;
  final String wasteType;
  final double quantityKg;
  final String location;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? suggestedCollectorName;
  final int? estimatedEtaMinutes;
  final String? beforePickupPhotoUrl;
  final String? afterPickupPhotoUrl;
  final double? generatorRating;
  final double? collectorRating;
  final DateTime? scheduledAt;
  final DateTime? rescheduledAt;
  final double? distanceKm;
  final double? unitPricePerKg;
  final double? totalAmount;
  final PaymentStatus paymentStatus;
  final bool isDisputed;
  final String? disputeReason;
  final String? receiptId;
  final DateTime? receiptIssuedAt;
  final double co2SavedKg;
  /// Assigned collector [User.public_id], when set.
  final String? collectorPublicId;

  factory WasteRequest.fromJson(Map<String, dynamic> json) =>
      _$WasteRequestFromJson(json);

  Map<String, dynamic> toJson() => _$WasteRequestToJson(this);

  WasteRequest copyWith({
    RequestStatus? status,
    DateTime? acceptedAt,
    DateTime? pickedUpAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? suggestedCollectorName,
    int? estimatedEtaMinutes,
    String? beforePickupPhotoUrl,
    String? afterPickupPhotoUrl,
    double? generatorRating,
    double? collectorRating,
    DateTime? scheduledAt,
    DateTime? rescheduledAt,
    double? distanceKm,
    double? unitPricePerKg,
    double? totalAmount,
    PaymentStatus? paymentStatus,
    bool? isDisputed,
    String? disputeReason,
    String? receiptId,
    DateTime? receiptIssuedAt,
    double? co2SavedKg,
    String? collectorPublicId,
  }) {
    return WasteRequest(
      id: id,
      wasteType: wasteType,
      quantityKg: quantityKg,
      location: location,
      status: status ?? this.status,
      createdAt: createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      suggestedCollectorName:
          suggestedCollectorName ?? this.suggestedCollectorName,
      estimatedEtaMinutes: estimatedEtaMinutes ?? this.estimatedEtaMinutes,
      beforePickupPhotoUrl: beforePickupPhotoUrl ?? this.beforePickupPhotoUrl,
      afterPickupPhotoUrl: afterPickupPhotoUrl ?? this.afterPickupPhotoUrl,
      generatorRating: generatorRating ?? this.generatorRating,
      collectorRating: collectorRating ?? this.collectorRating,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      rescheduledAt: rescheduledAt ?? this.rescheduledAt,
      distanceKm: distanceKm ?? this.distanceKm,
      unitPricePerKg: unitPricePerKg ?? this.unitPricePerKg,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      isDisputed: isDisputed ?? this.isDisputed,
      disputeReason: disputeReason ?? this.disputeReason,
      receiptId: receiptId ?? this.receiptId,
      receiptIssuedAt: receiptIssuedAt ?? this.receiptIssuedAt,
      co2SavedKg: co2SavedKg ?? this.co2SavedKg,
      collectorPublicId: collectorPublicId ?? this.collectorPublicId,
    );
  }

  DateTime get statusUpdatedAt {
    switch (status) {
      case RequestStatus.pending:
        return createdAt;
      case RequestStatus.accepted:
        return acceptedAt ?? createdAt;
      case RequestStatus.pickedUp:
        return pickedUpAt ?? acceptedAt ?? createdAt;
      case RequestStatus.completed:
        return completedAt ?? pickedUpAt ?? acceptedAt ?? createdAt;
      case RequestStatus.cancelled:
        return cancelledAt ?? acceptedAt ?? createdAt;
    }
  }
}
