import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

class ReceiptService {
  ReceiptService(this._dio);
  final Dio _dio;

  /// GET `/receipts/{receiptId}` — JSON payload (unwrapped by [ApiClient]).
  Future<Map<String, dynamic>> getReceipt(String receiptId) async {
    final response = await _dio.get<dynamic>(ApiEndpoints.receipt(receiptId));
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw StateError('Invalid receipt response');
  }

  /// GET `/receipts/{receiptId}/pdf` — saves to temp dir and opens with the OS.
  Future<void> downloadAndOpenPdf(String receiptId) async {
    final response = await _dio.get<List<int>>(
      ApiEndpoints.receiptPdf(receiptId),
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/pdf'},
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Empty PDF response');
    }
    final dir = await getTemporaryDirectory();
    final safe = receiptId.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final path = '${dir.path}/receipt-$safe.pdf';
    await File(path).writeAsBytes(bytes, flush: true);
    final result = await OpenFile.open(path);
    if (result.type != ResultType.done) {
      throw StateError('Could not open PDF: ${result.message}');
    }
  }
}
