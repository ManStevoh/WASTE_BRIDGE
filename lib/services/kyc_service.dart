import 'package:dio/dio.dart';
import 'package:waste_bridge/models/kyc_submission.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

class KycService {
  KycService(this._dio);

  final Dio _dio;

  Future<List<KycSubmission>> listSubmissions() async {
    final response = await _dio.get(ApiEndpoints.kycSubmissions);
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => KycSubmission.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<KycSubmission> submit({
    required String documentType,
    required String filePath,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'documentType': documentType,
      'document': await MultipartFile.fromFile(filePath, filename: filename),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.kycSubmissions,
      data: formData,
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return KycSubmission.fromJson(data);
    }
    throw StateError('Invalid KYC submit response');
  }

  Future<KycSubmission> getSubmission(String publicId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.kycSubmission(publicId),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return KycSubmission.fromJson(data);
    }
    throw StateError('Invalid KYC detail response');
  }
}
