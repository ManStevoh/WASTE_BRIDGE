import 'package:dio/dio.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

/// Phase 4 — M-Pesa payment intents (STK when backend has MPESA_ENABLED=true).
class PaymentService {
  PaymentService(this._dio);
  final Dio _dio;

  /// Returns API envelope `data` map for a new or idempotent payment intent.
  Future<Map<String, dynamic>> initiatePayment({
    required double amount,
    String? currency,
    String? orderPublicId,
    String? phone,
    String? idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.paymentInitiate,
      data: <String, dynamic>{
        'amount': amount,
        if (currency != null) 'currency': currency,
        if (orderPublicId != null) 'orderPublicId': orderPublicId,
        if (phone != null) 'phone': phone,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw StateError('Invalid payment response shape');
  }
}
