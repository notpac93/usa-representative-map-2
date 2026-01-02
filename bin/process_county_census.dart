import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';

/// Merges Census County Population data into county_demographics.json.
///
/// Reads: data/raw/census-csv/counties/totals/co-est2024-alldata.csv
/// Updates: assets/data/county_demographics.json
Future<void> main() async {
  final csvFile = File(
    'data/raw/census-csv/counties/totals/co-est2024-alldata.csv',
  );
  final jsonFile = File('assets/data/county_demographics.json');

  if (!await csvFile.exists()) {
    print("Error: CSV file not found at ${csvFile.path}");
    return;
  }

  if (!await jsonFile.exists()) {
    print("Error: JSON file not found at ${jsonFile.path}");
    return;
  }

  // 1. Read existing JSON
  final jsonString = await jsonFile.readAsString();
  final fullJson = json.decode(jsonString) as Map<String, dynamic>;
  final countiesMap = fullJson['counties'] as Map<String, dynamic>;

  // 2. Read CSV
  // Use Latin-1 to be safe with names
  String csvInput;
  try {
    csvInput = await csvFile.readAsString();
  } catch (_) {
    csvInput = await csvFile.readAsString(encoding: latin1);
  }

  final rows = const CsvToListConverter().convert(csvInput, eol: '\n');
  if (rows.isEmpty) return;

  final header = rows[0].map((e) => e.toString().toUpperCase().trim()).toList();
  final stateIndex = header.indexOf('STATE');
  final countyIndex = header.indexOf('COUNTY');
  final nameIndex = header.indexOf('CTYNAME'); // "Autauga County"
  final popIndex = header.indexOf('POPESTIMATE2024');
  final sumlevIndex = header.indexOf('SUMLEV');

  if (stateIndex == -1 || countyIndex == -1 || popIndex == -1) {
    print("Error: Missing required columns in CSV");
    return;
  }

  print("Processing ${rows.length} rows...");
  int addedCount = 0;
  int updatedCount = 0;

  for (int i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.length <= popIndex) continue;

    final sumlev = row[sumlevIndex].toString();
    // Filter for SUMLEV 050 (County), allowing '50' for unpadded
    if (sumlev != '050' && sumlev != '50') continue;

    final stateFips = row[stateIndex].toString().padLeft(2, '0');
    final countyFips = row[countyIndex].toString().padLeft(3, '0');
    final fullFips = "$stateFips$countyFips";

    final rawName = row[nameIndex].toString();
    // Strip " County", " Parish", " Borough", " Census Area"
    String name = rawName
        .replaceAll(' County', '')
        .replaceAll(' Parish', '')
        .replaceAll(' Borough', '')
        .replaceAll(' Census Area', '')
        .replaceAll(
          ' city',
          '',
        ); // Special cases like "Baltimore city" vs "Baltimore County"
    // Note: "Baltimore city" usually is independent city.
    // If we strip " city", "Baltimore city" -> "Baltimore". "Baltimore County" -> "Baltimore".
    // They have different FIPS so collision is fine in Map, but Display name might be same.
    // Usually independent cities keep "City" in UI?
    // For now, let's just strip " County" and " Parish" which are noise.
    // "Borough" in Alaska is like county.

    // Better Name cleaning:
    if (rawName.endsWith(" County"))
      name = rawName.substring(0, rawName.length - 7);
    else if (rawName.endsWith(" Parish"))
      name = rawName.substring(0, rawName.length - 7);
    else if (rawName.endsWith(" Borough"))
      name = rawName.substring(0, rawName.length - 8);
    else if (rawName.endsWith(" Census Area"))
      name = rawName.substring(0, rawName.length - 12);
    else
      name = rawName; // Keep "City" for independent cities to distinguish

    final popVal = row[popIndex];
    int popInt = 0;
    if (popVal is int)
      popInt = popVal;
    else if (popVal is String)
      popInt = int.tryParse(popVal.replaceAll(',', '')) ?? 0;

    // Format "1,234,567"
    final popStr = _formatNumber(popInt);

    if (countiesMap.containsKey(fullFips)) {
      // Update existing
      final existing = countiesMap[fullFips] as Map<String, dynamic>;
      existing['population'] = popStr;
      // potentially update name if we prefer our cleaned version?
      // Existing JSON has "Wood", "Dallas". CSV provides "Wood County".
      // Our Logic produces "Wood". Safe to overwrite or keep?
      // Let's keep existing name if valid, but update population.
      countiesMap[fullFips] = existing;
      updatedCount++;
    } else {
      // Create new
      countiesMap[fullFips] = {
        "id": fullFips,
        "name": name,
        "population": popStr,
        // No description or election data for new ones
        "description": "$name is located in the US.",
        "republican": null,
        "democrat": null,
      };
      addedCount++;
    }
  }

  // Write back
  fullJson['counties'] = countiesMap;
  await jsonFile.writeAsString(
    const JsonEncoder.withIndent('    ').convert(fullJson),
  );

  print("Success: Updated $updatedCount, Added $addedCount counties.");
}

String _formatNumber(int number) {
  // Simple comma formatting
  return number.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}
