import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/data/federal_officials.dart';
import 'package:usa_map_app/data/models.dart';
import 'package:usa_map_app/screens/lawmaker_detail_screen.dart';
import 'package:usa_map_app/services/federal_officials_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FederalOfficialsService service;
  late FederalSnapshot? original;
  final now = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
  String stamp(DateTime value) => value.toIso8601String();
  const legacyName = 'Fixture Serving Governor';
  const successorName = 'Fixture Verified Successor';
  final legacy = Governor(
    name: legacyName,
    photoLocalPath: 'governors/fixture-predecessor.jpg',
    phone: '601-555-0100',
  );

  FederalSnapshot release({
    bool serving = false,
    bool expired = false,
    DateTime? expectedStart,
    String? civilStartDate,
  }) {
    final start = expectedStart ?? now.subtract(const Duration(days: 1));
    final source = FederalSource.fromJson({
      'id': 'fixture-governor',
      'name': 'Fixture government office',
      'url': 'https://governor.example.gov/official',
      'hosts': ['governor.example.gov'],
      'officeKinds': ['governor'],
      'states': ['MS'],
      'claims': [
        'certification',
        'scheduledStart',
        'scheduledEnd',
        'assumedOffice',
      ],
    });
    Map<String, dynamic> proof(String id, String claim) => {
      'id': id,
      'sourceId': source.id,
      'url': source.url,
      'officeId': 'us:state:MS:governor',
      'personId': 'fixture-successor',
      'claim': claim,
      'sha256': List.filled(64, 'a').join(),
      'retrievedAt': stamp(now),
    };
    return FederalSnapshot.decode(
      jsonEncode({
        'schemaVersion': 1,
        'publishedAt': stamp(now),
        'offices': [
          {
            'id': 'us:state:MS:governor',
            'kind': 'governor',
            'branch': 'executive',
            'state': 'MS',
            'title': 'Governor',
          },
        ],
        'people': [
          {
            'id': 'fixture-successor',
            'name': successorName,
            'party': 'Independent',
            'photoLocalPath': 'governors/fixture-successor.jpg',
          },
        ],
        'terms': [
          {
            'id': 'fixture-term',
            'officeId': 'us:state:MS:governor',
            'personId': 'fixture-successor',
            'status': serving ? 'current' : 'incoming',
            'certifiedAt': stamp(now.subtract(const Duration(days: 2))),
            if (civilStartDate == null) 'scheduledStart': stamp(start),
            if (civilStartDate != null) ...{
              'scheduledStartDate': civilStartDate,
              'startTimeZone': 'America/Denver',
            },
            if (serving) 'actualStart': stamp(start),
            if (expired)
              'scheduledEnd': stamp(now.subtract(const Duration(hours: 12))),
            'evidenceIds': [
              'cert',
              'start',
              if (serving) 'service',
              if (expired) 'end',
            ],
            'contact': {
              'phone': '601-555-0199',
              'address': 'Fixture official office',
              'website': source.url,
            },
          },
        ],
        'evidence': [
          proof('cert', 'certification'),
          proof('start', 'scheduledStart'),
          if (serving) proof('service', 'assumedOffice'),
          if (expired) proof('end', 'scheduledEnd'),
        ],
      }),
      [source],
    );
  }

  setUpAll(() async {
    service = FederalOfficialsService.instance;
    await service.load();
    original = service.snapshot;
  });
  tearDown(() => service.snapshot = original);
  tearDownAll(() => service.dispose());

  test('incoming-only governor preserves legacy serving record in lists', () {
    final provider = MapDataProvider()..governors = {'MS': legacy};
    provider.applyOfficialSnapshot(
      release(expectedStart: now.add(const Duration(days: 1))),
      asOf: now,
    );
    expect(provider.governors!['MS'], same(legacy));
    expect(provider.governors!['MS']!.name, isNot(successorName));
    provider.dispose();
  });

  test(
    'confirmed handoff projects successor contact and portrait into lists',
    () {
      final provider = MapDataProvider()
        ..governors = {
          'MS': legacy,
          'CA': Governor(name: 'Other serving governor'),
        };
      provider.applyOfficialSnapshot(release(serving: true), asOf: now);
      final governor = provider.governors!['MS']!;
      expect(governor.name, successorName);
      expect(governor.party, 'Independent');
      expect(governor.photoLocalPath, 'governors/fixture-successor.jpg');
      expect(governor.phone, '601-555-0199');
      expect(governor.address, 'Fixture official office');
      expect(governor.website, 'https://governor.example.gov/official');
      expect(governor.sourceUrl, 'https://governor.example.gov/official');
      expect(provider.governors!['CA']!.name, 'Other serving governor');
      provider.dispose();
    },
  );

  test('expired verified governor cannot resurrect a legacy predecessor', () {
    final provider = MapDataProvider()..governors = {'MS': legacy};
    provider.applyOfficialSnapshot(
      release(serving: true, expired: true),
      asOf: now,
    );
    expect(provider.governors!.containsKey('MS'), isFalse);
    provider.dispose();
  });

  testWidgets(
    'open governor profile follows a verified handoff and hides old identity',
    (tester) async {
      service.snapshot = release(
        expectedStart: now.add(const Duration(days: 1)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LawmakerDetailScreen(
            lawmaker: legacy,
            role: 'Governor',
            stateId: 'MS',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(legacyName), findsOneWidget);
      expect(
        find.byKey(const Key('federal_transition_notice')),
        findsOneWidget,
      );

      service.snapshot = release(serving: true);
      // Simulate publication notification from the service without networking.
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      service.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text(successorName), findsOneWidget);
      expect(find.text(legacyName), findsNothing);
      expect(find.text('Serving now'), findsOneWidget);
      expect(find.byKey(const Key('federal_transition_notice')), findsNothing);
      expect(find.text('601-555-0100'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('expired tracked governor profile shows a verification gap', (
    tester,
  ) async {
    service.snapshot = release(serving: true, expired: true);
    await tester.pumpWidget(
      MaterialApp(
        home: LawmakerDetailScreen(
          lawmaker: legacy,
          role: 'Governor',
          stateId: 'MS',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(legacyName), findsNothing);
    expect(find.text(successorName), findsNothing);
    expect(
      find.text('No current occupant verified in this snapshot.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('past verified incoming start suppresses legacy serving governor', () {
    final provider = MapDataProvider()..governors = {'MS': legacy};
    final snapshot = release();
    expect(snapshot.view('us:state:MS:governor', now).current, isNull);
    provider.applyOfficialSnapshot(snapshot, asOf: now);
    expect(provider.governors!.containsKey('MS'), isFalse);
    provider.dispose();
  });

  test('expired incoming notice cannot restore legacy governor in lists', () {
    final provider = MapDataProvider()..governors = {'MS': legacy};
    final snapshot = release(
      expectedStart: now.subtract(const Duration(days: 8)),
    );
    final view = snapshot.view('us:state:MS:governor', now);
    expect(view.current, isNull);
    expect(view.incoming, isNull);
    expect(view.awaitingVerification, isTrue);
    provider.applyOfficialSnapshot(snapshot, asOf: now);
    expect(provider.governors!.containsKey('MS'), isFalse);
    provider.dispose();
  });

  test(
    'civil incoming start preserves legacy until the entire legal day passes',
    () {
      final day = DateTime.utc(now.year, now.month, now.day);
      final snapshot = release(
        civilStartDate: day.toIso8601String().substring(0, 10),
      );
      final provider = MapDataProvider()..governors = {'MS': legacy};
      provider.applyOfficialSnapshot(
        snapshot,
        asOf: day.add(const Duration(days: 1, hours: 13, minutes: 59)),
      );
      expect(provider.governors!['MS'], same(legacy));
      provider.applyOfficialSnapshot(
        snapshot,
        asOf: day.add(const Duration(days: 1, hours: 14)),
      );
      expect(provider.governors!.containsKey('MS'), isFalse);
      expect(
        snapshot
            .view(
              'us:state:MS:governor',
              day.add(const Duration(days: 1, hours: 14)),
            )
            .current,
        isNull,
      );
      provider.dispose();
    },
  );

  testWidgets(
    'expired incoming notice leaves a verification gap instead of a legacy profile',
    (tester) async {
      service.snapshot = release(
        expectedStart: now.subtract(const Duration(days: 8)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LawmakerDetailScreen(
            lawmaker: legacy,
            role: 'Governor',
            stateId: 'MS',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(legacyName), findsNothing);
      expect(find.text(successorName), findsNothing);
      expect(
        find.text('No current occupant verified in this snapshot.'),
        findsOneWidget,
      );
      expect(
        find.text('Official confirmation of service is still pending.'),
        findsOneWidget,
      );
      expect(find.text('601-555-0100'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
