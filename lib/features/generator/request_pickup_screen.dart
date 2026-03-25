import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/features/shared/info_row.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class RequestPickupScreen extends ConsumerStatefulWidget {
  const RequestPickupScreen({super.key});

  @override
  ConsumerState<RequestPickupScreen> createState() =>
      _RequestPickupScreenState();
}

class _RequestPickupScreenState extends ConsumerState<RequestPickupScreen> {
  final _quantity = TextEditingController();
  final _location = TextEditingController(text: 'Victoria Island, Lagos');
  String _wasteType = 'Plastic';
  DateTime? _scheduledAt;
  String? _selectedTemplate;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final quantity = double.tryParse(_quantity.text) ?? 0;
    final estimatedDistance = _location.text.toLowerCase().contains('lekki')
        ? 9.5
        : 5.0;
    final unitPrice = _unitPriceFor(_wasteType, estimatedDistance);
    final total = unitPrice * quantity;
    return Scaffold(
      appBar: AppBar(title: const Text('Request Pickup')),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.md),
        children: [
          DropdownButtonFormField<String>(
            value: _selectedTemplate,
            hint: const Text('Saved Template (optional)'),
            items: const [
              DropdownMenuItem(
                value: 'Office Plastic 20kg',
                child: Text('Office Plastic 20kg'),
              ),
              DropdownMenuItem(
                value: 'Market Organic 50kg',
                child: Text('Market Organic 50kg'),
              ),
            ],
            onChanged: (value) {
              setState(() => _selectedTemplate = value);
              if (value == null) return;
              if (value.contains('Plastic')) _wasteType = 'Plastic';
              if (value.contains('Organic')) _wasteType = 'Organic';
              _quantity.text = value.contains('20kg') ? '20' : '50';
            },
          ),
          SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            value: _wasteType,
            decoration: const InputDecoration(labelText: 'Waste Type'),
            items: const [
              'Plastic',
              'Paper',
              'Metal',
              'Organic',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _wasteType = v!),
          ),
          SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity (kg)'),
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Pickup location'),
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pickup Schedule'),
            subtitle: Text(
              _scheduledAt == null
                  ? 'Now / earliest available'
                  : _scheduledAt!.toLocal().toString().split('.').first,
            ),
            trailing: TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (date == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time == null) return;
                setState(() {
                  _scheduledAt = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                });
              },
              child: const Text('Pick slot'),
            ),
          ),
          const SizedBox(height: 8),
          AppSectionCard(
            title: 'Dynamic Pricing Preview',
            child: Column(
              children: [
                InfoRow(
                  label: 'Distance',
                  value: '${estimatedDistance.toStringAsFixed(1)} km',
                ),
                InfoRow(
                  label: 'Rate',
                  value: 'NGN ${unitPrice.toStringAsFixed(0)} / kg',
                ),
                InfoRow(
                  label: 'Estimated total',
                  value: 'NGN ${total.toStringAsFixed(0)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting
                ? null
                : () async {
                    setState(() => _submitting = true);
                    try {
                      await ref
                          .read(requestNotifierProvider.notifier)
                          .addRequest(
                            wasteType: _wasteType,
                            quantityKg: double.tryParse(_quantity.text) ?? 1,
                            location: _location.text.trim(),
                            scheduledAt: _scheduledAt,
                          );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Pickup request submitted successfully.',
                          ),
                        ),
                      );
                      context.pop();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    } finally {
                      if (mounted) setState(() => _submitting = false);
                    }
                  },
            child: _submitting
                ? const CircularProgressIndicator()
                : const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
}

double _unitPriceFor(String wasteType, double distanceKm) {
  final type = wasteType.toLowerCase();
  final base = switch (type) {
    'plastic' => 420.0,
    'paper' => 260.0,
    'metal' => 520.0,
    'organic' => 180.0,
    _ => 220.0,
  };
  return base - (distanceKm * 2);
}
