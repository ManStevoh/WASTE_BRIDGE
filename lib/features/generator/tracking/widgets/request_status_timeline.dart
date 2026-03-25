import 'package:flutter/material.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/features/shared/status_timeline_step.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/waste_request.dart';

import '../request_tracking_helpers.dart';

class RequestStatusTimeline extends StatelessWidget {
  const RequestStatusTimeline({
    super.key,
    required this.requestStatus,
    required this.currentIndex,
    required this.createdAt,
    required this.currentRequest,
  });

  final RequestStatus requestStatus;
  final int currentIndex;
  final DateTime createdAt;
  final WasteRequest? currentRequest;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Status Timeline',
      child: Column(
        children: [
          ...kRequestTrackingTimeline.asMap().entries.map((entry) {
            final index = entry.key;
            final status = entry.value;
            final done = index <= currentIndex;
            final active = index == currentIndex;
            return StatusTimelineStep(
              isDone: done,
              isActive: active,
              isLast:
                  index == kRequestTrackingTimeline.length - 1 &&
                  requestStatus != RequestStatus.cancelled,
              label: labelForRequestStatus(status),
              dateTime: dateForRequestStatus(
                status: status,
                createdAt: createdAt,
                item: currentRequest,
              ),
            );
          }),
          if (requestStatus == RequestStatus.cancelled)
            StatusTimelineStep(
              isDone: true,
              isActive: true,
              isLast: true,
              label: labelForRequestStatus(RequestStatus.cancelled),
              dateTime: currentRequest?.cancelledAt,
            ),
        ],
      ),
    );
  }
}
