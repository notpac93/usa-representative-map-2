import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import '../map/atlas_path_cache.dart';
import '../utils/fips_mapping.dart';

class MapDataProvider extends ChangeNotifier {
  Atlas? atlas;
  AtlasPathCache? pathCache;
  Map<String, Governor>? governors;
  Map<String, List<Senator>>? senators;
  Map<String, List<Representative>>? houseMembers;
  Map<String, List<CityFeature>>? cities;
  List<CityFeature>? nationalCities;
  Map<String, List<Mayor>>? mayors;
  List<Judge>? supremeCourt;
  Map<String, List<Judge>>? circuitJudges;
  Map<String, List<Judge>>? districtJudges;
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

    // Load Supreme Court
    try {
      final scString = await rootBundle.loadString(
        'assets/data/supreme_court.json',
      );
      final scList = json.decode(scString) as List;
      supremeCourt = scList.map((e) => Judge.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Supreme Court load error: $e");
    }

    // Load Circuit Judges
    try {
      final cString = await rootBundle.loadString(
        'assets/data/circuit_judges.json',
      );
      final cMap = json.decode(cString) as Map<String, dynamic>;
      circuitJudges = {};
      cMap.forEach((court, list) {
        final jList = list as List;
        circuitJudges![court] = jList.map((e) => Judge.fromJson(e)).toList();
      });
    } catch (e) {
      debugPrint("Circuit Judges load error: $e");
    }

    // Load District Judges
    try {
      final dString = await rootBundle.loadString(
        'assets/data/district_judges.json',
      );
      final dMap = json.decode(dString) as Map<String, dynamic>;
      districtJudges = {};
      dMap.forEach((court, list) {
        final jList = list as List;
        districtJudges![court] = jList.map((e) => Judge.fromJson(e)).toList();
      });
    } catch (e) {
      debugPrint("District Judges load error: $e");
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
      final Map<String, int> _lsadRanks = {};

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

      const stateCapitals = {
        'AL': 'Montgomery',
        'AK': 'Juneau',
        'AZ': 'Phoenix',
        'AR': 'Little Rock',
        'CA': 'Sacramento',
        'CO': 'Denver',
        'CT': 'Hartford',
        'DE': 'Dover',
        'FL': 'Tallahassee',
        'GA': 'Atlanta',
        'HI': 'Honolulu',
        'ID': 'Boise',
        'IL': 'Springfield',
        'IN': 'Indianapolis',
        'IA': 'Des Moines',
        'KS': 'Topeka',
        'KY': 'Frankfort',
        'LA': 'Baton Rouge',
        'ME': 'Augusta',
        'MD': 'Annapolis',
        'MA': 'Boston',
        'MI': 'Lansing',
        'MN': 'St. Paul',
        'MS': 'Jackson',
        'MO': 'Jefferson City',
        'MT': 'Helena',
        'NE': 'Lincoln',
        'NV': 'Carson City',
        'NH': 'Concord',
        'NJ': 'Trenton',
        'NM': 'Santa Fe',
        'NY': 'Albany',
        'NC': 'Raleigh',
        'ND': 'Bismarck',
        'OH': 'Columbus',
        'OK': 'Oklahoma City',
        'OR': 'Salem',
        'PA': 'Harrisburg',
        'RI': 'Providence',
        'SC': 'Columbia',
        'SD': 'Pierre',
        'TN': 'Nashville',
        'TX': 'Austin',
        'UT': 'Salt Lake City',
        'VT': 'Montpelier',
        'VA': 'Richmond',
        'WA': 'Olympia',
        'WV': 'Charleston',
        'WI': 'Madison',
        'WY': 'Cheyenne',
        'DC': 'Washington',
      };

      for (var f in features) {
        // Support either flattened or nested structure
        final stateId =
            f['stateId'] as String? ??
            (f['properties'] as Map<String, dynamic>?)?['stateId'] as String?;
        final rawName = f['name'] as String;

        // Clean name
        final name = rawName
            .replaceAll(' city', '')
            .replaceAll(' town', '')
            .replaceAll(' village', '')
            .replaceAll(' CDP', '')
            .replaceAll(' borough', '')
            .replaceAll(' municipality', '');

        final isCapital = stateId != null && stateCapitals[stateId] == name;

        int? population = f['population'] as int?;

        if (stateId != null && popUpdates.containsKey(stateId)) {
          if (popUpdates[stateId]!.containsKey(rawName)) {
            population = popUpdates[stateId]![rawName];
          }
        }

        final city = CityFeature(
          id: f['id'] as String,
          name: name,
          x: (f['x'] as num).toDouble(),
          y: (f['y'] as num).toDouble(),
          lon: (f['lon'] as num).toDouble(),
          lat: (f['lat'] as num).toDouble(),
          population: population,
          isCapital: isCapital,
          stateId: stateId,
        );

        // Store temporary LSAD rank as part of sorting, but we don't need to persist it in model
        int lsadRank = 0;
        if (rawName.endsWith(' city'))
          lsadRank = 4;
        else if (rawName.endsWith(' borough') ||
            rawName.endsWith(' municipality'))
          lsadRank = 3;
        else if (rawName.endsWith(' town') || rawName.endsWith(' village'))
          lsadRank = 2;
        else if (rawName.endsWith(' CDP'))
          lsadRank = 1;

        if (stateId != null) {
          if (cities![stateId] == null) cities![stateId] = [];
          cities![stateId]!.add(city);
          // We can attach the lsadRank to a map for sorting
          _lsadRanks[city.id] = lsadRank;
        }
      }

      // Sort the cities for rendering occlusion priority
      for (final stateCities in cities!.values) {
        stateCities.sort((a, b) {
          // 1. Capital first
          if (a.isCapital && !b.isCapital) return -1;
          if (!a.isCapital && b.isCapital) return 1;

          // 2. Population
          final popA = a.population ?? 0;
          final popB = b.population ?? 0;
          if (popA != popB) {
            return popB.compareTo(popA); // Descending
          }

          // 3. Fallback to LSAD
          final lsadA = _lsadRanks[a.id] ?? 0;
          final lsadB = _lsadRanks[b.id] ?? 0;
          return lsadB.compareTo(lsadA);
        });
      }

      // Create a globally sorted list for the national map
      nationalCities = cities!.values.expand((e) => e).toList();
      nationalCities!.sort((a, b) {
        if (a.isCapital && !b.isCapital) return -1;
        if (!a.isCapital && b.isCapital) return 1;
        final popA = a.population ?? 0;
        final popB = b.population ?? 0;
        if (popA != popB) return popB.compareTo(popA);
        final lsadA = _lsadRanks[a.id] ?? 0;
        final lsadB = _lsadRanks[b.id] ?? 0;
        return lsadB.compareTo(lsadA);
      });
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

  List<PlaceFeature>? getCachedPlaces(String stateFips) =>
      _placesCache[stateFips];

  Future<List<PlaceFeature>> loadPlacesForState(String stateFips) async {
    if (_placesCache.containsKey(stateFips)) {
      return _placesCache[stateFips]!;
    }

    try {
      final fips = FipsMapping.getFips(stateFips);
      final path = 'assets/data/places/$fips.json';
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
