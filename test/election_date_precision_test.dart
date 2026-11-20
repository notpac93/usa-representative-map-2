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

  void civilStart() {
    data['terms'][1].remove('scheduledStart');
    data['terms'][1]['scheduledStartDate'] = '2027-01-04';
    data['terms'][1]['startTimeZone'] = 'America/Denver';
  }

  setUp(() {
    data = jsonDecode(
      File('scripts/tests/fixtures/federal_transition.json').readAsStringSync(),
    );
    sources =
        (jsonDecode(
                  File('assets/data/federal_sources.json').readAsStringSync(),
                )['sources']
                as List)
            .map((source) => FederalSource.fromJson(source))
            .toList();
    sources.add(
      FederalSource.fromJson({
        'id': 'test-election',
        'name': 'Fixture election authority',
        'url': 'https://elections.example.gov/certified',
        'hosts': ['elections.example.gov'],
        'officeKinds': ['house'],
        'states': ['CA'],
        'claims': ['certification', 'incomingRecognition'],
      }),
    );
  });

  test('civil dates are not exposed as UTC service-start instants', () {
    civilStart();
    final term = snapshot().terms['incoming']!;
    expect(term.scheduledStartDate, '2027-01-04');
    expect(term.scheduledStart, isNull);
    expect(term.displayStart, isNull);
  });

  test('UTC midnight cannot mark an unspecified local start as overdue', () {
    civilStart();
    final s = snapshot();
    for (final when in [
      '2027-01-04T00:01:00Z', // Still January 3 in Denver.
      '2027-01-04T18:00:00Z', // The local date has begun, but time is unknown.
      '2027-01-05T13:59:59Z',
    ]) {
      final view = s.view('us:house:CA01', DateTime.parse(when));
      expect(view.awaitingVerification, isFalse, reason: when);
      expect(view.incoming, isNotNull);
      expect(view.current, isNull); // Client time never promotes the successor.
    }
    expect(
      s
          .view('us:house:CA01', DateTime.parse('2027-01-05T14:00:00Z'))
          .awaitingVerification,
      isTrue,
    );
  });

  test('civil card does not disappear while the seventh local day remains', () {
    civilStart();
    final s = snapshot();
    expect(
      s.view('us:house:CA01', DateTime.parse('2027-01-11T00:01:00Z')).incoming,
      isNotNull,
    );
    expect(
      s.view('us:house:CA01', DateTime.parse('2027-01-11T14:00:00Z')).incoming,
      isNull,
    );
  });

  test('civil window waits until the ninety-day date in every local zone', () {
    civilStart();
    data['terms'][1]['certifiedAt'] = '2026-06-01T17:00:00Z';
    final s = snapshot();
    expect(
      s.view('us:house:CA01', DateTime.parse('2026-10-06T00:01:00Z')).incoming,
      isNull,
    );
    expect(
      s.view('us:house:CA01', DateTime.parse('2026-10-06T14:00:00Z')).incoming,
      isNotNull,
    );
  });

  test('an instant cannot mask an invalid or conflicting civil start', () {
    for (final civil in ['2027-02-31', '2027-01-04', '2027-01-03']) {
      data['terms'][1]['scheduledStartDate'] = civil;
      expect(snapshot, throwsFormatException, reason: civil);
    }
  });

  test('recognized certification needs a nonfuture verification timestamp', () {
    data['terms'][1]['status'] = 'incomingRecognized';
    data['terms'][1]['recognizedAt'] = '2026-11-10T17:00:00Z';
    data['terms'][1]['certificationStatus'] = 'certified';
    data['terms'][1]['certifiedAt'] = '2026-12-01T17:00:00Z';
    expect(snapshot, throwsFormatException);
    data['terms'][1].remove('certifiedAt');
    expect(snapshot, throwsFormatException);
  });

  testWidgets(
    'civil start is displayed as a local date with unspecified time',
    (tester) async {
      civilStart();
      await tester.pumpWidget(
        MaterialApp(
          home: FederalOfficialProfileScreen(
            officeId: 'us:house:CA01',
            initialSnapshot: snapshot(),
            clock: () => DateTime.parse('2026-11-19T17:00:00Z'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Scheduled start: Jan 4, 2027 (local date; time not specified)',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Start date awaiting official confirmation'),
        findsNothing,
      );
      expect(find.text('Transition awaiting verification'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
