import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/core/ui/user_safe_error.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class GeneratorHomeScreen extends ConsumerWidget {
  const GeneratorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generator Home'),
        actions: [
          IconButton(
            onPressed: () => context.push('/generator/impact'),
            icon: const Icon(Icons.insights_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/generator/requests'),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.md),
        children: [
          FilledButton.icon(
            onPressed: () => context.push('/generator/request-pickup'),
            icon: const Icon(Icons.add_business),
            label: const Text('Request Pickup'),
          ),
          SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => context.push('/generator/create-listing'),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Post listing to marketplace'),
          ),
          SizedBox(height: AppSpacing.md),
          const AppSectionCard(
            title: 'Waste Categories',
            child: Wrap(
              spacing: AppSpacing.xs,
              children: [
                Chip(label: Text('Plastic')),
                Chip(label: Text('Paper')),
                Chip(label: Text('Metal')),
                Chip(label: Text('Organic')),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),
          AppSectionCard(
            title: 'Recent Requests',
            trailing: TextButton(
              onPressed: () => context.push('/generator/requests'),
              child: const Text('View all'),
            ),
            child: requests.when(
              data: (items) {
                if (items.isEmpty) {
                  return const CenterState(
                    title: 'No requests yet',
                    subtitle: 'Create your first pickup request.',
                  );
                }
                return Column(
                  children: items
                      .take(3)
                      .map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () =>
                              context.push('/generator/track/${item.id}'),
                          title: Text(
                            '${item.wasteType} - ${item.quantityKg}kg',
                          ),
                          subtitle: Text(item.location),
                          trailing: Text(item.status.name),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: const CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => CenterState(
                title: 'Could not load requests',
                subtitle: userVisibleError(e),
                icon: Icons.error_outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
