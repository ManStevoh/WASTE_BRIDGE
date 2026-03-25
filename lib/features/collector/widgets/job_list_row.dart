import 'package:flutter/material.dart';
import 'package:waste_bridge/models/job.dart';

class JobListRow extends StatelessWidget {
  const JobListRow({super.key, required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${job.wasteType} - ${job.quantityKg}kg'),
      subtitle: Text(job.pickupLocation),
      trailing: TextButton(onPressed: onTap, child: const Text('Details')),
    );
  }
}
