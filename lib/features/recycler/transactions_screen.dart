import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/core/ui/user_safe_error.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    if (user?.role == UserRole.recycler) {
      final orders = ref.watch(buyerOrdersProvider);
      return Scaffold(
        appBar: AppBar(title: const Text('My purchases')),
        body: orders.when(
          data: (page) {
            if (page.items.isEmpty) {
              return const CenterState(
                title: 'No purchases yet',
                subtitle: 'Buy from the marketplace feed, then pay with M-Pesa.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(buyerOrdersProvider);
                await ref.read(buyerOrdersProvider.future);
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(AppSpacing.md),
                itemBuilder: (_, i) {
                  final o = page.items[i];
                  return Card(
                    child: ListTile(
                      title: Text(o.id),
                      subtitle: Text(
                        '${o.status} · ${o.subtotalAmount != null ? '${o.currency ?? 'KES'} ${o.subtotalAmount!.toStringAsFixed(0)}' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/recycler/order/${o.id}'),
                    ),
                  );
                },
                separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
                itemCount: page.items.length,
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => CenterState(
            title: 'Could not load purchases',
            subtitle: userVisibleError(e),
            icon: Icons.error_outline,
          ),
        ),
      );
    }

    final transactions = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: transactions.when(
        data: (items) {
          if (items.isEmpty) {
            return const CenterState(
              title: 'No transactions',
              subtitle: 'Your wallet history will appear here.',
            );
          }
          return ListView.separated(
            padding: EdgeInsets.all(AppSpacing.md),
            itemBuilder: (_, i) {
              final t = items[i];
              return Card(
                child: ListTile(
                  title: Text('${t.material} (${t.quantityKg}kg)'),
                  subtitle: Text(t.createdAt.toLocal().toString().split(' ').first),
                  trailing: Text('KES ${t.amount.toStringAsFixed(0)}'),
                ),
              );
            },
            separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
            itemCount: items.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CenterState(
          title: 'Could not load transactions',
          subtitle: userVisibleError(e),
          icon: Icons.error_outline,
        ),
      ),
    );
  }
}
