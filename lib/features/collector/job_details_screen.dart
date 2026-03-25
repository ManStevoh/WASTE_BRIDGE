import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/job.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class JobDetailsScreen extends ConsumerWidget {
  const JobDetailsScreen({super.key, required this.jobId});

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
          subtitle: 'This job may already be closed.',
          icon: Icons.search_off_rounded,
        ),
      );
    }
    final currentJob = job;
    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Waste Type: ${currentJob.wasteType}'),
            Text('Quantity: ${currentJob.quantityKg} kg'),
            Text('Pickup: ${currentJob.pickupLocation}'),
            Text('Earning: NGN ${currentJob.earning.toStringAsFixed(0)}'),
            SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: currentJob.status != JobStatus.open
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(jobNotifierProvider.notifier)
                            .accept(currentJob.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Job accepted successfully.'),
                          ),
                        );
                        context.go('/collector');
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
              child: const Text('Accept Job'),
            ),
          ],
        ),
      ),
    );
  }
}
