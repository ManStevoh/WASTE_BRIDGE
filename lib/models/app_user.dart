import 'package:json_annotation/json_annotation.dart';
import 'package:waste_bridge/models/app_enums.dart';

part 'app_user.g.dart';

@JsonSerializable()
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.kycStatus = KycStatus.notSubmitted,
    this.isVerified = false,
    this.subscriptionPlan = 'Free',
    this.referralCode,
    this.collectorAvailable,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final KycStatus kycStatus;
  final bool isVerified;
  final String subscriptionPlan;
  final String? referralCode;
  /// When [role] is [UserRole.collector], server-driven availability for matching.
  final bool? collectorAvailable;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);

  Map<String, dynamic> toJson() => _$AppUserToJson(this);
}
