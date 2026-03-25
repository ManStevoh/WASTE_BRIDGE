import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: jobs.when(
        data: (items) {
          final done = items
              .where((j) => j.status == JobStatus.delivered)
              .toList();
          final total = done.fold<double>(0, (sum, j) => sum + j.earning);
          if (done.isEmpty) {
            return const CenterState(
              title: 'No completed jobs',
              subtitle: 'Deliver jobs to see earnings history.',
            );
          }
          return ListView(
            padding: EdgeInsets.all(AppSpacing.md),
            children: [
              Text('Total Earnings: NGN ${total.toStringAsFixed(0)}'),
              SizedBox(height: AppSpacing.sm),
              ...done.map(
                (j) => Card(
                  child: ListTile(
                    title: Text(j.wasteType),
                    trailing: Text('NGN ${j.earning}'),
                  ),
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
