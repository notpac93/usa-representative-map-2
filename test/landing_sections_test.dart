import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/screens/landing_screen.dart';
import 'package:usa_map_app/screens/find_reps_screen.dart';
import 'package:usa_map_app/screens/federal_branches_screen.dart';
import 'package:usa_map_app/screens/contact_congress_start_screen.dart';
import 'package:usa_map_app/widgets/civic_glass.dart';

class _Provider extends MapDataProvider {
  @override
  Future<void> loadAllData() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 430.0, 1024.0]) {
    testWidgets('three landing routes fit at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<MapDataProvider>(
          create: (_) => _Provider(),
          child: const MaterialApp(home: LandingScreen()),
        ),
      );
      await tester.pump();
      for (final label in ['Find My Reps', 'US States', 'Federal Branches']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Contact My Reps'), findsOneWidget);
      expect(find.text('Your Representatives'), findsOneWidget);
      expect(find.text('Your government'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Find My Reps'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FindRepsScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
  testWidgets('Federal Branches opens its own chooser', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<MapDataProvider>(
        create: (_) => _Provider(),
        child: const MaterialApp(home: LandingScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Federal Branches'));
    await tester.pumpAndSettle();
    expect(find.byType(FederalBranchesScreen), findsOneWidget);
    expect(find.text('Legislative Branch'), findsOneWidget);
    expect(find.text('Executive Branch'), findsOneWidget);
    expect(find.text('Judicial Branch'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('home contact action opens address-based constituent flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<MapDataProvider>(
        create: (_) => _Provider(),
        child: const MaterialApp(home: LandingScreen()),
      ),
    );
    await tester.pump();
    final button = find.byKey(const Key('home-contact-my-reps'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(ContactCongressStartScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [320.0, 430.0]) {
    testWidgets('four matching home controls fill the phone at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 932);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(
        ChangeNotifierProvider<MapDataProvider>(
          create: (_) => _Provider(),
          child: const MaterialApp(home: LandingScreen()),
        ),
      );
      await tester.pump();
      final controls = [
        'US States',
        'Federal Branches',
        'Find My Reps',
        'Contact My Reps',
      ].map((label) => find.byKey(ValueKey('home-label-$label'))).toList();
      final heights = controls.map((f) => tester.getSize(f).height);
      for (final height in heights) {
        expect(height, 80);
      }
      expect(tester.getSize(controls[2]), tester.getSize(controls[3]));
      expect(tester.getBottomLeft(controls[3]).dy, closeTo(932 - 34 - 12, 1));
      for (final label in ['US States', 'Federal Branches', 'Find My Reps']) {
        expect(
          tester
              .widget<CivicColorReveal>(
                find.byKey(ValueKey('home-color-$label')),
              )
              .amount,
          0,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'portraits gain color while opening and return to grayscale on Back',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<MapDataProvider>(
          create: (_) => _Provider(),
          child: const MaterialApp(home: LandingScreen()),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Find My Reps'));
      await tester.pump();
      await tester.pump();
      final reveal = find.byKey(const Key('destination-color-reveal'));
      expect(tester.widget<CivicColorReveal>(reveal).amount, 0);
      await tester.pump(const Duration(milliseconds: 360));
      expect(
        tester.widget<CivicColorReveal>(reveal).amount,
        inExclusiveRange(0, 1),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(tester.widget<CivicColorReveal>(reveal).amount, 1);
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(FindRepsScreen), findsNothing);
      expect(
        tester
            .widget<CivicColorReveal>(
              find.byKey(const ValueKey('home-color-Find My Reps')),
            )
            .amount,
        0,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
