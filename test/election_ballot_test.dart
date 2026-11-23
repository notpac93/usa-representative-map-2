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

  group('Recorded Elections & Ballot Lifecycle Tests', () {
    test(
      'CivicDataProvider loads recorded dates without unverified ballot data',
      () async {
        final civicProvider = CivicDataProvider();
        await civicProvider.loadData();

        // Election info for CA
        final caElection = civicProvider.getElectionForState('CA');
        expect(caElection.stateId, 'CA');
        expect(caElection.recordedElectionDate, isNotNull);
        // Loading a past calendar does not manufacture another election cycle.
        expect(
          caElection.statusLabelOn(DateTime(2026, 11, 19)),
          'Election held',
        );

        // Unverified candidate and proposition examples are excluded from the
        // active asset. Missing records cannot trigger synthetic fallbacks.
        final caCandidates = civicProvider.getCandidatesForJurisdiction('CA');
        expect(caCandidates, isEmpty);

        // Propositions for CA
        final caProps = civicProvider.getPropositionsForJurisdiction('CA');
        expect(caProps, isEmpty);
        for (final state in ['MS', 'WY', 'ZZ', 'US']) {
          expect(civicProvider.getCandidatesForJurisdiction(state), isEmpty);
          expect(civicProvider.getPropositionsForJurisdiction(state), isEmpty);
        }

        // Re-election timeline checks
        final govTimeline = civicProvider.getIncumbentReelectionTimeline(
          'Governor',
          'CA',
        );
        expect(govTimeline, contains('Next election date not verified'));
        expect(govTimeline, isNot(contains('Up for Re-Election')));

        final senTimeline = civicProvider.getIncumbentReelectionTimeline(
          'Senator',
          'CA',
        );
        expect(senTimeline, contains('Next election date not verified'));

        final houseTimeline = civicProvider.getIncumbentReelectionTimeline(
          'Representative',
          'CA',
        );
        expect(houseTimeline, contains('Next election date not verified'));
      },
    );

    test('SearchHandler includes elections & ballot query matching', () async {
      final handler = SearchHandler();
      await handler.loadData();
      final provider = MapDataProvider();

      final results = await handler.search('elections', provider);
      expect(results.isNotEmpty, isTrue);
      expect(
        results.any((r) => r.title == 'Elections & Ballot Records'),
        isTrue,
      );

      final ballotResults = await handler.search('ballot', provider);
      expect(ballotResults.isNotEmpty, isTrue);
      expect(
        ballotResults.any((r) => r.title == 'Elections & Ballot Records'),
        isTrue,
      );
    });

    testWidgets(
      'LocalDetailScreen separates recorded ballots and completed voting deadlines',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final civicProvider = CivicDataProvider();
        await tester.runAsync(civicProvider.loadData);

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

        // Representatives come first; elections are a separate destination.
        expect(find.text('Alex Padilla'), findsOneWidget);
        await tester.tap(find.text('Explore this area'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elections'));
        await tester.pumpAndSettle();
        final election = civicProvider.getElectionForState('CA');
        expect(
          find.text('${election.nextElectionDate} • ${election.electionType}'),
          findsOneWidget,
        );
        expect(find.text('Election held'), findsOneWidget);
        expect(find.text('Certification status not verified'), findsOneWidget);
        expect(find.textContaining('Reg. Deadline:'), findsNothing);
        expect(find.text('Upcoming election'), findsNothing);

        await tester.tap(find.text('Ballot records'));
        await tester.pumpAndSettle();
        expect(find.text('Electoral Candidates'), findsOneWidget);
        expect(
          find.text('Recorded candidates · not certified results'),
          findsOneWidget,
        );
        expect(find.text('Alex Padilla'), findsNothing);
        expect(find.text('Propositions & Ballot Measures'), findsOneWidget);
        expect(find.text('Proposition 1'), findsNothing);
        expect(find.text('WHAT A YES VOTE MEANS'), findsNothing);
        expect(find.text('WHAT A NO VOTE MEANS'), findsNothing);

        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Voting guide'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Election information:'), findsOneWidget);
        expect(find.text('Voter Registration Deadline'), findsNothing);
        expect(find.text('Vote By Mail & Absentee Voting'), findsNothing);
        expect(find.text('Find Your Polling Location'), findsNothing);
        expect(
          find.textContaining('Past deadlines are not valid instructions'),
          findsOneWidget,
        );
      },
    );
  });
}
