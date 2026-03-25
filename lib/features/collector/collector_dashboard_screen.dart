import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/features/collector/widgets/job_list_row.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class CollectorDashboardScreen extends ConsumerWidget {
  const CollectorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collector Dashboard'),
        actions: [
          IconButton(
            onPressed: () => context.push('/collector/wallet'),
            icon: const Icon(Icons.account_balance_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/collector/earnings'),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: jobs.when(
        data: (items) {
          final active = items
              .where((j) => j.status != JobStatus.open)
              .toList();
          final open = items.where((j) => j.status == JobStatus.open).toList();
          final todayEarnings = items
              .where((j) => j.status == JobStatus.delivered)
              .fold<double>(0, (sum, j) => sum + j.earning);
          return ListView(
            padding: EdgeInsets.all(AppSpacing.md),
            children: [
              AppSectionCard(
                title: 'Earnings Today',
                child: Text('NGN ${todayEarnings.toStringAsFixed(0)}'),
              ),
              SizedBox(height: AppSpacing.sm),
              AppSectionCard(
                title: 'Active Job',
                child: active.isEmpty
                    ? const Text('No active job currently.')
                    : ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(active.first.wasteType),
                        subtitle: Text(active.first.pickupLocation),
                        trailing: FilledButton(
                          onPressed: () => context.push(
                            '/collector/active/${active.first.id}',
                          ),
                          child: const Text('Open'),
                        ),
                      ),
              ),
              SizedBox(height: AppSpacing.sm),
              AppSectionCard(
                title: 'Available Jobs Nearby',
                child: open.isEmpty
                    ? const CenterState(
                        title: 'No open jobs',
                        subtitle: 'Check back shortly for nearby pickups.',
                      )
                    : Column(
                        children: open
                            .map(
                              (job) => JobListRow(
                                job: job,
                                onTap: () =>
                                    context.push('/collector/job/${job.id}'),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            CenterState(title: 'Error', subtitle: '$e', icon: Icons.error),
      ),
    );
  }
}
