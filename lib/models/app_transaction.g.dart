// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppTransaction _$AppTransactionFromJson(Map<String, dynamic> json) =>
    AppTransaction(
      id: json['id'] as String,
      material: json['material'] as String,
      quantityKg: (json['quantityKg'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      type:
          $enumDecodeNullable(_$TransactionTypeEnumMap, json['type']) ??
          TransactionType.credit,
      description: json['description'] as String?,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble(),
      payoutStatus: json['payoutStatus'] as String?,
      conversationId: json['conversationId'] as String?,
      payoutReceipt: json['payoutReceipt'] as String?,
    );

Map<String, dynamic> _$AppTransactionToJson(AppTransaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'material': instance.material,
      'quantityKg': instance.quantityKg,
      'amount': instance.amount,
      'createdAt': instance.createdAt.toIso8601String(),
      'type': _$TransactionTypeEnumMap[instance.type]!,
      'description': instance.description,
      'balanceAfter': instance.balanceAfter,
      'payoutStatus': instance.payoutStatus,
      'conversationId': instance.conversationId,
      'payoutReceipt': instance.payoutReceipt,
    };

const _$TransactionTypeEnumMap = {
  TransactionType.credit: 'credit',
  TransactionType.debit: 'debit',
};
