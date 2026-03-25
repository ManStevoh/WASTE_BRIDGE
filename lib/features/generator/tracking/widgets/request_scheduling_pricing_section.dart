import 'package:flutter/material.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/features/shared/info_row.dart';
import 'package:waste_bridge/models/waste_request.dart';

class RequestSchedulingPricingSection extends StatelessWidget {
  const RequestSchedulingPricingSection({super.key, required this.request});

  final WasteRequest request;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Scheduling and Pricing',
      child: Column(
        children: [
          InfoRow(
            label: 'Scheduled',
            value: request.scheduledAt == null
                ? 'Not set'
                : request.scheduledAt!.toLocal().toString().split('.').first,
          ),
          InfoRow(
            label: 'Rescheduled',
            value: request.rescheduledAt == null
                ? 'No'
                : request.rescheduledAt!.toLocal().toString().split('.').first,
          ),
          InfoRow(
            label: 'Distance',
            value: request.distanceKm == null
                ? 'Unknown'
                : '${request.distanceKm!.toStringAsFixed(1)} km',
          ),
          InfoRow(
            label: 'Price/kg',
            value: request.unitPricePerKg == null
                ? 'TBD'
                : 'NGN ${request.unitPricePerKg!.toStringAsFixed(0)}',
          ),
          InfoRow(
            label: 'Total Amount',
            value: request.totalAmount == null
                ? 'TBD'
                : 'NGN ${request.totalAmount!.toStringAsFixed(0)}',
          ),
        ],
      ),
    );
  }
}
