import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/screens/landing_screen.dart';
import 'package:usa_map_app/screens/supreme_court_screen.dart';
import 'package:usa_map_app/screens/congress_screen.dart';
import 'package:usa_map_app/screens/president_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Federal Branches Direct Links UI Tests', () {
    testWidgets('LandingScreen displays buttons for all federal branches', (tester) async {
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

      // Check all 4 buttons on landing screen
      expect(find.text('Explore National Map'), findsOneWidget);
      expect(find.text('Executive Branch'), findsOneWidget);
      expect(find.text('Legislative Branch'), findsOneWidget);
      expect(find.text('Judicial Branch'), findsOneWidget);
    });

    testWidgets('Tapping Supreme Court button navigates to SupremeCourtScreen', (tester) async {
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

      final scotusButton = find.text('Judicial Branch');
      expect(scotusButton, findsOneWidget);

      await tester.tap(scotusButton);
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(SupremeCourtScreen), findsOneWidget);
      expect(find.text('Supreme Court of the United States'), findsWidgets);
      expect(find.text('ARTICLE III • THE JUDICIAL BRANCH'), findsOneWidget);
    });

    testWidgets('Tapping Congress button navigates to CongressScreen', (tester) async {
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

      final congressButton = find.text('Legislative Branch');
      expect(congressButton, findsOneWidget);

      await tester.tap(congressButton);
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(CongressScreen), findsOneWidget);
      expect(find.text('The United States Congress'), findsWidgets);
      expect(find.text('U.S. Senate & House of Representatives'), findsOneWidget);
    });
  });
}
