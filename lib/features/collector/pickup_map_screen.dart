import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pickup_map_view.dart';

class PickupMapScreen extends ConsumerWidget {
  const PickupMapScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PickupMapView(jobId: jobId);
  }
}
