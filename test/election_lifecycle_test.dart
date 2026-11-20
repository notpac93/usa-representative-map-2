import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/data/bill_models.dart';
import 'package:usa_map_app/data/civic_data_provider.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/utils/search_handler.dart';
import 'package:usa_map_app/widgets/election_status_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ElectionRecord record({
    String date = 'November 3, 2026',
    String? iso,
    String status = 'unknown',
  }) => ElectionRecord.fromJson({
    'stateId': 'MS',
    'stateName': 'Mississippi',
    'nextElectionDate': date,
    'electionType': 'Recorded general election',
    'electionDateIso': iso,
    'certificationStatus': status,
    'voterRegistrationDeadline': 'October 5, 2026',
    'earlyVotingStart': 'October 15, 2026',
  });
  test('past election is held without implying a certified winner', () {
    final election = record();
    expect(election.phaseOn(DateTime(2026, 11, 19)), ElectionPhase.held);
    expect(election.statusLabelOn(DateTime(2026, 11, 19)), 'Election held');
    expect(election.resultsStatusLabel, 'Certification status not verified');
  });
  test('election day remains distinct from before and after voting date', () {
    final election = record(iso: '2026-11-03');
    expect(
      election.phaseOn(DateTime(2026, 11, 2, 23, 59)),
      ElectionPhase.upcoming,
    );
    expect(
      election.phaseOn(DateTime(2026, 11, 3, 23, 59)),
      ElectionPhase.electionDay,
    );
    expect(election.phaseOn(DateTime(2026, 11, 4)), ElectionPhase.held);
  });
  test(
    'calendar selection uses the nearest future record or latest historical record',
    () {
      final past = record(iso: '2026-11-03');
      final future = record(iso: '2027-11-02');
      final later = record(iso: '2028-11-07');
      expect(
        ElectionRecord.selectForState(
          [past, later, future],
          'ms',
          DateTime(2026, 11, 19),
        ),
        same(future),
      );
      expect(
        ElectionRecord.selectForState(
          [past, later, future],
          'MS',
          DateTime(2029, 1, 1),
        ),
        same(later),
      );
      expect(
        ElectionRecord.selectForState([past], 'CA', DateTime(2026, 11, 19)),
        isNull,
      );
    },
  );
  test('missing, invalid, and ambiguous dates are never guessed', () {
    for (final value in ['', 'Spring 2026', 'November 31, 2026']) {
      expect(
        record(date: value).phaseOn(DateTime(2026, 11, 19)),
        ElectionPhase.undated,
      );
    }
    expect(record(iso: '2026-11-31').recordedElectionDate, isNull);
    expect(record(iso: '2026-11-03T17:00:00Z').recordedElectionDate, isNull);
    expect(ElectionRecord.fromJson({}).nextElectionDate, isEmpty);
    expect(ElectionRecord.fromJson({}).voterRegistrationDeadline, isEmpty);
  });
  test(
    'certification and unofficial results remain separate from date lifecycle',
    () {
      expect(
        record(status: 'unofficial').resultsStatusLabel,
        'Unofficial results · certification pending',
      );
      expect(
        record(status: 'certified').resultsStatusLabel,
        'Certified results recorded',
      );
      expect(
        record(status: 'projected').resultsStatusLabel,
        'Certification status not verified',
      );
    },
  );
  test('unknown state calendar does not inherit national deadlines', () async {
    final provider = CivicDataProvider();
    await provider.loadData();
    final unknown = provider.getElectionForState('ZZ');
    expect(unknown.recordedElectionDate, isNull);
    expect(unknown.voterRegistrationDeadline, isEmpty);
    expect(unknown.earlyVotingStart, isEmpty);
    expect(unknown.pollsOpenHours, isEmpty);
  });
  test(
    'all fifty states have sourced federal dates and no invented ballot details',
    () async {
      final source =
          jsonDecode(await rootBundle.loadString('assets/data/elections.json'))
              as Map<String, dynamic>;
      final entries = (source['elections'] as List)
          .cast<Map<String, dynamic>>();
      final expected =
          'US AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY'
              .split(' ');
      expect(entries, hasLength(51));
      expect(entries.map((e) => e['stateId']).toSet(), expected.toSet());
      expect(source['candidates'], isEmpty);
      expect(source['propositions'], isEmpty);
      final officialSources = (source['sources'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        officialSources.any(
          (s) =>
              s['url'] ==
              'https://www.fec.gov/introduction-campaign-finance/election-results-and-voting-information/',
        ),
        isTrue,
      );
      expect(
        officialSources.any(
          (s) => s['url'] == 'https://uscode.house.gov/us/usc/119-142/t2/s7/',
        ),
        isTrue,
      );
      final provider = CivicDataProvider();
      await provider.loadData();
      for (final entry in entries) {
        expect(entry['recordStatus'], 'recorded');
        expect(entry['scope'], 'federal_regular_general');
        expect(entry['electionDateIso'], '2026-11-03');
        expect(entry['dateSourceIds'], hasLength(2));
        final record = provider.getElectionForState(
          entry['stateId'] as String,
          asOf: DateTime(2026, 11, 19),
        );
        expect(record.recordedElectionDate, DateTime(2026, 11, 3));
        expect(record.phaseOn(DateTime(2026, 11, 19)), ElectionPhase.held);
        expect(record.certificationStatus, 'unknown');
        expect(record.electionType, 'Recorded 2026 federal general election');
        expect(record.officialPortalUrl, isNotEmpty);
        expect(record.primaryDate, isEmpty);
        expect(record.voterRegistrationDeadline, isEmpty);
        expect(record.earlyVotingStart, isEmpty);
        expect(record.earlyVotingEnd, isEmpty);
        expect(record.pollsOpenHours, isEmpty);
        expect(record.ballotTrackerUrl, isEmpty);
        expect(record.keyOfficesUp, isNot(contains('Governor')));
        expect(record.keyOfficesUp, isNot(contains('Senate')));
        expect(provider.getCandidatesForJurisdiction(record.stateId), isEmpty);
        expect(
          provider.getPropositionsForJurisdiction(record.stateId),
          isEmpty,
        );
      }
    },
  );
  test(
    'reelection descriptions never assign a passed or guessed next date',
    () {
      for (final role in ['Governor', 'Senator', 'Representative', 'Mayor']) {
        final text = CivicDataProvider().getIncumbentReelectionTimeline(
          role,
          'MS',
        );
        expect(text, contains('not verified'));
        expect(text, isNot(contains('2026')));
        expect(text, isNot(contains('2027')));
      }
    },
  );
  test(
    'election search stays useful without claiming the past election is upcoming',
    () async {
      final results = await SearchHandler().search(
        'elections',
        MapDataProvider(),
      );
      expect(
        results.any((r) => r.title == 'Elections & Ballot Records'),
        isTrue,
      );
      expect(results.any((r) => r.title.contains('Upcoming 2026')), isFalse);
    },
  );
  testWidgets(
    'held election hides expired registration and early voting instructions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElectionStatusBanner(
              election: record(),
              now: DateTime(2026, 11, 19),
            ),
          ),
        ),
      );
      expect(find.text('Election held'), findsOneWidget);
      expect(find.text('Certification status not verified'), findsOneWidget);
      expect(find.textContaining('October 5'), findsNothing);
      expect(find.textContaining('October 15'), findsNothing);
      expect(find.text('Upcoming election'), findsNothing);
    },
  );
  testWidgets(
    'unofficial and certified result labels are displayed accurately',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElectionStatusBanner(
              election: record(status: 'unofficial'),
              now: DateTime(2026, 11, 19),
            ),
          ),
        ),
      );
      expect(
        find.text('Unofficial results · certification pending'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElectionStatusBanner(
              election: record(status: 'certified'),
              now: DateTime(2026, 11, 19),
            ),
          ),
        ),
      );
      expect(find.text('Certified results recorded'), findsOneWidget);
      expect(find.textContaining('certification pending'), findsNothing);
    },
  );
  testWidgets(
    'unknown calendar gives official information without invented dates',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElectionStatusBanner(
              election: record(date: ''),
              now: DateTime(2026, 11, 19),
              onOfficialInformation: () {},
            ),
          ),
        ),
      );
      expect(find.text('Election date not verified'), findsOneWidget);
      expect(find.text('Official election information'), findsOneWidget);
      expect(find.textContaining('November 3'), findsNothing);
    },
  );
}
