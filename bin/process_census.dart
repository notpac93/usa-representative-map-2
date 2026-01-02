import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';

/// Aggregates Census CSV data into a JSON map for the Flutter app.
///
/// Reads from: data/raw/census-csv/cities/sub-est2024_*.csv
/// Writes to: assets/data/census_populations.json
///
/// Output Format:
/// {
///   "states": {
///     "TX": { "Austin city": 993588, ... },
///     "CA": { ... }
///   }
/// }
Future<void> main() async {
  // Files are in the root of census-csv based on `list_dir` output
  final baseDir = Directory('data/raw/census-csv');
  if (!await baseDir.exists()) {
    print("Error: Census data directory not found at ${baseDir.path}");
    return;
  }

  // Map FIPS (e.g. "48") to State ID (e.g. "TX")
  // We need a mapping. If we don't have one, we can either:
  // 1. Load `assets/data/atlas.json` and build a FIPS->ID map?
  // 2. Hardcode or just use FIPS as key in the JSON, but MapDataProvider expects StateID (e.g. "TX").
  // Let's try to load atlas.json or just include a small mapping.

  // Minimal mapping for main states (or load from file if possible, but script is separate).
  // Let's just key by FIPS in the intermediate JSON if easiest?
  // NO, `MapDataProvider` keys `cities` by `stateId` (e.g. "TX").
  // And `_loadCities` loops `features`. Features contain `stateId` ("TX").
  // So `popUpdates` MUST be keyed by "TX", "CA", etc.

  // Solution: Load `assets/data/atlas.json` which has StateRecord(id="TX", fips="48").
  final atlasFile = File('assets/data/atlas.json');
  final fipsToStateId = <String, String>{};

  if (await atlasFile.exists()) {
    try {
      final atlasJson = json.decode(await atlasFile.readAsString());
      final states = atlasJson['states'] as List;
      for (var s in states) {
        final fips = s['fips'].toString(); // Ensure string
        final id = s['id'] as String;
        // Pad FIPS to 2 digits? usually they are "01", "48".
        fipsToStateId[fips] = id;
        // print("Loaded mapping: $fips -> $id");
      }
    } catch (e) {
      print("Warning: Failed to parse atlas.json for FIPS mapping: $e");
    }
  } else {
    print("Warning: atlas.json not found.");
  }

  // Always merge manual mapping to ensure coverage
  print("Merging manual fallback FIPS mapping");
  fipsToStateId.addAll({
    "01": "AL",
    "02": "AK",
    "04": "AZ",
    "05": "AR",
    "06": "CA",
    "08": "CO",
    "09": "CT",
    "10": "DE",
    "11": "DC",
    "12": "FL",
    "13": "GA",
    "15": "HI",
    "16": "ID",
    "17": "IL",
    "18": "IN",
    "19": "IA",
    "20": "KS",
    "21": "KY",
    "22": "LA",
    "23": "ME",
    "24": "MD",
    "25": "MA",
    "26": "MI",
    "27": "MN",
    "28": "MS",
    "29": "MO",
    "30": "MT",
    "31": "NE",
    "32": "NV",
    "33": "NH",
    "34": "NJ",
    "35": "NM",
    "36": "NY",
    "37": "NC",
    "38": "ND",
    "39": "OH",
    "40": "OK",
    "41": "OR",
    "42": "PA",
    "44": "RI",
    "45": "SC",
    "46": "SD",
    "47": "TN",
    "48": "TX",
    "49": "UT",
    "50": "VT",
    "51": "VA",
    "53": "WA",
    "54": "WV",
    "55": "WI",
    "56": "WY",
    "72": "PR",
  });
  // Also handle unpadded just in case (e.g. "1" instead of "01")
  fipsToStateId.addAll({
    "1": "AL",
    "2": "AK",
    "4": "AZ",
    "5": "AR",
    "6": "CA",
    "8": "CO",
    "9": "CT",
  });

  final outputMap = <String, Map<String, int>>{};

  await for (final file in baseDir.list()) {
    if (file is File && file.path.endsWith('.csv')) {
      final filename = file.uri.pathSegments.last;
      // Expect: sub-est2024_48.csv
      final match = RegExp(r'sub-est2024_(\d+)\.csv').firstMatch(filename);
      if (match == null) continue;

      final fips = match.group(1)!;
      final stateId = fipsToStateId[fips];

      if (stateId == null) {
        print("Skipping FIPS $fips (Unknown State ID)");
        continue;
      }

      print("Processing $stateId (FIPS $fips)...");

      final cityPops = await _parseCsv(file);
      if (cityPops.isNotEmpty) {
        outputMap[stateId] = cityPops;
      }
    }
  }

  final outputFile = File('assets/data/census_populations.json');
  await outputFile.writeAsString(json.encode({'states': outputMap}));
  print("Specific census data written to ${outputFile.path}");
}

Future<Map<String, int>> _parseCsv(File file) async {
  final map = <String, int>{};
  try {
    String input;
    try {
      input = await file.readAsString();
    } catch (_) {
      // Fallback to Latin-1
      input = await file.readAsString(encoding: latin1);
    }

    final rows = const CsvToListConverter().convert(input, eol: '\n');
    if (rows.isEmpty) return map;

    final header = rows[0]
        .map((e) => e.toString().toUpperCase().trim())
        .toList();
    final nameIndex = header.indexOf('NAME');
    // 2024 estimate might be named differently? From `head` output: POPESTIMATE2024
    final popIndex = header.indexOf('POPESTIMATE2024');
    final sumlevIndex = header.indexOf('SUMLEV');

    if (nameIndex == -1 || popIndex == -1) return map;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= popIndex) continue;

      if (sumlevIndex != -1) {
        // SUMLEV 162 = Incorporated Place
        // SUMLEV 170 = Consolidated City
        // 172 = Consolidated City (part)
        // 157 = County part
        // We generally want 162 or 170.
        // Austin is 162.
        final sl = row[sumlevIndex].toString();
        // Allow 162 and 170
        if (sl != '162' && sl != '170') continue;
      }

      final name = row[nameIndex].toString();
      final popVal = row[popIndex];

      int? pop;
      if (popVal is int)
        pop = popVal;
      else if (popVal is String)
        pop = int.tryParse(popVal.replaceAll(',', ''));

      if (pop != null) {
        map[name] = pop;
      }
    }
  } catch (e) {
    print("Error parsing ${file.path}: $e");
  }
  return map;
}
