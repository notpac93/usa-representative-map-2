import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import '../map/national_map_painter.dart'; // For AtlasPathCache

class MapDataProvider extends ChangeNotifier {
  Atlas? atlas;
  AtlasPathCache? pathCache;
  Map<String, Governor>? governors;
  Map<String, List<Senator>>? senators;
  Map<String, List<Representative>>? houseMembers;
  Map<String, List<CityFeature>>? cities;

  List<OverlayFeature>? counties;
  List<OverlayFeature>? cd116;
  List<OverlayFeature>? urbanAreas;
  List<OverlayFeature>? zcta;
  List<OverlayFeature>? lakes;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Future<void> loadAllData() async {
    try {
      final atlasString = await rootBundle.loadString('assets/data/atlas.json');
      atlas = Atlas.fromJson(json.decode(atlasString));

      pathCache = AtlasPathCache();
      pathCache!.parseAndCache(atlas!);

      // Load Governors
      try {
        final govString = await rootBundle.loadString(
          'assets/data/governors.json',
        );
        final govList = json.decode(govString) as List;
        governors = {
          for (var item in govList)
            if (item['stateId'] != null)
              item['stateId']: Governor.fromJson(item),
        };
      } catch (e) {
        debugPrint("Error loading governors: $e");
      }

      // Load Senators
      try {
        final senString = await rootBundle.loadString(
          'assets/data/senators.json',
        );
        final senList = json.decode(senString) as List;
        senators = {};
        for (var item in senList) {
          final stateId = item['stateId'] as String?;
          final senJsonList = item['senators'] as List?;
          if (stateId != null && senJsonList != null) {
            senators![stateId] = senJsonList
                .map((e) => Senator.fromJson(e))
                .toList();
          }
        }
      } catch (e) {
        debugPrint("Error loading senators: $e");
      }

      // Load House Members
      try {
        final houseString = await rootBundle.loadString(
          'assets/data/houseMembers.json',
        );
        final houseList = json.decode(houseString) as List;
        houseMembers = {};
        for (var item in houseList) {
          final stateId = item['stateId'] as String?;
          final repJsonList = item['representatives'] as List?;
          if (stateId != null && repJsonList != null) {
            houseMembers![stateId] = repJsonList
                .map((e) => Representative.fromJson(e))
                .toList();
          }
        }
      } catch (e) {
        debugPrint("Error loading house members: $e");
      }

      // Load Cities
      try {
        final citiesString = await rootBundle.loadString(
          'assets/data/cities.json',
        );
        final citiesJson = json.decode(citiesString);
        final features = citiesJson['features'] as List;
        cities = {};
        for (var f in features) {
          // Convert to CityFeature
          final city = CityFeature.fromJson(f);
          // My script outputs stateId.
          // If CityFeature doesn't have it, we access raw map 'f'
          final stateId =
              f['properties']['stateId'] as String?; // Access 'properties' map
          if (stateId != null) {
            if (cities![stateId] == null) cities![stateId] = [];
            cities![stateId]!.add(city);
          }
        }
      } catch (e) {
        debugPrint("Cities load error or missing: $e");
      }

      // Load Overlays
      try {
        counties = await _loadOverlay('assets/data/overlays/counties.json');
        cd116 = await _loadOverlay('assets/data/overlays/cd116.json');
        urbanAreas = await _loadOverlay('assets/data/overlays/urbanAreas.json');
        zcta = await _loadOverlay('assets/data/overlays/zcta.json');
        lakes = await _loadOverlay('assets/data/overlays/lakes.json');
      } catch (e) {
        debugPrint("Overlay load error: $e");
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading data: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helpers to get data by State Code (e.g. "IL" or FIPS "17")
  // Note: JSON keys need verification. Usually "IL".
  // Atlas uses FIPS ("17"). Atlas StateRecord has "id" (FIPS) and maybe we can derive "IL"?
  // We need a FIPS -> USPS mapping if the JSONs uses USPS.
  // Standard cb_2023_us_state_5m uses FIPS as ID.
  // `capitals.dart` uses USPS.
  // We need a map. I'll stick to FIPS for matching if possible, or build a helper.

  Future<List<OverlayFeature>> _loadOverlay(String path) async {
    try {
      final jsonString = await rootBundle.loadString(path);
      final jsonMap = json.decode(jsonString);
      final features = jsonMap['features'] as List;
      return features.map((f) => OverlayFeature.fromJson(f)).toList();
    } catch (e) {
      debugPrint("Failed to load overlay $path: $e");
      return [];
    }
  }
}
