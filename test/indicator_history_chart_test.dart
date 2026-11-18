import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/widgets/indicator_history_chart.dart';

void main() {
  test('Missing months and years remain gaps', () {
    expect(
      const HistoryPoint(
        '2025-11',
        4,
      ).followsGap(const HistoryPoint('2025-09', 3)),
      isTrue,
    );
    expect(
      const HistoryPoint(
        '2025-02',
        4,
      ).followsGap(const HistoryPoint('2025-01', 3)),
      isFalse,
    );
    expect(
      const HistoryPoint('2021', 4).followsGap(const HistoryPoint('2019', 3)),
      isTrue,
    );
    expect(const HistoryPoint('2025', 4).date.year, 2025);
  });
  testWidgets(
    'Annual chart changes period and exposes exact estimates and uncertainty',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IndicatorHistoryChart(
                title: 'Income history',
                unit: 'USD',
                source: 'Census ACS',
                survey: true,
                note: 'Reporting-year dollars.',
                points: [
                  for (var y = 2021; y <= 2025; y++)
                    HistoryPoint(
                      '$y',
                      80000 + (y - 2021) * 1000,
                      marginOfError: 250,
                    ),
                ],
                onSource: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('2025: \$84,000 ±\$250'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '3 years'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2023–2025'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2023').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('2023: \$82,000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Rate change uses percentage points and missing history stays empty',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: IndicatorHistoryChart(
                title: 'Unemployment history',
                unit: 'percent',
                source: 'BLS',
                note: 'Seasonally adjusted.',
                points: const [
                  HistoryPoint('2025-01', 5),
                  HistoryPoint('2025-03', 4.5),
                ],
                onSource: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('-0.5 percentage points'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IndicatorHistoryChart(
              key: const ValueKey('empty'),
              title: 'Missing history',
              unit: 'USD',
              source: 'Census',
              note: '',
              points: const [],
              onSource: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('At least two published observations'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
