import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/core/ui/user_safe_error.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class RecyclerDashboardScreen extends ConsumerWidget {
  const RecyclerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(marketplaceFeedProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycler Dashboard'),
        actions: [
          IconButton(
            onPressed: () => context.push('/recycler/transactions'),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: feed.when(
        data: (page) {
          final items = page.items;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(marketplaceFeedProvider);
              await ref.read(marketplaceFeedProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(AppSpacing.md),
              children: [
                FilledButton.icon(
                  onPressed: () => context.push('/recycler/transactions'),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('My purchases'),
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Browse fixed-price listings from generators. Pull down to refresh.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                AppSectionCard(
                  title: 'Marketplace',
                  child: items.isEmpty
                      ? const CenterState(
                          title: 'No listings yet',
                          subtitle:
                              'When generators post listings, they will appear here.',
                        )
                      : Column(
                          children: items
                              .map(
                                (l) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    l.wasteType,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  subtitle: Text(
                                    '${l.quantityKg} kg · ${l.locationText}'
                                    '${l.totalPrice != null ? ' · KES ${l.totalPrice!.toStringAsFixed(0)}' : ''}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  isThreeLine: true,
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    size: 22,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  onTap: () =>
                                      context.push('/recycler/listing', extra: l),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CenterState(
          title: 'Could not load marketplace',
          subtitle: userVisibleError(e),
          icon: Icons.error_outline,
        ),
      ),
    );
  }
}
