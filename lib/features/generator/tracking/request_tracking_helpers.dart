import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/models/waste_request.dart';

/// Ordered steps shown on the generator request tracking screen.
const List<RequestStatus> kRequestTrackingTimeline = [
  RequestStatus.pending,
  RequestStatus.accepted,
  RequestStatus.pickedUp,
  RequestStatus.completed,
];

String labelForRequestStatus(RequestStatus status) {
  switch (status) {
    case RequestStatus.pending:
      return 'Pending';
    case RequestStatus.accepted:
      return 'Accepted by Collector';
    case RequestStatus.pickedUp:
      return 'Waste Picked Up';
    case RequestStatus.completed:
      return 'Completed';
    case RequestStatus.cancelled:
      return 'Cancelled';
  }
}

String formatRequestRating(double? rating) {
  if (rating == null) return 'Not rated';
  return '${rating.toStringAsFixed(1)} / 5';
}

DateTime? dateForRequestStatus({
  required RequestStatus status,
  required DateTime createdAt,
  required WasteRequest? item,
}) {
  switch (status) {
    case RequestStatus.pending:
      return createdAt;
    case RequestStatus.accepted:
      return item?.acceptedAt;
    case RequestStatus.pickedUp:
      return item?.pickedUpAt;
    case RequestStatus.completed:
      return item?.completedAt;
    case RequestStatus.cancelled:
      return item?.cancelledAt;
  }
}
