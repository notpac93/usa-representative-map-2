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
}
