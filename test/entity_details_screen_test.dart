import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/screens/entity_details_screen.dart';

void main() {
  setUp(() => rootBundle.clear());
  testWidgets(
    'Details opens the matching profile and exposes sourced population history',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EntityDetailsButton(
              name: 'California',
              category: 'State',
              stateId: 'CA',
              isState: true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('California'), findsOneWidget);
      expect(find.text('Population snapshot'), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, 'Trends'));
      await tester.pumpAndSettle();
      expect(find.text('Population · 2020–2024'), findsOneWidget);
      await tester.tap(find.text('3 years'));
      await tester.pumpAndSettle();
      expect(find.text('Population · 2022–2024'), findsOneWidget);
      await tester.tap(find.text('GDP'));
      await tester.pumpAndSettle();
      expect(find.text('GDP data not connected'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.tap(find.text('Sources').first);
      await tester.pumpAndSettle();
      expect(
        find.text('Census population dataset · Vintage 2024'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Leader and city context stays distinct from statewide population',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: EntityDetailsScreen(
            name: 'A governor',
            category: 'Governor',
            stateId: 'CA',
            isLeader: true,
            facts: {'Recorded term': '2023–2027'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Office at a glance'), findsOneWidget);
      expect(find.text('Population snapshot'), findsNothing);
      await tester.tap(find.widgetWithText(Tab, 'Trends'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not an individual leader'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Unavailable jurisdiction has an honest empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EntityDetailsScreen(
          name: 'National office',
          category: 'President',
          isLeader: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Trends'));
    await tester.pumpAndSettle();
    expect(find.text('Population data not connected'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
