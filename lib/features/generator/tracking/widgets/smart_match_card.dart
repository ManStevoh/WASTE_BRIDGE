import 'package:flutter/material.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/features/shared/info_row.dart';
import 'package:waste_bridge/models/waste_request.dart';

class SmartMatchCard extends StatelessWidget {
  const SmartMatchCard({super.key, required this.request});

  final WasteRequest? request;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Smart Match',
      child: Column(
        children: [
          InfoRow(
            label: 'Suggested Collector',
            value: request?.suggestedCollectorName ?? 'Matching in progress',
          ),
          InfoRow(
            label: 'Estimated ETA',
            value: request?.estimatedEtaMinutes == null
                ? 'TBD'
                : '${request?.estimatedEtaMinutes} mins',
          ),
        ],
      ),
    );
  }
}
