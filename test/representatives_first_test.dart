import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/data/congressional_roster.dart';
import 'package:usa_map_app/data/civic_data_provider.dart';
import 'package:usa_map_app/data/models.dart';
import 'package:usa_map_app/screens/find_reps_screen.dart';
import 'package:usa_map_app/screens/local_detail_screen.dart';
import 'package:usa_map_app/screens/house_district_screen.dart';
import 'package:usa_map_app/screens/lawmaker_detail_screen.dart';
import 'package:usa_map_app/services/congressional_district_service.dart';
import 'package:usa_map_app/utils/search_handler.dart';
import 'package:usa_map_app/widgets/official_list_tile.dart';

class _Provider extends MapDataProvider {
  @override
  bool get isLoading => false;
  @override
  Future<void> loadAllData() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CongressionalRoster roster;
  setUpAll(() async {
    roster = await CongressionalRoster.load();
    await CivicDataProvider().loadData();
    await SearchHandler().loadData();
  });
  _Provider provider() => _Provider()
    ..congressionalRoster = roster
    ..senators = roster.senators
    ..houseMembers = roster.houseMembers;
  SearchResult location() => SearchResult(
    type: SearchResultType.zipCode,
    title: '92688 — Rancho Santa Margarita, CA',
    subtitle: '',
    stateId: 'CA',
    cityName: 'Rancho Santa Margarita',
  );
  Widget app(Widget home, {_Provider? data}) =>
      ChangeNotifierProvider<MapDataProvider>.value(
        value: data ?? provider(),
        child: MaterialApp(home: home),
      );

  for (final width in [320.0, 430.0]) {
    testWidgets('ZIP search leads to focused representatives at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(const FindRepsScreen()));
      await tester.enterText(find.byType(TextField), '92688');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('92688 — Rancho Santa Margarita, CA'));
      await tester.pumpAndSettle();
      expect(find.byType(OfficialListTile), findsNWidgets(2));
      expect(find.text('Your representatives'), findsOneWidget);
      expect(find.text('Contact Congress'), findsNothing);
      expect(find.text('Direct Message'), findsNothing);
      expect(find.text('Elections'), findsNothing);
      expect(find.text('Your House district'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(OfficialListTile).first);
      await tester.pumpAndSettle();
      expect(find.byType(LawmakerDetailScreen), findsOneWidget);
      expect(find.text('Direct Message'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(LocalDetailScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Explore this area'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(LocalDetailScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Explore this area'));
      await tester.pumpAndSettle();
      expect(find.text('Elections'), findsOneWidget);
      expect(find.byType(OfficialListTile), findsNothing);
      await tester.tap(find.text('Elections'));
      await tester.pumpAndSettle();
      expect(find.text('Your House district'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Voting guide'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'only an explicitly at-large House member appears without an address',
    (tester) async {
      final data = provider()
        ..houseMembers = {
          'CA': [Representative(name: 'District member', districtNumber: 7)],
        };
      await tester.pumpWidget(
        app(LocalDetailScreen(searchResult: location()), data: data),
      );
      await tester.pumpAndSettle();
      expect(find.text('District member'), findsNothing);
      expect(find.text('Your House district'), findsOneWidget);
      data.houseMembers = {
        'CA': [Representative(name: 'At large', districtNumber: 0)],
      };
      data.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('At large'), findsOneWidget);
      expect(find.text('Your House district'), findsNothing);
    },
  );

  testWidgets('address resolves only the matched House profile', (
    tester,
  ) async {
    CongressionalDistrictAddress? sent;
    await tester.pumpWidget(
      app(
        HouseDistrictScreen(
          searchResult: location(),
          lookup: (address) async {
            sent = address;
            return CongressionalDistrictLookupResult.matched(
              CongressionalDistrictMatch(
                matchedAddress: '123 Test St',
                stateAbbreviation: 'CA',
                stateFips: '06',
                districtNumber: 40,
                districtCode: '40',
                congressionalSession: roster.congress.toString(),
              ),
            );
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('house-street')),
      '123 Test St',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(sent?.zip, '92688');
    expect(find.byType(LawmakerDetailScreen), findsOneWidget);
    final profile = tester.widget<LawmakerDetailScreen>(
      find.byType(LawmakerDetailScreen),
    );
    expect((profile.lawmaker as Representative).districtNumber, 40);
  });

  for (final outcome in [
    'ambiguous',
    'wrong-state',
    'old-congress',
    'vacant',
    'error',
  ]) {
    testWidgets('$outcome address lookup never opens a profile', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          HouseDistrictScreen(
            searchResult: location(),
            lookup: (_) async {
              if (outcome == 'error') throw Exception('unavailable');
              if (outcome == 'ambiguous') {
                return const CongressionalDistrictLookupResult.ambiguous();
              }
              return CongressionalDistrictLookupResult.matched(
                CongressionalDistrictMatch(
                  matchedAddress: '123 Test St',
                  stateAbbreviation: outcome == 'wrong-state' ? 'TX' : 'CA',
                  stateFips: '06',
                  districtNumber: outcome == 'vacant' ? 99 : 40,
                  districtCode: '40',
                  congressionalSession: outcome == 'old-congress'
                      ? '118'
                      : roster.congress.toString(),
                ),
              );
            },
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('house-street')),
        '123 Test St',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(LawmakerDetailScreen), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
