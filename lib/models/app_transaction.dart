import 'package:json_annotation/json_annotation.dart';
import 'package:waste_bridge/models/app_enums.dart';

part 'app_transaction.g.dart';

@JsonSerializable()
class AppTransaction {
  const AppTransaction({
    required this.id,
    required this.material,
    required this.quantityKg,
    required this.amount,
    required this.createdAt,
    this.type = TransactionType.credit,
    this.description,
    this.balanceAfter,
    this.payoutStatus,
    this.conversationId,
    this.payoutReceipt,
  });

  final String id;
  final String material;
  final double quantityKg;
  final double amount;
  final DateTime createdAt;
  final TransactionType type;
  final String? description;
  final double? balanceAfter;

  /// B2C withdrawal lifecycle (`submitted`, `completed`, `failed`, `timeout`), when applicable.
  final String? payoutStatus;

  /// Daraja ConversationID for M-Pesa B2C, when applicable.
  final String? conversationId;

  /// M-Pesa receipt from B2C result callback, when applicable.
  final String? payoutReceipt;

  factory AppTransaction.fromJson(Map<String, dynamic> json) =>
      _$AppTransactionFromJson(json);

  Map<String, dynamic> toJson() => _$AppTransactionToJson(this);
}
