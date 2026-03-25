import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/core/ui/user_safe_error.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class RecyclerDashboardScreen extends ConsumerWidget {
  const RecyclerDashboardScreen({super.key});

  static const _sortChoices = <String, String>{
    'newest': 'Newest',
    'price_asc': 'Price ↑',
    'price_desc': 'Price ↓',
    'nearest': 'Nearest (set GPS)',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(marketplaceFeedProvider);
    final theme = Theme.of(context);
    final sort = ref.watch(marketplaceSortProvider);
    final mode = ref.watch(marketplaceListingModeProvider);
    final wallet = ref.watch(walletBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycler Dashboard'),
        actions: [
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
          ),
          IconButton(
            onPressed: () => context.push('/kyc'),
            icon: const Icon(Icons.verified_user_outlined),
            tooltip: 'Identity verification',
          ),
          IconButton(
            onPressed: () => context.push('/recycler/wallet'),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Wallet',
          ),
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
              ref.invalidate(walletBalanceProvider);
              await ref.read(marketplaceFeedProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(AppSpacing.md),
              children: [
                wallet.when(
                  data: (w) => AppSectionCard(
                    title: 'Wallet balance',
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${w.currency} ${w.balance.toStringAsFixed(2)}',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/recycler/wallet'),
                          child: const Text('Ledger'),
                        ),
                      ],
                    ),
                  ),
                  loading: () => const AppSectionCard(
                    title: 'Wallet balance',
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: () => context.push('/recycler/transactions'),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('My purchases'),
                ),
                SizedBox(height: AppSpacing.md),
                AppSectionCard(
                  title: 'Browse & filters',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        value: sort,
                        decoration: const InputDecoration(
                          labelText: 'Sort',
                          border: OutlineInputBorder(),
                        ),
                        items: _sortChoices.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            ref.read(marketplaceSortProvider.notifier).state =
                                v;
                            ref.invalidate(marketplaceFeedProvider);
                          }
                        },
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text('Listing type', style: theme.textTheme.labelLarge),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: mode == null,
                            onSelected: (_) {
                              ref
                                  .read(marketplaceListingModeProvider.notifier)
                                  .state = null;
                              ref.invalidate(marketplaceFeedProvider);
                            },
                          ),
                          FilterChip(
                            label: const Text('Fixed'),
                            selected: mode == 'fixed_price',
                            onSelected: (_) {
                              ref
                                      .read(marketplaceListingModeProvider
                                          .notifier)
                                      .state =
                                  'fixed_price';
                              ref.invalidate(marketplaceFeedProvider);
                            },
                          ),
                          FilterChip(
                            label: const Text('Bulk'),
                            selected: mode == 'bulk_contract',
                            onSelected: (_) {
                              ref
                                      .read(marketplaceListingModeProvider
                                          .notifier)
                                      .state =
                                  'bulk_contract';
                              ref.invalidate(marketplaceFeedProvider);
                            },
                          ),
                          FilterChip(
                            label: const Text('Auction'),
                            selected: mode == 'auction',
                            onSelected: (_) {
                              ref
                                  .read(marketplaceListingModeProvider.notifier)
                                  .state = 'auction';
                              ref.invalidate(marketplaceFeedProvider);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Marketplace feed. Pull down to refresh.',
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
