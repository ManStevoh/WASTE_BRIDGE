import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class WalletLedgerScreen extends ConsumerWidget {
  const WalletLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet Ledger')),
      body: txAsync.when(
        data: (items) {
          final balance = items.fold<double>(
            0,
            (sum, t) => t.type == TransactionType.credit
                ? sum + t.amount
                : sum - t.amount,
          );
          return ListView(
            padding: EdgeInsets.all(AppSpacing.md),
            children: [
              AppSectionCard(
                title: 'Available Balance',
                child: Text('NGN ${balance.toStringAsFixed(0)}'),
              ),
              SizedBox(height: AppSpacing.sm),
              AppSectionCard(
                title: 'Ledger History',
                child: items.isEmpty
                    ? const Text('No wallet transactions yet.')
                    : Column(
                        children: items.map((t) {
                          final isCredit = t.type == TransactionType.credit;
                          final color = isCredit ? Colors.green : Colors.red;
                          final sign = isCredit ? '+' : '-';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(t.description ?? t.material),
                            subtitle: Text(
                              '${t.createdAt.toLocal().toString().split('.').first} - ${t.material}',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$sign NGN ${t.amount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (t.balanceAfter != null)
                                  Text(
                                    'Bal: ${t.balanceAfter!.toStringAsFixed(0)}',
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
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
