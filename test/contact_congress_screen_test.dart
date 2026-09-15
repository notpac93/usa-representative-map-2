import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/data/models.dart';
import 'package:usa_map_app/screens/contact_congress_screen.dart';
import 'package:usa_map_app/services/congressional_district_service.dart';
import 'package:usa_map_app/services/congressional_delivery_service.dart';

void main() {
  const recipients = [
    ContactCongressRecipient(
      name: 'Alex Senator',
      role: 'U.S. Senator',
      officialUrl: 'https://alex.senate.gov/contact',
      chamber: CongressionalChamber.senate,
    ),
    ContactCongressRecipient(
      name: 'Jordan Senator',
      role: 'U.S. Senator',
      officialUrl: 'https://jordan.senate.gov/contact',
      chamber: CongressionalChamber.senate,
    ),
  ];

  testWidgets('completes assisted flow without claiming direct delivery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: ContactCongressScreen(
          stateName: 'California',
          recipients: recipients,
          initialAddress: '123 Main St, Los Angeles, CA 90012',
        ),
      ),
    );

    expect(find.text('2 offices selected'), findsOneWidget);
    expect(find.text('Alex Senator • U.S. Senator'), findsOneWidget);

    await tester.tap(find.text('Choose a topic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Education').last);
    await tester.enterText(
      find.byKey(const Key('contact-subject-field')),
      'Support public schools',
    );
    await tester.enterText(
      find.byKey(const Key('contact-message-field')),
      'Please support stable funding for public schools in our community.',
    );
    await tester.tap(find.byKey(const Key('contact-continue-button')));
    await tester.pumpAndSettle();

    expect(find.text('Where replies go'), findsOneWidget);
    expect(find.textContaining('Why we ask:'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Taylor Citizen',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'taylor@example.com',
    );
    await tester.tap(find.byKey(const Key('contact-attestation')));
    await tester.tap(find.byKey(const Key('contact-continue-button')));
    await tester.pumpAndSettle();

    expect(find.text('Ready for the official sites'), findsOneWidget);
    expect(
      find.textContaining('This app has not sent your message.'),
      findsOneWidget,
    );
    expect(find.text('Submit to each office'), findsOneWidget);
    expect(find.text('Alex Senator'), findsOneWidget);
    expect(find.text('Jordan Senator'), findsOneWidget);
  });

  test('accepts only official House and Senate HTTPS URLs', () {
    const senate = ContactCongressRecipient(
      name: 'Senator',
      role: 'U.S. Senator',
      officialUrl: 'https://example.senate.gov/contact',
      chamber: CongressionalChamber.senate,
    );
    const house = ContactCongressRecipient(
      name: 'Representative',
      role: 'U.S. Representative',
      officialUrl: 'https://example.house.gov/contact',
      chamber: CongressionalChamber.house,
    );
    const unsafe = ContactCongressRecipient(
      name: 'Unknown',
      role: 'U.S. Senator',
      officialUrl: 'https://example.com/contact',
      chamber: CongressionalChamber.senate,
    );

    expect(senate.hasVerifiedOfficialUrl, isTrue);
    expect(house.hasVerifiedOfficialUrl, isTrue);
    expect(unsafe.hasVerifiedOfficialUrl, isFalse);
  });

  testWidgets('adds exactly one House member after an exact district match', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ContactCongressScreen(
          stateName: 'California',
          recipients: recipients,
          initialAddress: '123 Main St, Los Angeles, CA 90012',
          houseCandidates: [
            Representative(
              name: 'Exact Representative',
              districtNumber: 30,
              website: 'https://exact.house.gov/contact',
            ),
            Representative(
              name: 'Different Representative',
              districtNumber: 31,
              website: 'https://different.house.gov/contact',
            ),
          ],
          districtLookup: (address) async {
            expect(address.state, 'CA');
            expect(address.zip, '90012');
            return const CongressionalDistrictLookupResult.matched(
              CongressionalDistrictMatch(
                matchedAddress: '123 MAIN ST, LOS ANGELES, CA, 90012',
                stateAbbreviation: 'CA',
                stateFips: '06',
                districtNumber: 30,
                districtCode: '30',
                congressionalSession: '119',
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Choose a topic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Education').last);
    await tester.enterText(
      find.byKey(const Key('contact-subject-field')),
      'Support public schools',
    );
    await tester.enterText(
      find.byKey(const Key('contact-message-field')),
      'Please support stable funding for public schools in our community.',
    );
    await tester.tap(find.byKey(const Key('contact-continue-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Taylor Citizen',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'taylor@example.com',
    );
    await tester.tap(find.byKey(const Key('contact-attestation')));
    await tester.tap(find.byKey(const Key('contact-continue-button')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Exact Representative was added'),
      findsOneWidget,
    );
    expect(find.text('Exact Representative'), findsOneWidget);
    expect(find.text('Different Representative'), findsNothing);
    expect(find.textContaining('Official website'), findsNWidgets(3));
  });

  testWidgets(
    'placeholder UI says nothing was sent and offers no send button',
    (tester) async {
      await _pumpAtReview(tester, recipients: recipients);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();

      expect(
        find.byKey(const Key('direct-delivery-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('Nothing has been sent'), findsOneWidget);
      expect(find.byKey(const Key('direct-delivery-submit')), findsNothing);
    },
  );

  testWidgets('shows mixed direct-delivery outcomes office by office', (
    tester,
  ) async {
    await _pumpAtReview(
      tester,
      recipients: recipients,
      deliveryGateway: _MixedGateway(),
    );

    final submit = find.byKey(const Key('direct-delivery-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Alex Senator • Accepted for routing'), findsOneWidget);
    expect(find.text('Jordan Senator • Action needed'), findsOneWidget);
    expect(find.textContaining('not read by staff'), findsOneWidget);
  });

  testWidgets('allows a constituent to choose which offices to contact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: ContactCongressScreen(
          stateName: 'California',
          recipients: recipients,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('contact-recipient-senate:Jordan Senator')),
    );
    await tester.pump();

    expect(find.text('1 office selected'), findsOneWidget);
  });
}

Future<void> _pumpAtReview(
  WidgetTester tester, {
  required List<ContactCongressRecipient> recipients,
  CongressionalDeliveryGateway deliveryGateway =
      const PlaceholderCongressionalDeliveryGateway(),
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: ContactCongressScreen(
        stateName: 'California',
        recipients: recipients,
        initialAddress: '123 Main St, Los Angeles, CA 90012',
        deliveryGateway: deliveryGateway,
      ),
    ),
  );
  await tester.tap(find.text('Choose a topic'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Education').last);
  await tester.enterText(
    find.byKey(const Key('contact-subject-field')),
    'Support public schools',
  );
  await tester.enterText(
    find.byKey(const Key('contact-message-field')),
    'Please support stable funding for public schools in our community.',
  );
  await tester.tap(find.byKey(const Key('contact-continue-button')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Full name'),
    'Taylor Citizen',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email address'),
    'taylor@example.com',
  );
  await tester.tap(find.byKey(const Key('contact-attestation')));
  await tester.tap(find.byKey(const Key('contact-continue-button')));
  await tester.pumpAndSettle();
}

class _MixedGateway implements CongressionalDeliveryGateway {
  @override
  bool get canAttemptDirectDelivery => true;

  @override
  Future<CongressionalDeliveryResult> submit(
    CongressionalDeliveryRequest request,
  ) async {
    return CongressionalDeliveryResult(
      idempotencyKey: request.idempotencyKey,
      offices: [
        CongressionalOfficeDeliveryResult(
          recipient: request.recipients.first,
          status: CongressionalDeliveryStatus.acceptedForRouting,
          message: 'Accepted by the Senate gateway for routing.',
        ),
        CongressionalOfficeDeliveryResult(
          recipient: request.recipients.last,
          status: CongressionalDeliveryStatus.needsUserAction,
          message: 'Finish on the official website.',
        ),
      ],
    );
  }
}
