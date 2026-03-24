import 'package:json_annotation/json_annotation.dart';
import 'package:waste_bridge/models/app_enums.dart';

part 'job.g.dart';

@JsonSerializable()
class Job {
  const Job({
    required this.id,
    required this.requestId,
    required this.pickupLocation,
    required this.wasteType,
    required this.quantityKg,
    required this.earning,
    required this.status,
  });

  final String id;
  final String requestId;
  final String pickupLocation;
  final String wasteType;
  final double quantityKg;
  final double earning;
  final JobStatus status;

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);

  Map<String, dynamic> toJson() => _$JobToJson(this);

  Job copyWith({JobStatus? status}) {
    return Job(
      id: id,
      requestId: requestId,
      pickupLocation: pickupLocation,
      wasteType: wasteType,
      quantityKg: quantityKg,
      earning: earning,
      status: status ?? this.status,
    );
  }
}
