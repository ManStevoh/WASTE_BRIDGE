import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/job.dart';
import 'package:waste_bridge/providers/notification_providers.dart';
import 'package:waste_bridge/providers/service_providers.dart';
import 'package:waste_bridge/providers/waste_request_providers.dart';
import 'package:waste_bridge/services/job_service.dart';

class JobNotifier extends StateNotifier<AsyncValue<List<Job>>> {
  JobNotifier(
    this._ref,
    this._service,
  ) : super(const AsyncValue.loading()) {
    fetch();
  }

  final Ref _ref;
  final JobService _service;

  Future<void> fetch() async {
    state = await AsyncValue.guard(_service.getJobs);
  }

  Future<void> accept(String id) async {
    final jobs = state.valueOrNull ?? await _service.getJobs();
    final currentJob = jobs.firstWhere(
      (job) => job.id == id,
      orElse: () => throw StateError('Job not found'),
    );
    if (currentJob.status != JobStatus.open) {
      throw StateError('Only open jobs can be accepted.');
    }
    await _service.acceptJob(id);
    await _ref.read(notificationsProvider.notifier).fetch();
    await fetch();
    await _ref.read(requestNotifierProvider.notifier).fetch();
  }

  Future<void> setStatus(String id, JobStatus status) async {
    final jobs = state.valueOrNull ?? await _service.getJobs();
    final currentJob = jobs.firstWhere(
      (job) => job.id == id,
      orElse: () => throw StateError('Job not found'),
    );
    if (!_canTransition(currentJob.status, status)) {
      throw StateError(
        'Invalid transition from ${currentJob.status.name} to ${status.name}.',
      );
    }
    await _service.updateStatus(jobId: id, status: status);
    await _ref.read(notificationsProvider.notifier).fetch();
    await fetch();
    await _ref.read(requestNotifierProvider.notifier).fetch();
  }

  bool _canTransition(JobStatus from, JobStatus to) {
    if (from == to) return false;
    return switch (from) {
      JobStatus.open => to == JobStatus.accepted,
      JobStatus.accepted => to == JobStatus.arrived,
      JobStatus.arrived => to == JobStatus.picked,
      JobStatus.picked => to == JobStatus.delivered,
      JobStatus.delivered => false,
    };
  }
}

final jobNotifierProvider =
    StateNotifierProvider<JobNotifier, AsyncValue<List<Job>>>((ref) {
      return JobNotifier(
        ref,
        ref.read(jobServiceProvider),
      );
    });
