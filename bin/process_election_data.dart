import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';

/// Merges 2020 Election Data into county_demographics.json.
///
/// Reads: data/raw/election_results.csv
/// Updates: assets/data/county_demographics.json
Future<void> main() async {
  final csvFile = File('data/raw/election_results.csv');
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
  // Likely UTF-8
  final csvInput = await csvFile.readAsString();
  final rows = const CsvToListConverter().convert(csvInput, eol: '\n');
  if (rows.isEmpty) return;

  final header = rows[0].map((e) => e.toString().toLowerCase().trim()).toList();
  final fipsIndex = header.indexOf('county_fips');
  final perGopIndex = header.indexOf('per_gop');
  final perDemIndex = header.indexOf('per_dem');

  if (fipsIndex == -1 || perGopIndex == -1 || perDemIndex == -1) {
    print(
      "Error: Missing required columns in CSV (county_fips, per_gop, per_dem)",
    );
    return;
  }

  print("Processing ${rows.length} rows...");
  int updatedCount = 0;
  int missingCount = 0;

  for (int i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.length <= perDemIndex) continue;

    final rawFips = row[fipsIndex].toString();
    // Ensure 5 digits
    final fips = rawFips.length < 5 ? rawFips.padLeft(5, '0') : rawFips;

    final gopVal = row[perGopIndex];
    final demVal = row[perDemIndex];

    double gopPer = 0.0;
    double demPer = 0.0;

    if (gopVal is num) gopPer = gopVal.toDouble();
    if (demVal is num) demPer = demVal.toDouble();

    // Convert 0.714 -> 71.4 -> Round to 71? Or keep Double?
    // CountyDemographics model uses `double?`.
    // Existing data uses int (82, 18).
    // Let's use int to match existing style, or double if precise.
    // The UI `_buildPartySplitBar` prints `${demo.democrat!}%`.
    // It takes `double?` but UI usually expects whole numbers or short doubles.
    // Let's round to integer for simplicity in UI if that's what was there.
    // Existing JSON checks: "republican": 82.
    // Let's store as rounded integer 0-100.

    final repInt = (gopPer * 100).round();
    final demInt = (demPer * 100).round();

    if (countiesMap.containsKey(fips)) {
      final existing = countiesMap[fips] as Map<String, dynamic>;
      existing['republican'] = repInt;
      existing['democrat'] = demInt;
      updatedCount++;
    } else {
      // We have election data but no Demographics entry?
      // Should we create it? If we have no population?
      // User asked for "party data for all counties".
      // If we skipped it in census, maybe we should add it here too?
      // But we just added ALL census counties (3000+).
      // So missing matches should be rare.
      missingCount++;
      // print("Warning: No demographics entry for election FIPS $fips");
    }
  }

  // Write back
  fullJson['counties'] = countiesMap;
  await jsonFile.writeAsString(
    const JsonEncoder.withIndent('    ').convert(fullJson),
  );

  print("Success: Updated $updatedCount counties with election data.");
  if (missingCount > 0)
    print(
      "Warning: $missingCount election records matched no existing county.",
    );
}
