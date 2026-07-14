import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/providers/timezone_provider.dart';
import 'package:hello/widgets/ai_structured_widgets.dart';
import 'package:provider/provider.dart';

Widget _host(Widget child) => ChangeNotifierProvider(
      create: (_) => TimezoneProvider('Asia/Kolkata'),
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('renders Markdown formatting instead of raw Markdown syntax',
      (tester) async {
    await tester.pumpWidget(_host(const AIMessageStructuredWidget(
      text: '**Hemoglobin** is shown below the displayed reference range.',
    )));

    expect(find.text('**Hemoglobin** is shown below the displayed reference range.'),
        findsNothing);
    expect(find.textContaining('Hemoglobin'), findsOneWidget);
  });

  testWidgets('keeps a wide result table scrollable on a narrow screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(const AITableWidget(
      title: 'Test Results',
      data: {
        'columns': ['Long test name', 'Reference range', 'Interpretation'],
        'rows': [
          [
            'Very long laboratory measurement name that should wrap safely',
            '1000–2000 units per litre',
            'Within the displayed reference range',
          ],
        ],
      },
    )));

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('formats source-card dates without exposing raw ISO values',
      (tester) async {
    await tester.pumpWidget(_host(const DocumentPreviewCard(
      id: 'document-1',
      name: 'Hospital report',
      type: 'Report',
      date: '2026-06-25T00:00:00.000Z',
      previewAvailable: true,
    )));

    expect(find.text('25 Jun 2026'), findsOneWidget);
    expect(find.text('2026-06-25T00:00:00.000Z'), findsNothing);
  });
}
