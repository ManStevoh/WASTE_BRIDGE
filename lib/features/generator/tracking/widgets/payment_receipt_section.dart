import 'package:flutter/material.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/features/shared/info_row.dart';
import 'package:waste_bridge/features/shared/receipt_actions.dart';
import 'package:waste_bridge/models/waste_request.dart';

class PaymentReceiptSection extends StatelessWidget {
  const PaymentReceiptSection({super.key, required this.request});

  final WasteRequest request;

  @override
  Widget build(BuildContext context) {
    final hasReceipt = request.receiptId != null && request.receiptId!.isNotEmpty;

    return AppSectionCard(
      title: 'Payment and Receipt',
      child: Column(
        children: [
          InfoRow(
            label: 'Payment',
            value: request.paymentStatus.name.toUpperCase(),
          ),
          InfoRow(
            label: 'Receipt ID',
            value: request.receiptId ?? 'Pending issuance',
          ),
          InfoRow(
            label: 'Receipt time',
            value: request.receiptIssuedAt == null
                ? 'N/A'
                : request.receiptIssuedAt!.toLocal().toString().split('.').first,
          ),
          if (hasReceipt) ...[
            SizedBox(height: AppSpacing.md),
            ReceiptActions(receiptId: request.receiptId!),
          ],
        ],
      ),
    );
  }
}
