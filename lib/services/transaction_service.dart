import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waste_bridge/models/app_transaction.dart';
import 'package:waste_bridge/models/wallet_snapshot.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

class TransactionService {
  TransactionService(this._dio);
  final Dio _dio;

  /// `GET /wallet` — authoritative balance (same as `/user/wallet`).
  Future<WalletSnapshot> getWallet() async {
    final response = await _dio.get(ApiEndpoints.wallet);
    final data = response.data as Map<String, dynamic>;
    return WalletSnapshot.fromJson(data);
  }

  /// Phase 4 — CSV export of the current user's ledger (`GET /wallet/ledger/export`).
  Future<List<int>> downloadLedgerExport({String? from, String? to}) async {
    final response = await _dio.get<List<int>>(
      ApiEndpoints.walletLedgerExport,
      queryParameters: <String, dynamic>{
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? <int>[];
  }

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

  /// CSV export (`GET /wallet/ledger/export`). Opens the file when complete.
  Future<void> exportLedgerOpen({
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _dio.get<List<int>>(
      ApiEndpoints.walletLedgerExport,
      queryParameters: {
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
      },
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'text/csv,*/*'},
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Empty export response');
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/wallet-export-${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFile.open(path);
    if (result.type != ResultType.done) {
      throw StateError('Could not open CSV: ${result.message}');
    }
  }

  String _dateOnly(DateTime d) {
    final x = d.toUtc();
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }
}
