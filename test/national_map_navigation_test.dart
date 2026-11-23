import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/data/models.dart';
import 'package:usa_map_app/data/static/us_house_apportionment.dart';
import 'package:usa_map_app/map/atlas_path_cache.dart';
import 'package:usa_map_app/screens/landing_screen.dart';
import 'package:usa_map_app/screens/national_map_screen.dart';
import 'package:usa_map_app/screens/state_delegation_screen.dart';
import 'package:usa_map_app/screens/state_detail_screen.dart';

class _MapFixture extends MapDataProvider {
  _MapFixture() {
    atlas = Atlas(
      width: 100,
      height: 60,
      projection: 'test',
      states: [_state('CA', 0, 40), _state('NY', 60, 90), _state('DC', 92, 95)],
    );
    pathCache = AtlasPathCache()..parseAndCache(atlas!);
    senators = {
      'CA': [Senator(name: 'California Senator')],
      'NY': [Senator(name: 'New York Senator')],
    };
    houseMembers = {
      'CA': [Representative(name: 'California Representative')],
      'NY': [Representative(name: 'New York Representative')],
      'DC': [Representative(name: 'District Delegate')],
    };
  }

  @override
  bool get isLoading => false;

  @override
  Future<void> loadAllData() async {}

  static StateRecord _state(String id, double min, double max) => StateRecord(
    id: id,
    name: id,
    fips: '',
    path: 'M$min 5 H$max V55 H$min Z',
    bbox: [min, 5, max, 55],
    centroid: [(min + max) / 2, 30],
  );
}

Future<void> _openMap(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 51, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  await tester.pumpWidget(
    ChangeNotifierProvider<MapDataProvider>(
      create: (_) => _MapFixture(),
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const map = Key('interactive-national-map');
  const stateName = Key('selected-state-name');

  testWidgets('seat buttons open only the selected state and chamber', (
    tester,
  ) async {
    await _openMap(tester);
    final senate = find.byKey(const Key('national-seats-senate'));
    final house = find.byKey(const Key('national-seats-house'));

    expect(
      find.descendant(of: senate, matching: find.text('2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: house, matching: find.text('52')),
      findsOneWidget,
    );

    await tester.tap(senate);
    await tester.pumpAndSettle();
    expect(find.text('California Senator'), findsOneWidget);
    expect(find.text('New York Senator'), findsNothing);
    expect(find.text('California Representative'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(house);
    await tester.pumpAndSettle();
    expect(find.text('California Representative'), findsOneWidget);
    expect(find.text('New York Representative'), findsNothing);
    expect(find.text('California Senator'), findsNothing);
  });

  testWidgets('selecting a state twice on the map opens its state page', (
    tester,
  ) async {
    await _openMap(tester);
    final bounds = tester.getRect(find.byKey(map));
    final newYork = Offset(bounds.left + bounds.width * .75, bounds.center.dy);

    await tester.tapAt(newYork);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'New York'), findsOneWidget);
    expect(find.byType(StateDetailScreen), findsNothing);

    await tester.tapAt(newYork);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      tester.widget<StateDetailScreen>(find.byType(StateDetailScreen)).stateId,
      'NY',
    );
  });

  testWidgets('state name opens the state page and D.C. opens its delegate', (
    tester,
  ) async {
    await _openMap(tester);
    await tester.tap(find.byKey(const Key('national-state-DC')));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(ListTile, 'District of Columbia'),
      findsOneWidget,
    );
    expect(find.text('Nonvoting House delegate'), findsOneWidget);

    await tester.tap(find.byKey(const Key('national-seats-house')));
    await tester.pumpAndSettle();
    expect(find.text('District Delegate'), findsOneWidget);
    expect(find.byType(StateDelegationScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(stateName));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      tester.widget<StateDetailScreen>(find.byType(StateDetailScreen)).stateId,
      'DC',
    );
  });

  for (final (width, label) in [(393.0, 'US States'), (1200.0, 'US States')]) {
    testWidgets('$label opens the shared national map', (tester) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<MapDataProvider>(
          create: (_) => _MapFixture(),
          child: const MaterialApp(home: LandingScreen()),
        ),
      );
      await tester.pump();
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byKey(map), findsOneWidget);
    });
  }

  test('House apportionment covers all 50 states and 435 voting seats', () {
    expect(usHouseApportionment, hasLength(50));
    expect(usHouseApportionment.values.reduce((a, b) => a + b), 435);
    expect(usHouseApportionment.containsKey('DC'), isFalse);
  });
}
