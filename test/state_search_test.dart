import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/utils/search_handler.dart';
import 'package:usa_map_app/data/data_provider.dart';
import 'package:usa_map_app/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Exact state names, codes and prefixes work before atlas loading',
    () async {
      final provider = MapDataProvider();
      for (final query in [
        'california',
        ' CALIFORNIA ',
        'CA',
        'calif',
        'state california',
      ]) {
        final results = await SearchHandler().search(query, provider);
        expect(results.first.type, SearchResultType.state, reason: query);
        expect(results.first.title, 'California · State');
        expect(results.first.stateId, 'CA');
        expect(
          results.where(
            (r) => r.type == SearchResultType.state && r.stateId == 'CA',
          ),
          hasLength(1),
        );
      }
      final results = await SearchHandler().search('california', provider);
      expect(
        results.any(
          (r) => r.type == SearchResultType.city && r.stateId == 'PA',
        ),
        isTrue,
      );
    },
  );
  test(
    'Abbreviated atlas names do not hide full state results or break city queries',
    () async {
      final provider = MapDataProvider()
        ..atlas = Atlas(
          width: 1,
          height: 1,
          projection: '',
          states: [
            StateRecord(
              id: 'CA',
              name: 'CA',
              fips: '',
              path: '',
              bbox: [0, 0, 1, 1],
              centroid: [0, 0],
            ),
          ],
        );
      expect(
        (await SearchHandler().search('California', provider)).first.type,
        SearchResultType.state,
      );
      final city = (await SearchHandler().search(
        'California, PA',
        provider,
      )).first;
      expect(city.type, SearchResultType.city);
      expect(city.stateId, 'PA');
    },
  );
}
