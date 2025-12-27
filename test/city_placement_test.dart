import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/utils/city_placements.dart';
import 'package:usa_map_app/data/models.dart';
// import 'package:usa_map_app/utils/city_labeling.dart'; // Ensure this exists or mock if needed

void main() {
  group('City Placements', () {
    // Helper to test intersection logic (replicated from implementation)
    // [minX, minY, maxX, maxY]
    bool intersects(List<double> a, List<double> b) {
      final xOverlap = (a[2] < b[0] || a[0] > b[2]) ? 0 : 1;
      final yOverlap = (a[3] < b[1] || a[1] > b[3]) ? 0 : 1;
      return (xOverlap * yOverlap) > 0;
    }

    test('Bounding Box Intersection', () {
      final a = [0.0, 0.0, 10.0, 10.0];
      final b = [5.0, 5.0, 15.0, 15.0];
      final c = [20.0, 20.0, 30.0, 30.0];

      expect(intersects(a, b), isTrue);
      expect(intersects(a, c), isFalse);
    });

    test('Single City Placement', () {
      final feature = CityFeature(
        id: '1',
        name: 'Test City',
        x: 100,
        y: 100,
        lon: -90,
        lat: 35,
        population: 1000,
      );

      final city = DecoratedCity(
        feature: feature,
        normalizedName: 'TEST CITY',
        displayName: 'Test City',
        placementJitter: 0.5,
      );

      final result = computeCityPlacements(
        [city],
        ComputePlacementOptions(
          normalizedZoom: 1.0,
          transform: [0, 0, 1],
          viewWidth: 1000,
          viewHeight: 1000,
          baseMarkerRadius: 2.0,
          baseFontSize: 12.0,
          baseOffsetX: 5.0,
          baseOffsetY: 5.0,
          strokeWidth: 2.0,
          detailZoomFactor: 1.0,
          labelPaddingScale: 1.0,
          preferCentered: false,
          maxLabels: 100,
        ),
      );

      expect(result.length, 1);
      final placement = result[0];
      expect(placement.text, 'Test City');
      // Verify bbox is populated
      expect(placement.bbox.length, 4);
    });

    test('Collision Avoidance', () {
      // Two cities very close
      final f1 = CityFeature(
        id: '1',
        name: 'A',
        x: 100,
        y: 100,
        lon: -90,
        lat: 35,
        population: 1000,
      );
      final c1 = DecoratedCity(
        feature: f1,
        normalizedName: 'A',
        displayName: 'A',
      );

      final f2 = CityFeature(
        id: '2',
        name: 'B',
        x: 102,
        y: 102,
        lon: -90,
        lat: 35,
        population: 900,
      );
      final c2 = DecoratedCity(
        feature: f2,
        normalizedName: 'B',
        displayName: 'B',
      );

      final result = computeCityPlacements(
        [c1, c2],
        ComputePlacementOptions(
          normalizedZoom: 1.0,
          transform: [0, 0, 1],
          viewWidth: 1000,
          viewHeight: 1000,
          baseMarkerRadius: 5.0, // Large markers to force collision
          baseFontSize: 12.0,
          baseOffsetX: 5.0,
          baseOffsetY: 5.0,
          strokeWidth: 2.0,
          detailZoomFactor: 1.0,
          labelPaddingScale: 2.0, // Large padding
        ),
      );

      // With strict collision logic, one might be dropped or moved.
      // Current implementation iterates candidates but doesn't drop unless maxLabels is hit?
      // Actually, wait, the implementation DOES NOT drop if overlap remains, it just picks "minOverlap".
      // Line 317 in source: "If minOverlap > 0 ... if (ov < minOverlap) ... chosenPl = pl"
      // It pushes correct choice to 'placedBoxes' then adds to 'placements'.
      // So it returns ALL labels, but positioned to minimize overlap.

      expect(result.length, 2);
      expect(result[0].city.feature.id, '1');
      expect(result[1].city.feature.id, '2');

      // We expect the second one to try to move away if possible
    });
  });
}
