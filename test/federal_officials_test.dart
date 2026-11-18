import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/data/federal_officials.dart';
import 'package:usa_map_app/screens/federal_officials_screen.dart';

void main() {
  late Map<String, dynamic> data;
  late List<FederalSource> sources;
  FederalSnapshot snapshot() =>
      FederalSnapshot.decode(jsonEncode(data), sources);
  setUp(() {
    data = jsonDecode(
      File('scripts/tests/fixtures/federal_transition.json').readAsStringSync(),
    );
    final registry = jsonDecode(
      File('scripts/data/federal_sources.json').readAsStringSync(),
    );
    sources = (registry['sources'] as List)
        .map((x) => FederalSource.fromJson(x))
        .toList();
    sources.add(
      FederalSource.fromJson({
        'id': 'test-election',
        'name': 'Fixture election office',
        'url': 'https://elections.example.gov/certified',
        'hosts': ['elections.example.gov'],
        'claims': ['certification'],
        'officeKinds': ['house'],
        'states': ['CA'],
      }),
    );
  });
  test('incoming appears only after certification in final 90 days', () {
    data['terms'][1]['certifiedAt'] = '2026-06-01T17:00:00Z';
    final s = snapshot();
    expect(
      s.view('us:house:CA01', DateTime.parse('2026-10-05T16:59:59Z')).incoming,
      isNull,
    );
    expect(
      s.view('us:house:CA01', DateTime.parse('2026-10-05T17:00:00Z')).incoming,
      isNotNull,
    );
    data['terms'][1]['certifiedAt'] = '2026-11-10T17:00:00Z';
    expect(
      snapshot()
          .view('us:house:CA01', DateTime.parse('2026-11-10T16:59:59Z'))
          .incoming,
      isNull,
    );
    expect(
      snapshot()
          .view('us:house:CA01', DateTime.parse('2026-11-10T17:00:00Z'))
          .incoming,
      isNotNull,
    );
  });
  test(
    'offline clock cannot promote; outgoing expires at exact federal noon',
    () {
      final s = snapshot();
      expect(
        s
            .view('us:house:CA01', DateTime.parse('2027-01-03T16:59:59Z'))
            .current
            ?.personId,
        'current',
      );
      final boundary = s.view(
        'us:house:CA01',
        DateTime.parse('2027-01-03T17:00:00Z'),
      );
      expect(boundary.current, isNull);
      expect(boundary.awaitingVerification, isTrue);
      expect(boundary.incoming?.personId, 'next');
    },
  );
  test('incoming disappears seven days after expected start', () {
    final s = snapshot();
    expect(
      s.view('us:house:CA01', DateTime.parse('2027-01-10T16:59:59Z')).incoming,
      isNotNull,
    );
    final v = s.view('us:house:CA01', DateTime.parse('2027-01-10T17:00:00Z'));
    expect(v.incoming, isNull);
    expect(v.awaitingVerification, isTrue);
  });
  test('disputed and withdrawn records do not create incoming cards', () {
    for (final status in ['disputed', 'withdrawn']) {
      data['terms'][1]['status'] = status;
      expect(
        snapshot()
            .view('us:house:CA01', DateTime.parse('2026-11-18T17:00:00Z'))
            .incoming,
        isNull,
      );
    }
  });
  test('same-person next term is reelected', () {
    data['terms'][1]['personId'] = 'current';
    for (final e in data['evidence']) {
      e['personId'] = 'current';
    }
    expect(
      snapshot()
          .view('us:house:CA01', DateTime.parse('2026-11-18T17:00:00Z'))
          .reelected,
      isTrue,
    );
  });
  test(
    'rejects uncertified, duplicate, cross-office and untrusted evidence',
    () {
      for (final change in [
        'certification',
        'duplicate',
        'identity',
        'domain',
        'jurisdiction',
      ]) {
        final changed = jsonDecode(jsonEncode(data));
        if (change == 'certification')
          changed['terms'][1]['evidenceIds'] = ['start-proof'];
        if (change == 'duplicate')
          changed['terms'].add({...changed['terms'][0], 'id': 'duplicate'});
        if (change == 'identity')
          changed['evidence'][2]['personId'] = 'current';
        if (change == 'domain')
          changed['evidence'][2]['url'] =
              'https://elections.example.gov.attacker.com/';
        if (change == 'jurisdiction') changed['offices'][0]['state'] = 'NY';
        expect(
          () => FederalSnapshot.decode(jsonEncode(changed), sources),
          throwsFormatException,
          reason: change,
        );
      }
    },
  );
  test('shipped government snapshot passes local authority validation', () {
    final realSources =
        (jsonDecode(
                  File('assets/data/federal_sources.json').readAsStringSync(),
                )['sources']
                as List)
            .map((x) => FederalSource.fromJson(x))
            .toList();
    final s = FederalSnapshot.decode(
      File('assets/data/federal_officials.json').readAsStringSync(),
      realSources,
    );
    expect(s.offices.length, greaterThan(500));
  });
  testWidgets('one primary profile and a compact text-only successor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FederalOfficialProfileScreen(
          officeId: 'us:house:CA01',
          initialSnapshot: snapshot(),
          clock: () => DateTime.parse('2026-11-18T17:00:00Z'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Current Official'), findsOneWidget);
    expect(find.text('Incoming Official'), findsOneWidget);
    final card = find.byKey(const Key('federal_transition_notice'));
    expect(
      find.descendant(of: card, matching: find.byType(Image)),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.byType(CircleAvatar)),
      findsNothing,
    );
    expect(tester.getSize(card).height, lessThan(160));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('no incoming or transition space during ordinary term', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FederalOfficialProfileScreen(
          officeId: 'us:house:CA01',
          initialSnapshot: snapshot(),
          clock: () => DateTime.parse('2026-08-01T17:00:00Z'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Incoming Official'), findsNothing);
    expect(find.byKey(const Key('federal_transition_notice')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('long incoming name fits narrow screens with larger text', (
    tester,
  ) async {
    data['people'][1]['name'] =
        'Incoming Official With A Very Long Public Name';
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: FederalOfficialProfileScreen(
            officeId: 'us:house:CA01',
            initialSnapshot: snapshot(),
            clock: () => DateTime.parse('2026-11-18T17:00:00Z'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
