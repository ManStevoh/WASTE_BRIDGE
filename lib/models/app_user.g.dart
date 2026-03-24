// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUser _$AppUserFromJson(Map<String, dynamic> json) => AppUser(
  id: json['id'] as String,
  name: json['name'] as String,
  email: json['email'] as String,
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  kycStatus:
      $enumDecodeNullable(_$KycStatusEnumMap, json['kycStatus']) ??
      KycStatus.notSubmitted,
  isVerified: json['isVerified'] as bool? ?? false,
  subscriptionPlan: json['subscriptionPlan'] as String? ?? 'Free',
  referralCode: json['referralCode'] as String?,
);

Map<String, dynamic> _$AppUserToJson(AppUser instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'role': _$UserRoleEnumMap[instance.role]!,
  'kycStatus': _$KycStatusEnumMap[instance.kycStatus]!,
  'isVerified': instance.isVerified,
  'subscriptionPlan': instance.subscriptionPlan,
  'referralCode': instance.referralCode,
};

const _$UserRoleEnumMap = {
  UserRole.generator: 'generator',
  UserRole.collector: 'collector',
  UserRole.recycler: 'recycler',
};

const _$KycStatusEnumMap = {
  KycStatus.notSubmitted: 'notSubmitted',
  KycStatus.pending: 'pending',
  KycStatus.verified: 'verified',
  KycStatus.rejected: 'rejected',
};
