import 'package:dio/dio.dart';
import 'package:waste_bridge/models/app_transaction.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

class TransactionService {
  TransactionService(this._dio);
  final Dio _dio;

  Future<List<AppTransaction>> getTransactions() async {
    final response = await _dio.get(ApiEndpoints.walletTransactions);
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => AppTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Phase 4 — debits wallet and queues M-Pesa B2C payout (backend marks `payoutStatus`).
  Future<Map<String, dynamic>> withdraw({
    required double amount,
    String? idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.walletWithdraw,
      data: <String, dynamic>{
        'amount': amount,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw StateError('Invalid withdraw response shape');
  }
}
