import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/screens/landing_screen.dart';
import 'package:usa_map_app/screens/find_reps_screen.dart';
import 'package:usa_map_app/screens/federal_branches_screen.dart';
import 'package:usa_map_app/screens/contact_congress_start_screen.dart';

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
  testWidgets(
    'image gallery stacks equal panels above a compact separate contact action',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
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
      final contact = find.byKey(const Key('home-contact-my-reps'));
      Rect panel(String label) => tester.getRect(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
      );
      final states = panel('US States');
      final branches = panel('Federal Branches');
      final reps = panel('Find My Reps');
      expect(states.width, 430 - 28);
      expect(branches.size, states.size);
      expect(reps.height, closeTo(states.height, .01));
      expect(branches.top - states.bottom, 12);
      expect(reps.top - branches.bottom, 12);
      expect(tester.getRect(contact).top - reps.bottom, 12);
      expect(tester.getRect(contact).bottom, closeTo(932 - 34 - 12, 1));
      expect(tester.getSize(contact).height, 60);
      expect(tester.getSize(contact).width, 430 - 28);
      expect(
        tester.widget<Text>(find.text('Contact My Reps')).style!.fontSize,
        21,
      );
      expect(
        tester.widget<Text>(find.text('Find My Reps')).style!.fontSize,
        25,
      );
      expect(find.byKey(const Key('find-reps-white-outline')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('gallery remains usable on a short phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<MapDataProvider>(
        create: (_) => _Provider(),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const LandingScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final contact = find.byKey(const Key('home-contact-my-reps'));
    await tester.ensureVisible(contact);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(contact);
    await tester.pumpAndSettle();
    expect(find.byType(ContactCongressStartScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
