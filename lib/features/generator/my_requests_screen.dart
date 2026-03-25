import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      body: requests.when(
        data: (items) {
          if (items.isEmpty) {
            return const CenterState(
              title: 'No pickup requests',
              subtitle: 'You can request a pickup from the home screen.',
            );
          }
          return ListView.separated(
            padding: EdgeInsets.all(AppSpacing.md),
            itemBuilder: (_, i) {
              final item = items[i];
              return Card(
                child: ListTile(
                  onTap: () => context.push('/generator/track/${item.id}'),
                  title: Text('${item.wasteType} - ${item.quantityKg}kg'),
                  subtitle: Text(item.location),
                  trailing: Chip(label: Text(item.status.name.toUpperCase())),
                ),
              );
            },
            separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
            itemCount: items.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            CenterState(title: 'Error', subtitle: '$e', icon: Icons.error),
      ),
    );
  }
}
