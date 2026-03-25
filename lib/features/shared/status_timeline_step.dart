import 'package:flutter/material.dart';

/// Single step in a vertical status timeline.
class StatusTimelineStep extends StatelessWidget {
  const StatusTimelineStep({
    super.key,
    required this.isDone,
    required this.isActive,
    required this.isLast,
    required this.label,
    this.dateTime,
  });

  final bool isDone;
  final bool isActive;
  final bool isLast;
  final String label;
  final DateTime? dateTime;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dotColor = isDone ? scheme.primary : scheme.outline;
    final textColor = isActive ? scheme.primary : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: dotColor,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: isDone ? scheme.primary : scheme.outlineVariant,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: textColor,
                      ),
                ),
                if (dateTime != null)
                  Text(
                    dateTime!.toLocal().toString().split('.').first,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
