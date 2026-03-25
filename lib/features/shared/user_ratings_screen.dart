import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/providers/app_providers.dart';

/// Full-screen list of public ratings for a user (`GET /users/{id}/ratings`).
class UserRatingsScreen extends ConsumerWidget {
  const UserRatingsScreen({super.key, required this.userPublicId});

  final String userPublicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collectorRatingsProvider(userPublicId));

    return Scaffold(
      appBar: AppBar(title: const Text('Public ratings')),
      body: async.when(
        data: (items) {
          if (items.isEmpty) {
            return const CenterState(
              title: 'No ratings yet',
              subtitle: 'This user has no published reviews.',
              icon: Icons.star_border,
            );
          }
          final avg =
              items.fold<double>(0, (s, r) => s + r.score) / items.length;
          return ListView(
            padding: EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                'Average ${avg.toStringAsFixed(1)} / 5 · ${items.length} review(s)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: AppSpacing.md),
              ...items.map(
                (r) => Card(
                  margin: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.score.toStringAsFixed(1)} ★'
                          '${r.raterName != null ? ' · ${r.raterName}' : ''}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (r.comment != null && r.comment!.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(r.comment!),
                          ),
                        if (r.pickupRequestId != null)
                          Text(
                            'Request: ${r.pickupRequestId}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (r.createdAt != null)
                          Text(
                            r.createdAt!.toLocal().toString().split('.').first,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CenterState(
          title: 'Error',
          subtitle: '$e',
          icon: Icons.error_outline,
        ),
      ),
    );
  }
}
