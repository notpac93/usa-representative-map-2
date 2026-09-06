import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/utils/search_handler.dart';
import 'package:usa_map_app/screens/landing_screen.dart';
import 'package:usa_map_app/screens/local_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Find Your Representatives Search & Autofill Tests', () {
    test('SearchHandler parses and autofills home ZIP code', () async {
      final handler = SearchHandler();
      await handler.loadData();
      final provider = MapDataProvider();

      final results = await handler.search('90210', provider);
      expect(results.isNotEmpty, isTrue);

      final topResult = results.first;
      expect(topResult.type, SearchResultType.zipCode);
      expect(topResult.title, contains('90210'));
      expect(topResult.cityName, 'Beverly Hills');
      expect(topResult.stateId, 'CA');
      expect(topResult.subtitle, contains('Beverly Hills, CA'));
    });

    test('SearchHandler parses and autofills street address with ZIP code', () async {
      final handler = SearchHandler();
      await handler.loadData();
      final provider = MapDataProvider();

      final results = await handler.search('123 Main St, 90210', provider);
      expect(results.isNotEmpty, isTrue);

      final topResult = results.first;
      expect(topResult.type, SearchResultType.address);
      expect(topResult.title, contains('123 Main St'));
      expect(topResult.title, contains('Beverly Hills'));
      expect(topResult.title, contains('90210'));
      expect(topResult.cityName, 'Beverly Hills');
      expect(topResult.stateId, 'CA');
    });

    test('SearchHandler parses street address with City and State', () async {
      final handler = SearchHandler();
      await handler.loadData();
      final provider = MapDataProvider();

      final results = await handler.search('500 Elm St, Austin, TX', provider);
      expect(results.isNotEmpty, isTrue);

      final topResult = results.first;
      expect(topResult.type, SearchResultType.address);
      expect(topResult.title, contains('500 Elm St, Austin, TX'));
      expect(topResult.cityName, 'Austin');
      expect(topResult.stateId, 'TX');
      expect(topResult.subtitle, contains('Austin, TX'));
    });

    test('SearchHandler parses city name search', () async {
      final handler = SearchHandler();
      await handler.loadData();
      final provider = MapDataProvider();

      final results = await handler.search('Austin, TX', provider);
      expect(results.isNotEmpty, isTrue);

      final cityResult = results.firstWhere((r) => r.type == SearchResultType.city);
      expect(cityResult.cityName, 'Austin');
      expect(cityResult.stateId, 'TX');
      expect(cityResult.subtitle, contains('Your Representatives in Austin, TX'));

      // Also search plain city name
      final plainResults = await handler.search('Austin', provider);
      expect(plainResults.any((r) => r.cityName == 'Austin'), isTrue);
    });

    testWidgets('LandingScreen reframed around finding Your representatives', (tester) async {
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

      // Check header
      expect(find.text('Find Your Representatives'), findsOneWidget);
      expect(find.text('USA Representative Map'), findsNothing);
      expect(
        find.text('Enter your home address, ZIP code, city, or state to see your local, state, and federal elected officials.'),
        findsNothing,
      );

      // Check search bar hint text
      expect(find.text('Enter your home address, ZIP code, city, or state...'), findsOneWidget);

      // Verify quick suggestion chips are not present
      expect(find.text('ZIP: 90210'), findsNothing);
      expect(find.text('Address: 1600 Pennsylvania Ave'), findsNothing);
    });

    testWidgets('Entering ZIP code in search bar navigates to LocalDetailScreen with Your Representatives banner', (tester) async {
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

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, '90210');
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final optionFinder = find.text('90210 — Beverly Hills, CA');
      expect(optionFinder, findsOneWidget);
      await tester.tap(optionFinder);

      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(LocalDetailScreen), findsOneWidget);
      expect(find.text('YOUR HOME ZIP CODE'), findsOneWidget);
      expect(find.text('Your Elected Local, State & Federal Officials'), findsOneWidget);
    });
  });
}
