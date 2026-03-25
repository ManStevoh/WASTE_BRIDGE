import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/core/ui/user_safe_error.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class WalletLedgerScreen extends ConsumerStatefulWidget {
  const WalletLedgerScreen({super.key});

  @override
  ConsumerState<WalletLedgerScreen> createState() => _WalletLedgerScreenState();
}

class _WalletLedgerScreenState extends ConsumerState<WalletLedgerScreen> {
  bool _exporting = false;
  DateTime? _exportFrom;
  DateTime? _exportTo;

  Future<void> _pickExportRange() async {
    final now = DateTime.now();
    final initialFrom = _exportFrom ?? now.subtract(const Duration(days: 30));
    final initialTo = _exportTo ?? now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: initialFrom, end: initialTo),
    );
    if (picked != null) {
      setState(() {
        _exportFrom = picked.start;
        _exportTo = picked.end;
      });
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      await ref.read(transactionServiceProvider).exportLedgerOpen(
            from: _exportFrom,
            to: _exportTo,
          );
      if (!mounted) return;
      ref.invalidate(walletBalanceProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV opened.')),
      );
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userVisibleError(e, fallback: 'Export failed.'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userVisibleError(e, fallback: 'Export failed.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsProvider);
    final balAsync = ref.watch(walletBalanceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Ledger'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            onPressed: _exporting ? null : _exportCsv,
            icon: _exporting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: txAsync.when(
        data: (items) {
          return ListView(
            padding: EdgeInsets.all(AppSpacing.md),
            children: [
              balAsync.when(
                data: (w) => AppSectionCard(
                  title: 'Wallet balance (server)',
                  child: Text(
                    '${w.currency} ${w.balance.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                loading: () => const AppSectionCard(
                  title: 'Wallet balance',
                  child: LinearProgressIndicator(),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              SizedBox(height: AppSpacing.sm),
              AppSectionCard(
                title: 'CSV export range',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _exportFrom == null && _exportTo == null
                          ? 'All time (no date filter)'
                          : '${_exportFrom!.toLocal().toString().split(' ').first} → ${_exportTo!.toLocal().toString().split(' ').first}',
                    ),
                    SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _pickExportRange,
                      icon: const Icon(Icons.date_range_outlined),
                      label: const Text('Choose date range'),
                    ),
                    if (_exportFrom != null || _exportTo != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _exportFrom = null;
                          _exportTo = null;
                        }),
                        child: const Text('Clear range'),
                      ),
                  ],
                ),
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
                                  '$sign ${t.amount.toStringAsFixed(0)}',
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
