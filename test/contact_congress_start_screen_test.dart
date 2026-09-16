import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/data/models.dart';
import 'package:usa_map_app/screens/contact_congress_start_screen.dart';
import 'package:usa_map_app/services/congressional_district_service.dart';

void main() {
  final states = [
    StateRecord(
      id: 'AL',
      name: 'Alabama',
      fips: '01',
      path: '',
      bbox: const [0, 0, 1, 1],
      centroid: const [0, 0],
    ),
  ];
  final senators = {
    'AL': [
      Senator(
        name: 'First Senator',
        contactUrl: 'https://first.senate.gov/contact',
      ),
      Senator(
        name: 'Second Senator',
        contactUrl: 'https://second.senate.gov/contact',
      ),
    ],
  };
  final representatives = {
    'AL': [
      Representative(
        name: 'District One Representative',
        districtNumber: 1,
        website: 'https://one.house.gov/contact',
      ),
      Representative(
        name: 'District Two Representative',
        districtNumber: 2,
        website: 'https://two.house.gov/contact',
      ),
    ],
  };

  testWidgets('requires a full address before opening the composer', (
    tester,
  ) async {
    await _pump(
      tester,
      states: states,
      senators: senators,
      representatives: representatives,
      lookup: (_) async => const CongressionalDistrictLookupResult.noMatch(),
    );

    expect(find.text('Where do you live?'), findsOneWidget);
    expect(find.textContaining('two U.S. senators'), findsOneWidget);
    expect(find.text('Write once. Contact each office.'), findsNothing);

    await _tapFindMembers(tester);

    expect(find.text('Enter your street address'), findsOneWidget);
    expect(find.text('Choose your state'), findsOneWidget);
  });

  testWidgets('fills city and state from a recognized ZIP code', (
    tester,
  ) async {
    await _pump(
      tester,
      states: states,
      senators: senators,
      representatives: representatives,
      lookup: (_) async => const CongressionalDistrictLookupResult.noMatch(),
    );

    await tester.enterText(
      find.byKey(const Key('district-zip-field')),
      '36602',
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();

    final cityField = tester.widget<TextFormField>(
      find.byKey(const Key('district-city-field')),
    );
    expect(cityField.controller?.text, 'Mobile');
    expect(find.text('Alabama'), findsOneWidget);
    expect(find.text('Mobile, AL filled from ZIP 36602.'), findsOneWidget);
    expect(find.byKey(const Key('zip-autofill-notice')), findsOneWidget);
  });

  testWidgets(
    'matches one district and shows two senators plus one House member',
    (tester) async {
      await _pump(
        tester,
        states: states,
        senators: senators,
        representatives: representatives,
        lookup: (address) async {
          expect(address.street, '123 Main Street');
          expect(address.state, 'AL');
          return const CongressionalDistrictLookupResult.matched(
            CongressionalDistrictMatch(
              matchedAddress: '123 MAIN ST, MOBILE, AL, 36602',
              stateAbbreviation: 'AL',
              stateFips: '01',
              districtNumber: 1,
              districtCode: '01',
              congressionalSession: '119',
            ),
          );
        },
      );

      await _enterAddress(tester);
      await _tapFindMembers(tester);

      expect(find.byKey(const Key('district-match-success')), findsOneWidget);
      expect(find.text('Address matched • AL-1'), findsOneWidget);
      expect(find.text('First Senator'), findsOneWidget);
      expect(find.text('Second Senator'), findsOneWidget);
      expect(find.text('District One Representative'), findsOneWidget);
      expect(find.text('District Two Representative'), findsNothing);
      expect(find.text('Write to 3 offices'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('continue-to-compose-button')),
      );
      await tester.tap(find.byKey(const Key('continue-to-compose-button')));
      await tester.pumpAndSettle();

      expect(find.text('Write once. Contact each office.'), findsOneWidget);
      expect(find.text('3 offices selected'), findsOneWidget);
    },
  );

  testWidgets('does not guess when the address is ambiguous', (tester) async {
    await _pump(
      tester,
      states: states,
      senators: senators,
      representatives: representatives,
      lookup: (_) async => const CongressionalDistrictLookupResult.ambiguous(),
    );
    await _enterAddress(tester);
    await _tapFindMembers(tester);

    expect(find.byKey(const Key('district-lookup-error')), findsOneWidget);
    expect(find.textContaining('more than one district'), findsOneWidget);
    expect(find.byKey(const Key('continue-to-compose-button')), findsNothing);
  });

  testWidgets('shows a territory House office without inventing senators', (
    tester,
  ) async {
    final puertoRico = StateRecord(
      id: 'PR',
      name: 'Puerto Rico',
      fips: '72',
      path: '',
      bbox: const [0, 0, 1, 1],
      centroid: const [0, 0],
    );
    await _pump(
      tester,
      states: [puertoRico],
      senators: const {},
      representatives: {
        'PR': [
          Representative(
            name: 'Resident Commissioner',
            districtNumber: 0,
            website: 'https://commissioner.house.gov/contact',
          ),
        ],
      },
      lookup: (_) async => const CongressionalDistrictLookupResult.matched(
        CongressionalDistrictMatch(
          matchedAddress: '1 CALLE PRINCIPAL, SAN JUAN, PR, 00901',
          stateAbbreviation: 'PR',
          stateFips: '72',
          districtNumber: 0,
          districtCode: '98',
          congressionalSession: '119',
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('district-street-field')),
      '1 Calle Principal',
    );
    await tester.enterText(
      find.byKey(const Key('district-city-field')),
      'San Juan',
    );
    await tester.ensureVisible(find.byKey(const Key('district-state-field')));
    await tester.tap(find.byKey(const Key('district-state-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Puerto Rico').last);
    await tester.enterText(
      find.byKey(const Key('district-zip-field')),
      '00901',
    );
    await _tapFindMembers(tester);

    expect(find.text('Address matched • PR at-large'), findsOneWidget);
    expect(find.text('Resident Commissioner'), findsOneWidget);
    expect(find.text('Write to 1 office'), findsOneWidget);
    expect(find.textContaining('U.S. Senator for PR'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required List<StateRecord> states,
  required Map<String, List<Senator>> senators,
  required Map<String, List<Representative>> representatives,
  required Future<CongressionalDistrictLookupResult> Function(
    CongressionalDistrictAddress address,
  )
  lookup,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => MapDataProvider(),
      child: MaterialApp(
        home: ContactCongressStartScreen(
          states: states,
          senatorsByState: senators,
          houseMembersByState: representatives,
          districtLookup: lookup,
        ),
      ),
    ),
  );
}

Future<void> _enterAddress(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('district-street-field')),
    '123 Main Street',
  );
  await tester.enterText(
    find.byKey(const Key('district-city-field')),
    'Mobile',
  );
  await tester.ensureVisible(find.byKey(const Key('district-state-field')));
  await tester.tap(find.byKey(const Key('district-state-field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Alabama').last);
  await tester.enterText(find.byKey(const Key('district-zip-field')), '36602');
}

Future<void> _tapFindMembers(WidgetTester tester) async {
  final button = find.byKey(const Key('find-delegation-button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
