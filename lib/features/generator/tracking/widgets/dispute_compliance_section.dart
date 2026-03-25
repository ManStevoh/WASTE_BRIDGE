import 'package:flutter/material.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/features/shared/info_row.dart';
import 'package:waste_bridge/models/waste_request.dart';

class DisputeComplianceSection extends StatelessWidget {
  const DisputeComplianceSection({
    super.key,
    required this.request,
    required this.onReportIssue,
    required this.onResolveDispute,
  });

  final WasteRequest request;
  final VoidCallback onReportIssue;
  final VoidCallback onResolveDispute;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Dispute and Compliance',
      child: Column(
        children: [
          InfoRow(
            label: 'Dispute',
            value: request.isDisputed == true ? 'Open' : 'None',
          ),
          InfoRow(
            label: 'Reason',
            value: request.disputeReason ?? 'N/A',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onReportIssue,
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Report an Issue'),
                ),
                if (request.isDisputed == true)
                  TextButton.icon(
                    onPressed: onResolveDispute,
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Resolve Dispute'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
