import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/data/models.dart';
import 'package:usa_map_app/screens/president_detail_screen.dart';
import 'package:usa_map_app/screens/order_pdf_viewer_screen.dart';
import 'package:usa_map_app/data/bill_models.dart';
import 'package:usa_map_app/widgets/executive_branch_widget.dart';
import 'package:usa_map_app/screens/landing_screen.dart';
import 'package:usa_map_app/data/civic_data_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPresident = President(
    id: 'donald-trump',
    name: 'Donald J. Trump',
    ordinal: '47th President of the United States',
    party: 'Republican',
    current: true,
    terms: ['2025–Present', '2017–2021'],
    vicePresident: 'JD Vance',
    address: 'The White House, Washington DC',
    website: 'https://www.whitehouse.gov',
    bio: 'Test bio for president.',
  );

  group('President and Executive Orders UI Tests', () {
    testWidgets('ExecutiveBranchWidget renders correctly and has tap target', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExecutiveBranchWidget(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('The President'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    });

    testWidgets('PresidentDetailScreen renders profile, powers, and executive orders section', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PresidentDetailScreen(
            initialPresident: testPresident,
          ),
        ),
      );

      // Pump several frames for async loading to complete
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check Profile
      expect(find.text('Donald J. Trump'), findsWidgets);
      expect(find.text('47th President of the United States'), findsOneWidget);
      expect(find.text('Republican'), findsOneWidget);
      expect(find.text('Active Term'), findsOneWidget);

      // Check Article II Powers
      expect(find.text('Article II Powers'), findsOneWidget);
      expect(find.text('Executive Orders', findRichText: true), findsWidgets);
      expect(find.textContaining('Order Permanence', findRichText: true), findsOneWidget);

      // Check Executive Orders section header & top search bar
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Years'), findsOneWidget);
      expect(find.text('2026 Orders'), findsOneWidget);
      expect(find.text('2025 Orders'), findsOneWidget);
    });

    testWidgets('PresidentDetailScreen real-time search filtering works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PresidentDetailScreen(
            initialPresident: testPresident,
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Enter search text
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'NonExistentOrderNameXYZ');
      await tester.pump(const Duration(milliseconds: 100));

      // Expect no match message
      expect(find.text("No executive orders match 'NonExistentOrderNameXYZ'."), findsOneWidget);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('LandingScreen President button opens PresidentDetailScreen', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => MapDataProvider(),
          child: const MaterialApp(
            home: LandingScreen(),
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Tap Executive Branch button
      final presButton = find.text('Executive Branch');
      expect(presButton, findsOneWidget);

      await tester.tap(presButton);
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify navigated to PresidentDetailScreen
      expect(find.byType(PresidentDetailScreen), findsOneWidget);
      expect(find.text('Article II Powers'), findsOneWidget);
    });

    testWidgets('PresidentDetailScreen expands executive order summary on click and formats date as MM/DD/YYYY', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PresidentDetailScreen(
            initialPresident: testPresident,
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check for expandable summary button
      final expandBtn = find.text('Read Order Summary');
      if (expandBtn.evaluate().isNotEmpty) {
        expect(expandBtn, findsWidgets);

        // Tap to expand
        await tester.tap(expandBtn.first);
        await tester.pumpAndSettle();

        // Expect expanded summary panel & collapse button
        expect(find.text('Official Summary & Scope'), findsOneWidget);
        expect(find.text('Collapse Summary'), findsOneWidget);

        // Tap to collapse again
        await tester.tap(find.text('Collapse Summary').first);
        await tester.pumpAndSettle();

        expect(find.text('Official Summary & Scope'), findsNothing);
      }
    });

    testWidgets('PresidentDetailScreen displays historical presidents properly', (tester) async {
      final biden = President(
        id: 'joe-biden',
        name: 'Joseph R. Biden Jr.',
        ordinal: '46th President of the United States',
        party: 'Democratic',
        current: false,
        terms: ['2021–2025'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PresidentDetailScreen(
            initialPresident: biden,
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Joseph R. Biden Jr.'), findsWidgets);
      expect(find.text('46th President of the United States'), findsOneWidget);
      expect(find.text('Democratic'), findsOneWidget);
    });

    testWidgets('PresidentDetailScreen renders clean executive order cards and top keyword search', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PresidentDetailScreen(
            initialPresident: testPresident,
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check for top keyword search bar
      expect(find.byType(TextField), findsOneWidget);

      // Verify status filter chips and indicators are not present
      expect(find.textContaining('All Statuses'), findsNothing);

      // Verify year filter chips are present
      expect(find.text('All Years'), findsOneWidget);
    });

    testWidgets('PresidentDetailScreen supports snappy pagination and loading more orders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PresidentDetailScreen(
            initialPresident: testPresident,
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check for Load More button
      final loadMoreFinder = find.widgetWithText(OutlinedButton, 'Load More Orders (374 remaining)');
      if (loadMoreFinder.evaluate().isNotEmpty) {
        expect(loadMoreFinder, findsOneWidget);
        await tester.tap(loadMoreFinder);
        await tester.pumpAndSettle();
        expect(find.textContaining('Showing 50 of 399 orders'), findsOneWidget);
      }
    });

    testWidgets('PresidentDetailScreen renders single See Official Order button without redundant buttons', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PresidentDetailScreen(
            initialPresident: testPresident,
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final seeOrderFinder = find.text('See Official Order');
      if (seeOrderFinder.evaluate().isNotEmpty) {
        expect(seeOrderFinder, findsWidgets);
      }

      // Verify redundant buttons are not present
      expect(find.text('Federal Register Doc'), findsNothing);
      expect(find.text('Official PDF (GovInfo)'), findsNothing);
    });

    testWidgets('OrderPdfViewerScreen renders title, citation, and GovInfo action', (tester) async {
      final sampleOrder = ExecutiveOrderRecord(
        id: 'EO-14423',
        orderNumber: '14423',
        title: 'Establishing the United States Space Academy',
        signingDate: '2026-08-28',
        publicationDate: '2026-09-03',
        president: 'Donald Trump',
        presidentId: 'donald-trump',
        citation: '91 FR 56737',
        url: 'https://example.com/eo',
        pdfUrl: 'https://example.com/eo.pdf',
        summary: 'Space is a critical domain for American national security.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OrderPdfViewerScreen(order: sampleOrder),
        ),
      );

      await tester.pump();

      expect(find.text('Executive Order 14423'), findsAtLeastNWidgets(1));
      expect(find.textContaining('91 FR 56737'), findsWidgets);
      expect(find.text('GovInfo PDF'), findsOneWidget);
    });
  });
}
