import 'package:dio/dio.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/job.dart';
import 'package:waste_bridge/services/api_endpoints.dart';

class JobService {
  JobService(this._dio);
  final Dio _dio;

  Future<List<Job>> getJobs() async {
    final response = await _dio.get(ApiEndpoints.jobs);
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => Job.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Job> acceptJob(String jobId) async {
    final response = await _dio.post(ApiEndpoints.jobAccept(jobId));
    return Job.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Job> updateStatus({
    required String jobId,
    required JobStatus status,
  }) async {
    final response = await _dio.patch(
      ApiEndpoints.jobUpdate(jobId),
      data: {'status': status.name},
    );
    return Job.fromJson(response.data as Map<String, dynamic>);
  }

  /// Phase 5 — nearest-neighbor route for active jobs (`accepted` | `arrived` | `picked`).
  /// Pass both [latitude] and [longitude] (collector position) or omit both.
  Future<Map<String, dynamic>> getRoutePlan({
    double? latitude,
    double? longitude,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.jobsRoutePlan,
      queryParameters: {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
    return response.data ?? {};
  }
}
