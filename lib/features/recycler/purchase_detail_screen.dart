import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/core/ui/user_safe_error.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/features/shared/receipt_actions.dart';
import 'package:waste_bridge/features/shared/user_ratings_section.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/marketplace_order_detail.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class PurchaseDetailScreen extends ConsumerStatefulWidget {
  const PurchaseDetailScreen({super.key, required this.orderPublicId});

  final String orderPublicId;

  @override
  ConsumerState<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends ConsumerState<PurchaseDetailScreen> {
  final _phone = TextEditingController();
  bool _paying = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pay(MarketplaceOrderDetail order) async {
    final amount = order.subtotalAmount;
    if (amount == null) return;
    setState(() => _paying = true);
    try {
      final phone = _phone.text.trim().isEmpty ? null : _phone.text.trim();
      final result = await ref.read(paymentServiceProvider).initiatePayment(
            amount: amount,
            currency: order.currency ?? 'KES',
            orderPublicId: order.id,
            phone: phone,
          );
      ref.invalidate(orderDetailProvider(order.id));
      ref.invalidate(buyerOrdersProvider);
      if (!mounted) return;
      final mpesa = result['mpesa'];
      String msg = 'Payment intent created.';
      if (mpesa is Map) {
        final enabled = mpesa['enabled'];
        final client = mpesa['clientMessage']?.toString();
        if (enabled == false && client != null) {
          msg = client;
        } else if (client != null) {
          msg = client;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userVisibleError(e, fallback: 'Payment could not be started.'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userVisibleError(e, fallback: 'Payment could not be started.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDetailProvider(widget.orderPublicId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Order & delivery')),
      body: async.when(
        data: (order) {
          final pr = order.pickupRequest;
          final needPay = pr?.paymentStatus == PaymentStatus.unpaid;

          return ListView(
            padding: EdgeInsets.all(AppSpacing.md),
            children: [
              AppSectionCard(
                title: 'Order ${order.id}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${order.status}', style: theme.textTheme.bodyLarge),
                    Text(
                      'Escrow: ${order.escrowStatus ?? '—'}',
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (order.subtotalAmount != null)
                      Text(
                        'Amount: ${order.currency ?? 'KES'} ${order.subtotalAmount!.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyLarge,
                      ),
                    if (order.receiptId != null) ...[
                      Text('Receipt: ${order.receiptId}', style: theme.textTheme.bodyLarge),
                      SizedBox(height: AppSpacing.sm),
                      ReceiptActions(receiptId: order.receiptId!),
                    ],
                  ],
                ),
              ),
              if (order.sellerUserId != null) ...[
                SizedBox(height: AppSpacing.sm),
                UserRatingsSection(userPublicId: order.sellerUserId!),
              ],
              if (pr != null) ...[
                SizedBox(height: AppSpacing.sm),
                AppSectionCard(
                  title: 'Pickup',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Request: ${pr.id}', style: theme.textTheme.bodyLarge),
                      Text(
                        'Pickup status: ${pr.status.name}',
                        style: theme.textTheme.bodyLarge,
                      ),
                      Text(
                        'Payment: ${pr.paymentStatus.name}',
                        style: theme.textTheme.bodyLarge,
                      ),
                      Text('Location: ${pr.location}', style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
              ],
              if (order.jobPublicId != null) ...[
                SizedBox(height: AppSpacing.sm),
                AppSectionCard(
                  title: 'Collector job',
                  child: Text(
                    'Job ${order.jobPublicId} · ${order.jobStatus ?? '—'}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
              if (needPay && order.subtotalAmount != null) ...[
                SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'M-Pesa phone (optional if on profile)',
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: _paying ? null : () => _pay(order),
                  child: _paying
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Pay with M-Pesa (STK)'),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CenterState(
          title: 'Could not load order',
          subtitle: userVisibleError(e),
          icon: Icons.error_outline,
        ),
      ),
    );
  }
}
