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
  Map<String, List<Mayor>>? mayors;
  Map<String, CountyDemographics>? countyDemo;
  Map<String, CountyDemographics>? districtDemo;

  List<OverlayFeature>? counties;
  List<OverlayFeature>? cd116;
  List<OverlayFeature>? urbanAreas;
  List<OverlayFeature>? zcta;
  List<OverlayFeature>? lakes;
  List<OverlayFeature>? judicial;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Future<void> loadAllData() async {
    try {
      final atlasString = await rootBundle.loadString('assets/data/atlas.json');
      atlas = Atlas.fromJson(json.decode(atlasString));

      pathCache = AtlasPathCache();
      pathCache!.parseAndCache(atlas!);

      await _loadLeaders();
      await _loadCities();
      await _loadDemographics();
      await _loadOverlays();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading data: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadLeaders() async {
    // Load Governors
    try {
      final govString = await rootBundle.loadString(
        'assets/data/governors.json',
      );
      final govList = json.decode(govString) as List;
      governors = {
        for (var item in govList)
          if (item['stateId'] != null) item['stateId']: Governor.fromJson(item),
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

    // Load Mayors
    try {
      final mayorsString = await rootBundle.loadString(
        'assets/data/mayors.json',
      );
      final mayorsJson = json.decode(mayorsString) as Map<String, dynamic>;
      mayors = {};
      mayorsJson.forEach((stateId, list) {
        final mList = list as List;
        mayors![stateId] = mList.map((e) => Mayor.fromJson(e)).toList();
      });
    } catch (e) {
      debugPrint("Mayors load error: $e");
    }
  }

  Future<void> _loadCities() async {
    try {
      // 1. Load Base Cities
      final citiesString = await rootBundle.loadString(
        'assets/data/cities.json',
      );
      final citiesJson = json.decode(citiesString);
      final features = citiesJson['features'] as List;

      cities = {};

      // 2. Load Census Population Updates (if available)
      Map<String, Map<String, int>> popUpdates = {};
      try {
        final popString = await rootBundle.loadString(
          'assets/data/census_populations.json',
        );
        final popJson = json.decode(popString) as Map<String, dynamic>;
        // Structure: normalized_city_name -> population? No, likely Map<StateId, Map<City, Pop>>?
        // Let's assume the script generates: { "TX": { "Austin city": 993588, ... }, "CA": ... }
        // Or flattens it? Better to keep state structure if possible or FIPS.
        // Assuming simple FIPS keyed or State ID keyed.
        // Let's assume the script produces: { "states": { "TX": { "Austin city": 993588 } } }
        if (popJson['states'] != null) {
          final states = popJson['states'] as Map<String, dynamic>;
          states.forEach((sid, cityMap) {
            popUpdates[sid] = Map<String, int>.from(cityMap as Map);
          });
        }
      } catch (_) {
        // No updates found, ignore
      }

      for (var f in features) {
        // Convert to CityFeature
        // Access raw properties first
        final properties = f['properties'] as Map<String, dynamic>?;
        final stateId = properties?['stateId'] as String?;

        // Update Population if new data exists
        int? population = f['population'] as int?; // existing
        final name = f['name'] as String;

        if (stateId != null && popUpdates.containsKey(stateId)) {
          // Try exact match "Austin city"
          if (popUpdates[stateId]!.containsKey(name)) {
            population = popUpdates[stateId]![name];
          }
        }

        // Re-construct with potentially updated population
        final city = CityFeature(
          id: f['id'] as String,
          name: name,
          x: (f['x'] as num).toDouble(),
          y: (f['y'] as num).toDouble(),
          lon: (f['lon'] as num).toDouble(),
          lat: (f['lat'] as num).toDouble(),
          population: population,
        );

        if (stateId != null) {
          if (cities![stateId] == null) cities![stateId] = [];
          cities![stateId]!.add(city);
        }
      }
    } catch (e) {
      debugPrint("Cities load error or missing: $e");
    }
  }

  Future<void> _loadDemographics() async {
    try {
      final demoString = await rootBundle.loadString(
        'assets/data/county_demographics.json',
      );
      final demoJson = json.decode(demoString) as Map<String, dynamic>;

      countyDemo = (demoJson['counties'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, CountyDemographics.fromJson(value)),
      );

      districtDemo = (demoJson['districts'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, CountyDemographics.fromJson(value)),
      );
    } catch (e) {
      debugPrint("Demographics load error: $e");
    }
  }

  Future<void> _loadOverlays() async {
    try {
      counties = await _loadOverlay('assets/data/overlays/counties.json');
      cd116 = await _loadOverlay('assets/data/overlays/cd116.json');
      urbanAreas = await _loadOverlay('assets/data/overlays/urbanAreas.json');
      zcta = await _loadOverlay('assets/data/overlays/zcta.json');
      lakes = await _loadOverlay('assets/data/overlays/lakes.json');
      judicial = await _loadOverlay('assets/data/overlays/judicial.json');
    } catch (e) {
      debugPrint("Overlay load error: $e");
    }
  }

  // Cache for Places (lazy loaded)
  final Map<String, List<PlaceFeature>> _placesCache = {};

  Future<List<PlaceFeature>> loadPlacesForState(String stateFips) async {
    if (_placesCache.containsKey(stateFips)) {
      return _placesCache[stateFips]!;
    }

    try {
      final path = 'assets/data/places/$stateFips.json';
      final jsonString = await rootBundle.loadString(path);
      final jsonMap = json.decode(jsonString);
      final features = jsonMap['features'] as List;

      final places = features
          .map((f) => PlaceFeature.fromGeoJson(f, stateFips))
          .toList();

      _placesCache[stateFips] = places;
      return places;
    } catch (e) {
      debugPrint("Failed to load Places for state $stateFips: $e");
      return [];
    }
  }

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

  /// Returns a list of Mayors corresponding to the given places (Cities/Towns).
  List<Mayor> getMayorsForPlaces(String stateId, List<PlaceFeature> places) {
    if (mayors == null) return [];

    // Keys in JSON are typically uppercase "TX", "AL", etc.
    // Ensure we handle "tx" or "TX".
    List<Mayor> stateMayors = [];
    if (mayors!.containsKey(stateId)) {
      stateMayors = mayors![stateId]!;
    } else if (mayors!.containsKey(stateId.toUpperCase())) {
      stateMayors = mayors![stateId.toUpperCase()]!;
    } else {
      return [];
    }

    final matchedMayors = <Mayor>[];
    final placeNames = <String>{}; // Use a set for faster lookup context

    // Pre-process places to normalize names
    for (var place in places) {
      var placeName = place.name.toLowerCase();
      // Remove common suffixes from PlaceFeature name
      for (final suffix in [" city", " town", " village", " borough", " cdp"]) {
        if (placeName.endsWith(suffix)) {
          placeName = placeName
              .substring(0, placeName.length - suffix.length)
              .trim();
          break;
        }
      }
      placeNames.add(placeName);
    }

    for (var mayor in stateMayors) {
      // Normalize mayor city
      // 1. Remove State suffix (e.g. "Austin, TX")
      var mayorCity = mayor.city.toLowerCase();
      if (mayorCity.contains(',')) {
        mayorCity = mayorCity.split(',')[0].trim();
      }

      // 2. Remove "City of" or "Town of" prefixes
      if (mayorCity.startsWith("city of ")) {
        mayorCity = mayorCity.substring(8).trim();
      } else if (mayorCity.startsWith("town of ")) {
        mayorCity = mayorCity.substring(8).trim();
      }

      // 3. Remove common suffixes (e.g. "Austin City")
      for (final suffix in [" city", " town", " village", " borough"]) {
        if (mayorCity.endsWith(suffix)) {
          mayorCity = mayorCity
              .substring(0, mayorCity.length - suffix.length)
              .trim();
          break;
        }
      }

      // 4. Exact match against authorized places in the county
      // Note: This logic assumes that if a Place is in the county, its mayor belongs in the list.
      if (placeNames.contains(mayorCity)) {
        matchedMayors.add(mayor);
      }
    }

    return matchedMayors;
  }
}
