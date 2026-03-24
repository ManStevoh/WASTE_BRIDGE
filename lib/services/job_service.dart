import 'dart:async';

import 'package:dio/dio.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/job.dart';
import 'package:waste_bridge/services/api_endpoints.dart';
import 'package:waste_bridge/services/mock_data.dart';

class JobService {
  JobService(this._dio);
  final Dio _dio;

  Future<List<Job>> getJobs() async {
    await _dio.get(ApiEndpoints.jobs);
    return List<Job>.from(MockData.jobs);
  }

  Future<Job> acceptJob(String jobId) async {
    await _dio.post(ApiEndpoints.acceptJob, data: {'jobId': jobId});
    final index = MockData.jobs.indexWhere((j) => j.id == jobId);
    if (index < 0) throw Exception('Job not found');
    final updated = MockData.jobs[index].copyWith(status: JobStatus.accepted);
    MockData.jobs[index] = updated;
    return updated;
  }

  Future<Job> updateStatus({
    required String jobId,
    required JobStatus status,
  }) async {
    await _dio.post(ApiEndpoints.updateStatus, data: {'jobId': jobId, 'status': status.name});
    final index = MockData.jobs.indexWhere((j) => j.id == jobId);
    if (index < 0) throw Exception('Job not found');
    final updated = MockData.jobs[index].copyWith(status: status);
    MockData.jobs[index] = updated;
    return updated;
  }
}
