import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class RecyclerDashboardScreen extends ConsumerWidget {
  const RecyclerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestNotifierProvider);
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
      body: requests.when(
        data: (items) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppSectionCard(
                title: 'Incoming Waste Deliveries',
                child: items.isEmpty
                    ? const CenterState(title: 'No incoming deliveries', subtitle: 'Pending deliveries will show here.')
                    : Column(
                        children: items
                            .map(
                              (r) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(r.wasteType),
                                subtitle: Text('${r.quantityKg}kg - ${r.location}'),
                                trailing: TextButton(
                                  onPressed: () => context.push('/recycler/delivery/${r.id}'),
                                  child: const Text('Details'),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 12),
              const AppSectionCard(
                title: 'Available Materials',
                child: Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text('HDPE Plastic')),
                    Chip(label: Text('Aluminium')),
                    Chip(label: Text('Cardboard')),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CenterState(title: 'Error', subtitle: '$e', icon: Icons.error),
      ),
    );
  }
}

class DeliveryDetailsScreen extends StatelessWidget {
  const DeliveryDetailsScreen({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery ID: $deliveryId'),
            const SizedBox(height: 8),
            const Text('Waste Type: Plastic'),
            const Text('Quantity: 18 kg'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Receipt confirmed'))),
              child: const Text('Confirm Receipt'),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: transactions.when(
        data: (items) {
          if (items.isEmpty) {
            return const CenterState(title: 'No transactions', subtitle: 'Your purchase history will appear here.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, i) {
              final t = items[i];
              return Card(
                child: ListTile(
                  title: Text('${t.material} (${t.quantityKg}kg)'),
                  subtitle: Text(t.createdAt.toLocal().toString().split(' ').first),
                  trailing: Text('NGN ${t.amount.toStringAsFixed(0)}'),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: items.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CenterState(title: 'Error', subtitle: '$e', icon: Icons.error),
      ),
    );
  }
}
