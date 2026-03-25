import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/job.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class ActiveJobScreen extends ConsumerWidget {
  const ActiveJobScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobNotifierProvider).value ?? [];
    Job? job;
    for (final item in jobs) {
      if (item.id == jobId) {
        job = item;
        break;
      }
    }
    if (job == null) {
      return const Scaffold(
        body: CenterState(
          title: 'Job not found',
          subtitle: 'This job may no longer be active.',
          icon: Icons.search_off_rounded,
        ),
      );
    }
    final currentJob = job;
    final etaMinutes = switch (currentJob.status) {
      JobStatus.accepted => 18,
      JobStatus.arrived => 0,
      JobStatus.picked => 22,
      JobStatus.delivered => 0,
      JobStatus.open => 30,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Active Job')),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            '${currentJob.wasteType} pickup at ${currentJob.pickupLocation}',
          ),
          SizedBox(height: AppSpacing.xs),
          Text('Current status: ${currentJob.status.name.toUpperCase()}'),
          SizedBox(height: AppSpacing.sm),
          AppSectionCard(
            title: 'Live Route and ETA',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Map preview placeholder'),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Route: Collector Hub -> ${currentJob.pickupLocation} -> Recycler',
                ),
                Text(
                  'Live ETA: ${etaMinutes == 0 ? 'Reached' : '$etaMinutes mins'}',
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () => context.push('/collector/map/${currentJob.id}'),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open Full Map'),
          ),
          SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statusButton(
                context,
                ref,
                currentJob.id,
                currentStatus: currentJob.status,
                targetStatus: JobStatus.arrived,
                label: 'Arrived',
              ),
              _statusButton(
                context,
                ref,
                currentJob.id,
                currentStatus: currentJob.status,
                targetStatus: JobStatus.picked,
                label: 'Picked',
              ),
              _statusButton(
                context,
                ref,
                currentJob.id,
                currentStatus: currentJob.status,
                targetStatus: JobStatus.delivered,
                label: 'Delivered',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusButton(
    BuildContext context,
    WidgetRef ref,
    String id, {
    required JobStatus currentStatus,
    required JobStatus targetStatus,
    required String label,
  }) {
    final enabled = _canSetStatus(currentStatus, targetStatus);
    return FilledButton.tonal(
      onPressed: enabled
          ? () async {
              try {
                await ref
                    .read(jobNotifierProvider.notifier)
                    .setStatus(id, targetStatus);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Status updated to ${targetStatus.name}.'),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            }
          : null,
      child: Text(label),
    );
  }

  bool _canSetStatus(JobStatus currentStatus, JobStatus targetStatus) {
    return switch (currentStatus) {
      JobStatus.accepted => targetStatus == JobStatus.arrived,
      JobStatus.arrived => targetStatus == JobStatus.picked,
      JobStatus.picked => targetStatus == JobStatus.delivered,
      _ => false,
    };
  }
}
