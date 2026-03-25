import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_bridge/providers/app_providers.dart';

Future<void> showRequestRatingsDialog(
  BuildContext context,
  WidgetRef ref,
  String requestId,
) async {
  double generator = 4;
  double collector = 4;
  final submitted = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocalState) {
        return AlertDialog(
          title: const Text('Submit Ratings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Generator: ${generator.toStringAsFixed(1)}'),
              Slider(
                min: 1,
                max: 5,
                divisions: 8,
                value: generator,
                onChanged: (value) => setLocalState(() => generator = value),
              ),
              const SizedBox(height: 8),
              Text('Collector: ${collector.toStringAsFixed(1)}'),
              Slider(
                min: 1,
                max: 5,
                divisions: 8,
                value: collector,
                onChanged: (value) => setLocalState(() => collector = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    ),
  );
  if (submitted != true) return;
  await ref.read(requestNotifierProvider.notifier).submitRatings(
        requestId: requestId,
        generatorRating: generator,
        collectorRating: collector,
      );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Ratings submitted successfully.')),
  );
}

Future<void> showRequestDisputeDialog(
  BuildContext context,
  WidgetRef ref,
  String requestId,
) async {
  final reasonController = TextEditingController();
  final submitted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Report Dispute'),
      content: TextField(
        controller: reasonController,
        decoration: const InputDecoration(
          labelText: 'Reason',
          hintText: 'Describe issue with pickup/payment',
        ),
        minLines: 2,
        maxLines: 4,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Submit'),
        ),
      ],
    ),
  );
  if (submitted != true) return;
  final reason = reasonController.text.trim();
  if (reason.isEmpty) return;
  await ref
      .read(requestNotifierProvider.notifier)
      .reportDispute(requestId: requestId, reason: reason);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Dispute reported successfully.')),
  );
}

Future<void> resolveRequestDispute(
  BuildContext context,
  WidgetRef ref,
  String requestId,
) async {
  await ref.read(requestNotifierProvider.notifier).resolveDispute(requestId: requestId);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Dispute resolved and payment marked as paid.'),
    ),
  );
}
