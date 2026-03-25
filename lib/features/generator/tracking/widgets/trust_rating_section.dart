import 'package:flutter/material.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/features/shared/info_row.dart';
import 'package:waste_bridge/models/waste_request.dart';

import '../request_tracking_helpers.dart';

class TrustRatingSection extends StatelessWidget {
  const TrustRatingSection({
    super.key,
    required this.request,
    required this.onRatePickup,
  });

  final WasteRequest request;
  final VoidCallback? onRatePickup;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Trust and Rating',
      child: Column(
        children: [
          InfoRow(
            label: 'Generator Rating',
            value: formatRequestRating(request.generatorRating),
          ),
          InfoRow(
            label: 'Collector Rating',
            value: formatRequestRating(request.collectorRating),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRatePickup,
              icon: const Icon(Icons.star_rate_rounded),
              label: const Text('Rate This Pickup'),
            ),
          ),
        ],
      ),
    );
  }
}
