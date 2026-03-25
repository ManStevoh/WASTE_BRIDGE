import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/features/shared/info_row.dart';
import 'package:waste_bridge/features/shared/status_timeline_step.dart';

void main() {
  testWidgets('AppSectionCard shows title, trailing, and child', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSectionCard(
            title: 'Section',
            trailing: const Text('More'),
            child: const Text('Inner'),
          ),
        ),
      ),
    );
    expect(find.text('Section'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Inner'), findsOneWidget);
  });

  testWidgets('CenterState shows title, subtitle, and icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CenterState(
            title: 'Empty',
            subtitle: 'Nothing here',
            icon: Icons.hourglass_empty,
          ),
        ),
      ),
    );
    expect(find.text('Empty'), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
  });

  testWidgets('InfoRow shows label and value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoRow(label: 'Quantity', value: '12 kg'),
        ),
      ),
    );
    expect(find.text('Quantity:'), findsOneWidget);
    expect(find.text('12 kg'), findsOneWidget);
  });

  testWidgets('StatusTimelineStep shows label and optional date', (tester) async {
    final dt = DateTime(2024, 6, 15, 14, 30);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusTimelineStep(
            isDone: true,
            isActive: true,
            isLast: false,
            label: 'Accepted',
            dateTime: dt,
          ),
        ),
      ),
    );
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.textContaining('2024'), findsWidgets);
  });
}
