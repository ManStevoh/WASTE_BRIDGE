import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/core/ui/user_safe_error.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/models/marketplace_listing.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class RecyclerListingDetailScreen extends ConsumerStatefulWidget {
  const RecyclerListingDetailScreen({super.key, required this.listing});

  final MarketplaceListing listing;

  @override
  ConsumerState<RecyclerListingDetailScreen> createState() =>
      _RecyclerListingDetailScreenState();
}

class _RecyclerListingDetailScreenState
    extends ConsumerState<RecyclerListingDetailScreen> {
  bool _busy = false;
  late final TextEditingController _quantityController;
  late final TextEditingController _bidAmountController;

  @override
  void initState() {
    super.initState();
    final min = widget.listing.bulkMinQuantityKg;
    _quantityController = TextEditingController(
      text: min != null ? min.toString() : '',
    );
    final bidBase = widget.listing.currentBidAmount ?? widget.listing.startingBid;
    _bidAmountController = TextEditingController(
      text: bidBase != null ? bidBase.toString() : '',
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _bidAmountController.dispose();
    super.dispose();
  }

  Future<void> _purchase(BuildContext context) async {
    final l = widget.listing;
    double? qty;
    if (l.listingMode == 'bulk_contract') {
      qty = double.tryParse(_quantityController.text.trim());
      if (qty == null || qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid quantity (kg).')),
        );
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final order = await ref.read(orderServiceProvider).purchaseListing(
            listingPublicId: l.id,
            quantityKg: qty,
          );
      ref.invalidate(buyerOrdersProvider);
      ref.invalidate(marketplaceFeedProvider);
      if (!context.mounted) return;
      context.pushReplacement('/recycler/order/${order.id}');
    } on DioException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dioResponseMessage(e) ??
                  userVisibleError(e, fallback: 'Purchase failed'),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userVisibleError(e, fallback: 'Purchase failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _placeBid(BuildContext context) async {
    final amount = double.tryParse(_bidAmountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid bid amount.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(orderServiceProvider).placeBid(
            listingPublicId: widget.listing.id,
            amount: amount,
          );
      ref.invalidate(marketplaceFeedProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid placed.')),
      );
    } on DioException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dioResponseMessage(e) ??
                  userVisibleError(e, fallback: 'Bid failed'),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userVisibleError(e, fallback: 'Bid failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final theme = Theme.of(context);
    final auth = ref.watch(authNotifierProvider).valueOrNull;
    final price = l.totalPrice != null
        ? 'KES ${l.totalPrice!.toStringAsFixed(0)}'
        : (l.unitPricePerKg != null
            ? 'KES ${l.unitPricePerKg!.toStringAsFixed(0)} / kg'
            : '—');

    final isAuction = l.listingMode == 'auction';
    final isBulk = l.listingMode == 'bulk_contract';
    final auctionOpen = l.auctionStatus == 'open';
    final auctionEnded = l.auctionStatus == 'ended';
    final isWinningBidder =
        auth != null && l.currentHighestBidderUserId == auth.id;

    Widget action;
    if (isAuction && auctionOpen) {
      action = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (l.startingBid != null)
            Text('Starting bid: KES ${l.startingBid!.toStringAsFixed(0)}',
                style: theme.textTheme.bodyMedium),
          if (l.currentBidAmount != null)
            Text('Current bid: KES ${l.currentBidAmount!.toStringAsFixed(0)}',
                style: theme.textTheme.bodyMedium),
          if (l.auctionEndsAt != null)
            Text('Ends: ${l.auctionEndsAt}', style: theme.textTheme.bodySmall),
          SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _bidAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Your bid (KES)',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _busy ? null : () => _placeBid(context),
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Place bid'),
          ),
        ],
      );
    } else if (isAuction && auctionEnded) {
      if (isWinningBidder) {
        action = FilledButton(
          onPressed: _busy ? null : () => _purchase(context),
          child: _busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Complete purchase (winning bid)'),
        );
      } else {
        action = Text(
          'This auction has ended. Only the winning bidder can create an order.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      }
    } else if (isBulk) {
      action = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (l.bulkMinQuantityKg != null)
            Text(
              'Minimum order: ${l.bulkMinQuantityKg} kg (max listed: ${l.quantityKg} kg)',
              style: theme.textTheme.bodySmall,
            ),
          SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quantity to buy (kg)',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _busy ? null : () => _purchase(context),
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create order & pay next'),
          ),
        ],
      );
    } else {
      action = FilledButton(
        onPressed: _busy ? null : () => _purchase(context),
        child: _busy
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Create order & pay next'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.wasteType)),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.md),
        children: [
          AppSectionCard(
            title: 'Listing',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quantity: ${l.quantityKg} kg', style: theme.textTheme.bodyLarge),
                SizedBox(height: AppSpacing.xs),
                Text('Location: ${l.locationText}', style: theme.textTheme.bodyLarge),
                SizedBox(height: AppSpacing.xs),
                Text('Price: $price', style: theme.textTheme.bodyLarge),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Mode: ${l.listingMode}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),
          action,
        ],
      ),
    );
  }
}
