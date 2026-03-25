// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'waste_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WasteRequest _$WasteRequestFromJson(Map<String, dynamic> json) => WasteRequest(
  id: json['id'] as String,
  wasteType: json['wasteType'] as String,
  quantityKg: (json['quantityKg'] as num).toDouble(),
  location: json['location'] as String,
  status: $enumDecode(_$RequestStatusEnumMap, json['status']),
  createdAt: DateTime.parse(json['createdAt'] as String),
  acceptedAt: json['acceptedAt'] == null
      ? null
      : DateTime.parse(json['acceptedAt'] as String),
  pickedUpAt: json['pickedUpAt'] == null
      ? null
      : DateTime.parse(json['pickedUpAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  cancelledAt: json['cancelledAt'] == null
      ? null
      : DateTime.parse(json['cancelledAt'] as String),
  suggestedCollectorName: json['suggestedCollectorName'] as String?,
  estimatedEtaMinutes: (json['estimatedEtaMinutes'] as num?)?.toInt(),
  beforePickupPhotoUrl: json['beforePickupPhotoUrl'] as String?,
  afterPickupPhotoUrl: json['afterPickupPhotoUrl'] as String?,
  generatorRating: (json['generatorRating'] as num?)?.toDouble(),
  collectorRating: (json['collectorRating'] as num?)?.toDouble(),
  scheduledAt: json['scheduledAt'] == null
      ? null
      : DateTime.parse(json['scheduledAt'] as String),
  rescheduledAt: json['rescheduledAt'] == null
      ? null
      : DateTime.parse(json['rescheduledAt'] as String),
  distanceKm: (json['distanceKm'] as num?)?.toDouble(),
  unitPricePerKg: (json['unitPricePerKg'] as num?)?.toDouble(),
  totalAmount: (json['totalAmount'] as num?)?.toDouble(),
  paymentStatus:
      $enumDecodeNullable(_$PaymentStatusEnumMap, json['paymentStatus']) ??
      PaymentStatus.unpaid,
  isDisputed: json['isDisputed'] as bool? ?? false,
  disputeReason: json['disputeReason'] as String?,
  receiptId: json['receiptId'] as String?,
  receiptIssuedAt: json['receiptIssuedAt'] == null
      ? null
      : DateTime.parse(json['receiptIssuedAt'] as String),
  co2SavedKg: (json['co2SavedKg'] as num?)?.toDouble() ?? 0,
  collectorPublicId: json['collectorPublicId'] as String?,
);

Map<String, dynamic> _$WasteRequestToJson(WasteRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'wasteType': instance.wasteType,
      'quantityKg': instance.quantityKg,
      'location': instance.location,
      'status': _$RequestStatusEnumMap[instance.status]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'acceptedAt': instance.acceptedAt?.toIso8601String(),
      'pickedUpAt': instance.pickedUpAt?.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'cancelledAt': instance.cancelledAt?.toIso8601String(),
      'suggestedCollectorName': instance.suggestedCollectorName,
      'estimatedEtaMinutes': instance.estimatedEtaMinutes,
      'beforePickupPhotoUrl': instance.beforePickupPhotoUrl,
      'afterPickupPhotoUrl': instance.afterPickupPhotoUrl,
      'generatorRating': instance.generatorRating,
      'collectorRating': instance.collectorRating,
      'scheduledAt': instance.scheduledAt?.toIso8601String(),
      'rescheduledAt': instance.rescheduledAt?.toIso8601String(),
      'distanceKm': instance.distanceKm,
      'unitPricePerKg': instance.unitPricePerKg,
      'totalAmount': instance.totalAmount,
      'paymentStatus': _$PaymentStatusEnumMap[instance.paymentStatus]!,
      'isDisputed': instance.isDisputed,
      'disputeReason': instance.disputeReason,
      'receiptId': instance.receiptId,
      'receiptIssuedAt': instance.receiptIssuedAt?.toIso8601String(),
      'co2SavedKg': instance.co2SavedKg,
      'collectorPublicId': instance.collectorPublicId,
    };

const _$RequestStatusEnumMap = {
  RequestStatus.pending: 'pending',
  RequestStatus.accepted: 'accepted',
  RequestStatus.pickedUp: 'pickedUp',
  RequestStatus.completed: 'completed',
  RequestStatus.cancelled: 'cancelled',
};

const _$PaymentStatusEnumMap = {
  PaymentStatus.unpaid: 'unpaid',
  PaymentStatus.pending: 'pending',
  PaymentStatus.paid: 'paid',
};
