import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/features/shared/info_row.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class ImpactDashboardScreen extends ConsumerWidget {
  const ImpactDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(requestNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Impact Dashboard')),
      body: requests.when(
        data: (items) {
          final completed = items
              .where((e) => e.status == RequestStatus.completed)
              .length;
          final totalKg = items.fold<double>(0, (sum, e) => sum + e.quantityKg);
          final co2 = items.fold<double>(0, (sum, e) => sum + e.co2SavedKg);
          final paid = items
              .where((e) => e.paymentStatus == PaymentStatus.paid)
              .length;
          return ListView(
            padding: EdgeInsets.all(AppSpacing.md),
            children: [
              AppSectionCard(
                title: 'Environmental Impact',
                child: Column(
                  children: [
                    InfoRow(
                      label: 'Waste diverted',
                      value: '${totalKg.toStringAsFixed(1)} kg',
                    ),
                    InfoRow(
                      label: 'Estimated CO2 saved',
                      value: '${co2.toStringAsFixed(1)} kg',
                    ),
                    InfoRow(label: 'Completed pickups', value: '$completed'),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              AppSectionCard(
                title: 'Business Metrics',
                child: Column(
                  children: [
                    InfoRow(label: 'Total requests', value: '${items.length}'),
                    InfoRow(label: 'Paid requests', value: '$paid'),
                    InfoRow(
                      label: 'Revenue estimate',
                      value:
                          'NGN ${items.fold<double>(0, (sum, e) => sum + (e.totalAmount ?? 0)).toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              const AppSectionCard(
                title: 'Exportable Reports',
                child: Text(
                  'CSV/PDF report export can be connected to backend reporting endpoints.',
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
