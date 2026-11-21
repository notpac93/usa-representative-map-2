import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/data/models.dart';
import 'package:usa_map_app/screens/contact_congress_screen.dart';
import 'package:usa_map_app/screens/congress_screen.dart';
import 'package:usa_map_app/screens/lawmaker_detail_screen.dart';
import 'package:usa_map_app/widgets/direct_message_button.dart';

void main() {
  final representative = Representative(
    name: 'Example Representative',
    districtNumber: 7,
    party: 'D',
    phone: '202-555-0142',
    office: 'Example House Office Building',
    photoLocalPath: 'representatives/CA-ted-lieu.jpg',
    website: 'https://example.house.gov',
    contactUrl: 'https://example.house.gov/contact',
    bioguideId: 'E000001',
  );
  for (final width in [320.0, 390.0, 1024.0]) {
    testWidgets('compact profile and Direct Message work at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => MapDataProvider(),
          child: MaterialApp(
            home: LawmakerDetailScreen(
              lawmaker: representative,
              role: 'Representative',
              stateId: 'CA',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Direct Message'), findsOneWidget);
      expect(find.text('Example Representative'), findsOneWidget);
      expect(find.text('U.S. Representative'), findsOneWidget);
      expect(find.text('CA · District 7'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('Official website')).dy,
        lessThan(700),
      );
      expect(find.text('About your representative'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DirectMessageButton));
      await tester.pumpAndSettle();
      final screen = tester.widget<ContactCongressScreen>(
        find.byType(ContactCongressScreen),
      );
      expect(screen.directoryContact, isTrue);
      expect(screen.recipients.single.bioguideId, 'E000001');
      expect(
        screen.recipients.single.officialUrl,
        'https://example.house.gov/contact',
      );
      expect(find.text('Delivery Method'), findsOneWidget);
      expect(find.text('How your message is sent'), findsNothing);
      expect(find.text('Your email is your record'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'congressional results use the same button for the chosen senator',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = MapDataProvider()
        ..houseMembers = {
          'CA': [representative],
        }
        ..senators = {
          'CA': [Senator(name: 'Example Senator', bioguideId: 'S000001')],
        };
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: CongressScreen(initialTabIndex: 0)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DirectMessageButton), findsOneWidget);
      await tester.tap(find.byType(DirectMessageButton));
      await tester.pumpAndSettle();
      final screen = tester.widget<ContactCongressScreen>(
        find.byType(ContactCongressScreen),
      );
      expect(screen.recipients.single.bioguideId, 'S000001');
      expect(tester.takeException(), isNull);
    },
  );
}
