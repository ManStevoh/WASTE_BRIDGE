import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/features/shared/info_row.dart';
import 'package:waste_bridge/features/shared/user_ratings_section.dart';
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
    final collectorId = request.collectorPublicId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionCard(
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
        ),
        if (collectorId != null && collectorId.isNotEmpty) ...[
          SizedBox(height: AppSpacing.sm),
          UserRatingsSection(
            userPublicId: collectorId,
            title: 'Collector ratings',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  context.push('/users/$collectorId/ratings'),
              child: const Text('View all ratings'),
            ),
          ),
        ],
      ],
    );
  }
}
