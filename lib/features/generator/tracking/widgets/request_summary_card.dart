import 'package:flutter/material.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/features/shared/info_row.dart';

class RequestSummaryCard extends StatelessWidget {
  const RequestSummaryCard({
    super.key,
    required this.requestId,
    required this.wasteType,
    required this.quantityKg,
    required this.location,
    required this.createdAt,
  });

  final String requestId;
  final String wasteType;
  final double quantityKg;
  final String location;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Request Details',
      child: Column(
        children: [
          InfoRow(label: 'Request ID', value: requestId),
          InfoRow(label: 'Waste Type', value: wasteType),
          InfoRow(label: 'Quantity', value: '$quantityKg kg'),
          InfoRow(label: 'Location', value: location),
          InfoRow(
            label: 'Created',
            value: createdAt.toLocal().toString().split('.').first,
          ),
        ],
      ),
    );
  }
}
