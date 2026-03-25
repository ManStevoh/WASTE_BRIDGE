import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/core/ui/user_safe_error.dart';
import 'package:waste_bridge/features/shared/receipt_pdf_screen.dart';
import 'package:waste_bridge/providers/app_providers.dart';

/// View JSON receipt and download PDF (`GET /receipts/{id}`, `/pdf`).
class ReceiptActions extends ConsumerStatefulWidget {
  const ReceiptActions({super.key, required this.receiptId});

  final String receiptId;

  @override
  ConsumerState<ReceiptActions> createState() => _ReceiptActionsState();
}

class _ReceiptActionsState extends ConsumerState<ReceiptActions> {
  bool _busy = false;

  Future<void> _viewJson() async {
    setState(() => _busy = true);
    try {
      final data =
          await ref.read(receiptServiceProvider).getReceipt(widget.receiptId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Receipt'),
          content: SingleChildScrollView(
            child: SelectableText(
              _formatReceipt(data),
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userVisibleError(e, fallback: 'Could not load receipt.'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userVisibleError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _viewPdfInApp() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => ReceiptPdfScreen(receiptId: widget.receiptId),
      ),
    );
  }

  Future<void> _downloadPdf() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(receiptServiceProvider)
          .downloadAndOpenPdf(widget.receiptId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF opened.')),
      );
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userVisibleError(e, fallback: 'Could not download PDF.'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userVisibleError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _formatReceipt(Map<String, dynamic> data) {
    final buf = StringBuffer();
    void line(String k, Object? v) {
      if (v != null) buf.writeln('$k: $v');
    }

    line('Receipt ID', data['receiptId']);
    line('Issued', data['issuedAt']);
    line('Pickup request', data['pickupRequestId']);
    line('Order', data['orderId']);
    line('Currency', data['currency']);
    final items = data['lineItems'];
    if (items is List) {
      buf.writeln('Line items:');
      for (final it in items) {
        if (it is Map) {
          buf.writeln('  — ${it['description']}: ${it['totalAmount']}');
        }
      }
    }
    final escrow = data['escrow'];
    if (escrow is Map) {
      buf.writeln('Escrow: ${escrow['status']} ${escrow['amount']}');
    }
    return buf.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _viewJson,
          icon: const Icon(Icons.article_outlined, size: 18),
          label: const Text('View details'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _viewPdfInApp,
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('View PDF in app'),
        ),
        FilledButton.tonalIcon(
          onPressed: _busy ? null : _downloadPdf,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('Download PDF'),
        ),
      ],
    );
  }
}
