import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/data/models.dart';
import 'package:usa_map_app/map/atlas_path_cache.dart';
import 'package:usa_map_app/screens/civic_profile_screen.dart';
import 'package:usa_map_app/screens/lawmaker_detail_screen.dart';
import 'package:usa_map_app/screens/state_detail_screen.dart';

void main() {
  setUp(() => rootBundle.clear());

  final governor = Governor.fromJson({
    'sourceUrl': 'https://example.gov/record',
    'scrapedAt': '2025-12-27T00:00:00Z',
    'governor': {
      'name': 'Test Governor',
      'party': 'Independent',
      'terms': ['2023–2027'],
      'about': ['Recorded biography.'],
      'contact': {'phone': '555-0100', 'address': 'Public office address'},
      'links': [
        {'label': "Governor's Website", 'url': 'https://example.gov'},
      ],
    },
  });

  Future<void> pump(WidgetTester tester, Widget widget) => tester.pumpWidget(
    DefaultAssetBundle(bundle: _ProfileAssets(), child: widget),
  );

  Future<void> tab(WidgetTester tester, String name) async {
    final target = find.byKey(ValueKey('profile_tab_$name'));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  test('Governor retains source lineage and contact website', () {
    expect(governor.website, 'https://example.gov');
    expect(governor.sourceUrl, 'https://example.gov/record');
    expect(governor.retrievedAt, '2025-12-27T00:00:00Z');
    expect(governor.biography, ['Recorded biography.']);
    expect(Governor.fromJson({'name': 'Minimal'}).website, isNull);
  });

  testWidgets('Governor entry opens the approved profile and all sections', (
    tester,
  ) async {
    await pump(
      tester,
      MaterialApp(
        home: LawmakerDetailScreen(
          lawmaker: governor,
          role: 'Governor',
          stateId: 'CA',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CivicProfileScreen), findsNothing);
    expect(find.byKey(const Key('leader_call_office')), findsOneWidget);
    expect(find.byKey(const Key('leader_official_website')), findsOneWidget);
    expect(find.text('Office highlights'), findsNothing);
    await tester.tap(find.byKey(const Key('leader_details_button')));
    await tester.pumpAndSettle();
    expect(find.byType(CivicProfileScreen), findsOneWidget);
    expect(find.text('Test Governor'), findsOneWidget);
    expect(find.text('Office highlights'), findsOneWidget);
    await tab(tester, 'History');
    expect(find.text('Past governors'), findsOneWidget);
    expect(find.text('Edmund G. "Jerry" Brown'), findsOneWidget);
    await tester.tap(find.text('Edmund G. "Jerry" Brown'));
    await tester.pumpAndSettle();
    expect(find.text('Recorded service · #34'), findsOneWidget);
    expect(find.text('Recorded service · #39'), findsOneWidget);
    await tab(tester, 'Office');
    expect(find.text('2023–2027'), findsOneWidget);
    await tab(tester, 'Activity');
    expect(find.text('No activity records connected yet.'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Executive orders'));
    await tester.pumpAndSettle();
    expect(
      find.text('No executive orders records connected yet.'),
      findsOneWidget,
    );
    await tab(tester, 'Contact');
    expect(find.text('555-0100'), findsOneWidget);
    expect(find.text('Public office address'), findsOneWidget);
    await tab(tester, 'Sources');
    expect(find.text('2025-12-27'), findsOneWidget);
    expect(find.text('Original source'), findsOneWidget);
    await tab(tester, 'State');
    expect(find.textContaining('not an individual leader'), findsOneWidget);
    expect(find.text('Population · 2020–2024'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Senator opens a contact-first profile on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(
      tester,
      ChangeNotifierProvider(
        create: (_) => MapDataProvider(),
        child: MaterialApp(
          home: LawmakerDetailScreen(
            lawmaker: Senator(
              name: 'Test Senator',
              phone: '202-555-0100',
              website: 'https://example.gov',
            ),
            role: 'Senator',
            stateId: 'CA',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CivicProfileScreen), findsNothing);
    expect(find.text('202-555-0100'), findsOneWidget);
    expect(find.text('Official website'), findsOneWidget);
    expect(find.text('Direct Message'), findsOneWidget);
    expect(tester.getTopLeft(find.text('202-555-0100')).dy, lessThan(780));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Other states show saved history with separate service periods', (
    tester,
  ) async {
    await pump(
      tester,
      const MaterialApp(
        home: CivicProfileScreen(stateId: 'MN', stateName: 'Minnesota'),
      ),
    );
    await tester.pumpAndSettle();
    await tab(tester, 'History');
    expect(find.text('Past governors'), findsOneWidget);
    expect(find.text('Mark Dayton'), findsOneWidget);
    expect(
      find.textContaining('This saved archive is partial'),
      findsOneWidget,
    );
    await tester.tap(find.text('Mark Dayton'));
    await tester.pumpAndSettle();
    expect(find.text('Recorded service'), findsOneWidget);
    expect(find.text('Official source'), findsOneWidget);
    expect(find.textContaining('#null'), findsNothing);
    expect(find.text('State Library biography & records'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Rudy Perpich'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Rudy Perpich'));
    await tester.pumpAndSettle();
    expect(find.text('1976-1979'), findsOneWidget);
    expect(find.text('1983-1991'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('State entry opens leadership while maps remain optional', (
    tester,
  ) async {
    final provider = MapDataProvider()
      ..atlas = Atlas(
        width: 100,
        height: 100,
        projection: 'test',
        states: [
          StateRecord(
            id: 'CA',
            name: 'CA',
            fips: '06',
            path: '',
            bbox: [0, 0, 100, 100],
            centroid: [50, 50],
          ),
        ],
      )
      ..pathCache = AtlasPathCache()
      ..governors = {'CA': governor};
    await pump(
      tester,
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: StateDetailScreen(stateId: 'CA', showLeadership: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CivicProfileScreen), findsOneWidget);
    expect(find.text('California'), findsOneWidget);
    expect(find.byKey(const Key('profile_map_button')), findsOneWidget);
    expect(find.text('California leadership'), findsOneWidget);
    await tester.tap(find.text('How California government works'));
    await tester.pumpAndSettle();
    expect(find.text('40 members · four-year terms'), findsOneWidget);
    await tester.tap(find.text('How California government works'));
    await tester.pumpAndSettle();
    await tab(tester, 'Population');
    expect(find.text('Population · 2020–2024'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '3 years'));
    await tester.pumpAndSettle();
    expect(find.text('Population · 2022–2024'), findsOneWidget);
    await tab(tester, 'Economy');
    expect(find.text('Median income'), findsOneWidget);
    await tab(tester, 'Housing');
    expect(find.text('Homeownership'), findsOneWidget);
    await tab(tester, 'Government');
    await tester.scrollUntilVisible(
      find.text('Test Governor'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Test Governor'));
    await tester.pumpAndSettle();
    expect(find.text('Test Governor'), findsOneWidget);
    await tester.tap(find.text('Test Governor'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leader_call_office')), findsOneWidget);
    expect(find.text('Office highlights'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Narrow governor profile supports every tab and missing records',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(
        tester,
        MaterialApp(
          home: CivicProfileScreen(
            stateId: 'XX',
            stateName: 'Unknown jurisdiction',
            governorProfile: true,
            governor: Governor(name: 'A governor with a longer name'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final section in [
        'Office',
        'History',
        'Activity',
        'State',
        'Contact',
        'Sources',
        'Overview',
      ]) {
        await tab(tester, section);
        expect(tester.takeException(), isNull, reason: section);
      }
      await tab(tester, 'Contact');
      expect(find.text('Not supplied'), findsNWidgets(3));
    },
  );
  testWidgets(
    'Real state indicators render with periods and source details on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(
        tester,
        const MaterialApp(
          home: CivicProfileScreen(stateId: 'CA', stateName: 'California'),
        ),
      );
      await tester.pumpAndSettle();
      await tab(tester, 'Economy');
      expect(find.text('Unavailable'), findsNothing);
      expect(find.textContaining('BLS · '), findsOneWidget);
      expect(find.text('GDP history'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chart_selector_income')));
      await tester.pumpAndSettle();
      expect(find.text('Income history'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('chart_selector_unemployment')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unemployment history'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Median household income'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text('Median household income'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Median household income'));
      await tester.pumpAndSettle();
      expect(find.text('90% margin of error'), findsOneWidget);
      expect(find.text('U.S. Census Bureau'), findsOneWidget);
      await tab(tester, 'Housing');
      expect(find.text('Unavailable'), findsNothing);
      expect(find.text('Rent history'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chart_selector_homeValue')));
      await tester.pumpAndSettle();
      expect(find.text('Home value history'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('chart_selector_homeownership')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Homeownership history'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ProfileAssets extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
  @override
  Future<ByteData> load(String key) async => File(key).existsSync()
      ? ByteData.sublistView(File(key).readAsBytesSync())
      : rootBundle.load(key);
}
