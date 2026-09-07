import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/data/models.dart';
import 'package:usa_map_app/data/civic_data_provider.dart';
import 'package:usa_map_app/utils/search_handler.dart';
import 'package:usa_map_app/screens/local_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Upcoming Elections & Ballot Prioritization Tests', () {
    test('CivicDataProvider loads election records, candidates, and propositions', () async {
      final civicProvider = CivicDataProvider();
      await civicProvider.loadData();

      // Election info for CA
      final caElection = civicProvider.getElectionForState('CA');
      expect(caElection.stateId, 'CA');
      expect(caElection.nextElectionDate, contains('November 3, 2026'));
      expect(caElection.voterRegistrationDeadline, isNotEmpty);
      expect(caElection.earlyVotingStart, isNotEmpty);

      // Candidates for CA
      final caCandidates = civicProvider.getCandidatesForJurisdiction('CA');
      expect(caCandidates.isNotEmpty, isTrue);
      expect(caCandidates.any((c) => c.name == 'Alex Padilla'), isTrue);
      expect(caCandidates.any((c) => c.office.contains('Senator')), isTrue);
      expect(caCandidates.first.platform, isNotEmpty);

      // Propositions for CA
      final caProps = civicProvider.getPropositionsForJurisdiction('CA');
      expect(caProps.isNotEmpty, isTrue);
      expect(caProps.any((p) => p.code == 'Proposition 1'), isTrue);
      expect(caProps.first.yesVoteMeaning, isNotEmpty);
      expect(caProps.first.noVoteMeaning, isNotEmpty);
      expect(caProps.first.fiscalSummary, isNotEmpty);

      // Re-election timeline checks
      final govTimeline = civicProvider.getIncumbentReelectionTimeline('Governor', 'CA');
      expect(govTimeline, contains('2026'));

      final senTimeline = civicProvider.getIncumbentReelectionTimeline('Senator', 'CA');
      expect(senTimeline, contains('2026'));

      final houseTimeline = civicProvider.getIncumbentReelectionTimeline('Representative', 'CA');
      expect(houseTimeline, contains('2026'));
    });

    test('SearchHandler includes elections & ballot query matching', () async {
      final handler = SearchHandler();
      await handler.loadData();
      final provider = MapDataProvider();

      final results = await handler.search('elections', provider);
      expect(results.isNotEmpty, isTrue);
      expect(results.any((r) => r.title.contains('Upcoming 2026 Elections')), isTrue);

      final ballotResults = await handler.search('ballot', provider);
      expect(ballotResults.isNotEmpty, isTrue);
      expect(ballotResults.any((r) => r.title.contains('Upcoming 2026 Elections')), isTrue);
    });

    testWidgets('LocalDetailScreen prioritizes Upcoming Election banner, Candidates, and Propositions', (tester) async {
      final civicProvider = CivicDataProvider();
      await civicProvider.loadData();

      final searchResult = SearchResult(
        type: SearchResultType.zipCode,
        title: '90210 — Beverly Hills, CA',
        subtitle: 'Your Representatives in Beverly Hills, CA',
        cityName: 'Beverly Hills',
        stateId: 'CA',
        countyName: 'Los Angeles',
      );

      final mapProvider = MapDataProvider();
      mapProvider.governors = {
        'CA': Governor(name: 'Gavin Newsom', party: 'Democratic'),
      };
      mapProvider.senators = {
        'CA': [Senator(name: 'Alex Padilla', party: 'Democratic')],
      };

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: mapProvider,
          child: MaterialApp(
            home: LocalDetailScreen(searchResult: searchResult),
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 1. Verify upcoming election banner is prominently displayed at top
      expect(find.text('UPCOMING ELECTION'), findsOneWidget);
      expect(find.text('2026 California Statewide General Election'), findsOneWidget);
      expect(find.textContaining('Registration Deadline'), findsOneWidget);

      // 2. Verify Section tabs exist
      expect(find.text('On Your Ballot'), findsOneWidget);
      expect(find.text('Bills & Laws'), findsOneWidget);
      expect(find.text('Current Reps'), findsOneWidget);
      expect(find.text('Voter Guide'), findsOneWidget);

      // 3. Verify Default Tab is "On Your Ballot" and shows candidates & propositions
      expect(find.text('Electoral Candidates'), findsOneWidget);
      expect(find.text('Alex Padilla'), findsOneWidget);
      expect(find.text('Propositions & Ballot Measures'), findsOneWidget);
      expect(find.text('Proposition 1'), findsOneWidget);
      expect(find.text('WHAT A YES VOTE MEANS'), findsWidgets);
      expect(find.text('WHAT A NO VOTE MEANS'), findsWidgets);

      // 4. Switch to "Current Reps" tab
      await tester.tap(find.text('Current Reps'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Your Current Elected Officials'), findsOneWidget);
      expect(find.textContaining('4-Year Term • Up for Re-Election: Nov 3, 2026'), findsWidgets);

      // 5. Switch to "Voter Guide" tab
      await tester.tap(find.text('Voter Guide'));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.textContaining('Voter Guide & Key Deadlines'), findsOneWidget);
      expect(find.text('Voter ID Requirements'), findsOneWidget);
      expect(find.text('View State Voter ID Rules'), findsOneWidget);
    });
  });
}
