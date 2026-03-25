import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/core/ui/user_safe_error.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _quantity = TextEditingController(text: '20');
  final _location = TextEditingController(text: 'Nairobi Central');
  final _totalPrice = TextEditingController();
  final _unitPrice = TextEditingController();
  final _auctionHours = TextEditingController(text: '24');
  final _startingBid = TextEditingController();
  final _reservePrice = TextEditingController();
  final _bulkMin = TextEditingController();
  String _wasteType = 'Plastic';
  String _listingMode = 'fixed_price';
  bool _submitting = false;

  @override
  void dispose() {
    _quantity.dispose();
    _location.dispose();
    _totalPrice.dispose();
    _unitPrice.dispose();
    _auctionHours.dispose();
    _startingBid.dispose();
    _reservePrice.dispose();
    _bulkMin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_quantity.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity.')),
      );
      return;
    }
    final total = double.tryParse(_totalPrice.text);
    final unit = double.tryParse(_unitPrice.text);

    if (_listingMode == 'fixed_price' || _listingMode == 'bulk_contract') {
      if (total == null && unit == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter total price or unit price per kg.')),
        );
        return;
      }
    }

    double? bulkMin;
    if (_listingMode == 'bulk_contract') {
      bulkMin = double.tryParse(_bulkMin.text);
      if (bulkMin == null || bulkMin <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter minimum order quantity (kg) for bulk.')),
        );
        return;
      }
      if (bulkMin > qty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minimum cannot exceed total quantity.')),
        );
        return;
      }
    }

    String? auctionEndsAt;
    double? startingBid;
    double? reservePrice;
    if (_listingMode == 'auction') {
      startingBid = double.tryParse(_startingBid.text);
      if (startingBid == null || startingBid <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid starting bid.')),
        );
        return;
      }
      final hours = int.tryParse(_auctionHours.text) ?? 24;
      auctionEndsAt = DateTime.now().add(Duration(hours: hours)).toUtc().toIso8601String();
      final r = double.tryParse(_reservePrice.text);
      reservePrice = (r != null && r > 0) ? r : null;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(wasteListingServiceProvider).createListing(
            wasteType: _wasteType,
            quantityKg: qty,
            locationText: _location.text.trim(),
            totalPrice: total,
            unitPricePerKg: unit,
            listingMode: _listingMode,
            bulkMinQuantityKg: bulkMin,
            auctionEndsAt: auctionEndsAt,
            startingBid: startingBid,
            reservePrice: reservePrice,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing published to marketplace.')),
      );
      context.pop();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userVisibleError(e, fallback: 'Could not publish listing'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post marketplace listing')),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.md),
        children: [
          DropdownButtonFormField<String>(
            value: _wasteType,
            decoration: const InputDecoration(labelText: 'Waste type'),
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
          ),
          SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: 'Location (pickup)'),
          ),
          SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _totalPrice,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total price (KES) — optional if unit set',
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _unitPrice,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Unit price / kg (KES) — optional if total set',
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            value: _listingMode,
            decoration: const InputDecoration(labelText: 'Listing type'),
            items: const [
              DropdownMenuItem(value: 'fixed_price', child: Text('Fixed price')),
              DropdownMenuItem(value: 'bulk_contract', child: Text('Bulk (min order qty)')),
              DropdownMenuItem(value: 'auction', child: Text('Auction')),
            ],
            onChanged: (v) => setState(() => _listingMode = v!),
          ),
          if (_listingMode == 'bulk_contract') ...[
            SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _bulkMin,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum order (kg)',
              ),
            ),
          ],
          if (_listingMode == 'auction') ...[
            SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _startingBid,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Starting bid (KES)',
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _auctionHours,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Auction length (hours from now)',
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _reservePrice,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reserve price (KES) — optional',
              ),
            ),
          ],
          SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publish listing'),
          ),
        ],
      ),
    );
  }
}
