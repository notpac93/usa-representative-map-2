import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/data/models.dart';
import 'package:usa_map_app/utils/search_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Find Your Representatives Search & Autofill Tests', () {
    test('County searches retain their state when names repeat', () async {
      final provider = MapDataProvider()
        ..counties = [
          OverlayFeature(id: '06059', name: 'Orange', path: '', bbox: []),
          OverlayFeature(id: '12095', name: 'Orange', path: '', bbox: []),
        ];
      final results = (await SearchHandler().search(
        'Orange',
        provider,
      )).where((r) => r.type == SearchResultType.county).toList();
      expect(results.map((r) => r.stateId), ['CA', 'FL']);
      expect(results.map((r) => r.title), [
        'Orange County, CA',
        'Orange County, FL',
      ]);
    });

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

    test(
      'SearchHandler parses and autofills street address with ZIP code',
      () async {
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
      },
    );

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

      final cityResult = results.firstWhere(
        (r) => r.type == SearchResultType.city,
      );
      expect(cityResult.cityName, 'Austin');
      expect(cityResult.stateId, 'TX');
      expect(
        cityResult.subtitle,
        contains('Your Representatives in Austin, TX'),
      );

      // Also search plain city name
      final plainResults = await handler.search('Austin', provider);
      expect(plainResults.any((r) => r.cityName == 'Austin'), isTrue);
    });
  });
}
