import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/screens/landing_screen.dart';
import 'package:usa_map_app/screens/federal_branches_screen.dart';
import 'package:usa_map_app/screens/president_detail_screen.dart';
import 'package:usa_map_app/widgets/civic_glass.dart';

class _Provider extends MapDataProvider {
  @override
  Future<void> loadAllData() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Widget app({bool reduced = false}) => ChangeNotifierProvider<MapDataProvider>(
    create: (_) => _Provider(),
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: const LandingScreen(),
      ),
    ),
  );

  testWidgets('branch image expands, gains color, and contracts on Back', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.text('Federal Branches'));
    await tester.pump();
    await tester.pump();
    final surface = find.byKey(const Key('expanding-image-surface'));
    final start = tester.getRect(surface);
    expect(
      tester
          .widget<FederalBranchArtwork>(find.byType(FederalBranchArtwork).last)
          .colorAmount,
      0,
    );
    await tester.pump(const Duration(milliseconds: 360));
    final middle = tester.getRect(surface);
    expect(middle.width, greaterThan(start.width));
    expect(middle.height, greaterThan(start.height));
    final color = tester
        .widget<FederalBranchArtwork>(find.byType(FederalBranchArtwork).last)
        .colorAmount;
    expect(color, greaterThan(0));
    expect(color, lessThan(1));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FederalBranchArtwork>(find.byType(FederalBranchArtwork).last)
          .colorAmount,
      1,
    );
    expect(find.byType(CivicGlassPanel), findsNWidgets(3));
    final full = tester.getRect(surface);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));
    expect(tester.getRect(surface).width, lessThan(full.width));
    await tester.pumpAndSettle();
    expect(find.byType(FederalBranchesScreen), findsNothing);
    expect(find.text('Your Representatives'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion opens the full destination immediately', (
    tester,
  ) async {
    await tester.pumpWidget(app(reduced: true));
    await tester.pump();
    await tester.tap(find.text('Federal Branches'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FederalBranchArtwork>(find.byType(FederalBranchArtwork).last)
          .colorAmount,
      1,
    );
    final route = ModalRoute.of(
      tester.element(find.byType(FederalBranchesScreen)),
    )!;
    expect(route.transitionDuration, Duration.zero);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [320.0, 430.0]) {
    testWidgets('glass branch options navigate at $width', (tester) async {
      tester.view.physicalSize = Size(width, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.tap(find.text('Federal Branches'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Executive Branch'));
      await tester.pumpAndSettle();
      expect(find.byType(PresidentDetailScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
