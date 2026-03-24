// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Job _$JobFromJson(Map<String, dynamic> json) => Job(
  id: json['id'] as String,
  requestId: json['requestId'] as String,
  pickupLocation: json['pickupLocation'] as String,
  wasteType: json['wasteType'] as String,
  quantityKg: (json['quantityKg'] as num).toDouble(),
  earning: (json['earning'] as num).toDouble(),
  status: $enumDecode(_$JobStatusEnumMap, json['status']),
);

Map<String, dynamic> _$JobToJson(Job instance) => <String, dynamic>{
  'id': instance.id,
  'requestId': instance.requestId,
  'pickupLocation': instance.pickupLocation,
  'wasteType': instance.wasteType,
  'quantityKg': instance.quantityKg,
  'earning': instance.earning,
  'status': _$JobStatusEnumMap[instance.status]!,
};

const _$JobStatusEnumMap = {
  JobStatus.open: 'open',
  JobStatus.accepted: 'accepted',
  JobStatus.arrived: 'arrived',
  JobStatus.picked: 'picked',
  JobStatus.delivered: 'delivered',
};
