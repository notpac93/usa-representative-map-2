import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/data_provider.dart';

enum SearchResultType { state, county, city, zipCode, president, supremeCourt, congress, address }

class SearchResult {
  final SearchResultType type;
  final String title;
  final String subtitle;

  // Data for routing
  final String? stateId;
  final String? countyName;
  final String? cityName;
  final String? featureId; // For counties/districts in atlas
  final double? latitude;
  final double? longitude;
  final String? streetAddress;

  SearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    this.stateId,
    this.countyName,
    this.cityName,
    this.featureId,
    this.latitude,
    this.longitude,
    this.streetAddress,
  });
}

class ZipCodeRecord {
  final String zipCode;
  final String city;
  final String state;
  final String county;
  final double latitude;
  final double longitude;

  ZipCodeRecord({
    required this.zipCode,
    required this.city,
    required this.state,
    required this.county,
    required this.latitude,
    required this.longitude,
  });

  factory ZipCodeRecord.fromJson(Map<String, dynamic> json) {
    String zip = json['zip_code'].toString();
    if (zip.length < 5) {
      zip = zip.padLeft(5, '0');
    }

    double parseCoord(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return ZipCodeRecord(
      zipCode: zip,
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      county: json['county']?.toString() ?? '',
      latitude: parseCoord(json['latitude']),
      longitude: parseCoord(json['longitude']),
    );
  }
}

class SearchHandler {
  static final SearchHandler _instance = SearchHandler._internal();
  factory SearchHandler() => _instance;
  SearchHandler._internal();

  List<ZipCodeRecord> _zipCodes = [];
  final Map<String, ZipCodeRecord> _zipMap = {};
  final Map<String, List<ZipCodeRecord>> _cityStateMap = {};
  bool _isLoaded = false;

  static const Map<String, String> stateCodeToName = {
    'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
    'CA': 'California', 'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware',
    'DC': 'District of Columbia', 'FL': 'Florida', 'GA': 'Georgia', 'HI': 'Hawaii',
    'ID': 'Idaho', 'IL': 'Illinois', 'IN': 'Indiana', 'IA': 'Iowa',
    'KS': 'Kansas', 'KY': 'Kentucky', 'LA': 'Louisiana', 'ME': 'Maine',
    'MD': 'Maryland', 'MA': 'Massachusetts', 'MI': 'Michigan', 'MN': 'Minnesota',
    'MS': 'Mississippi', 'MO': 'Missouri', 'MT': 'Montana', 'NE': 'Nebraska',
    'NV': 'Nevada', 'NH': 'New Hampshire', 'NJ': 'New Jersey', 'NM': 'New Mexico',
    'NY': 'New York', 'NC': 'North Carolina', 'ND': 'North Dakota', 'OH': 'Ohio',
    'OK': 'Oklahoma', 'OR': 'Oregon', 'PA': 'Pennsylvania', 'RI': 'Rhode Island',
    'SC': 'South Carolina', 'SD': 'South Dakota', 'TN': 'Tennessee', 'TX': 'Texas',
    'UT': 'Utah', 'VT': 'Vermont', 'VA': 'Virginia', 'WA': 'Washington',
    'WV': 'West Virginia', 'WI': 'Wisconsin', 'WY': 'Wyoming', 'PR': 'Puerto Rico',
  };

  static final Map<String, String> stateNameToCode = {
    for (var entry in stateCodeToName.entries) entry.value.toLowerCase(): entry.key,
  };

  Future<void> loadData() async {
    if (_isLoaded) return;
    try {
      final zipString = await rootBundle.loadString(
        'assets/data/zip_code_database.json',
      );
      final zipList = json.decode(zipString) as List;
      _zipCodes = zipList.map((e) => ZipCodeRecord.fromJson(e)).toList();

      for (var z in _zipCodes) {
        _zipMap[z.zipCode] = z;
        final key = '${z.city.toLowerCase()}_${z.state.toLowerCase()}';
        _cityStateMap.putIfAbsent(key, () => []).add(z);
      }

      _isLoaded = true;
    } catch (e) {
      debugPrint("Error loading search data: $e");
    }
  }

  Future<List<SearchResult>> search(
    String query,
    MapDataProvider provider,
  ) async {
    if (!_isLoaded) {
      await loadData();
    }

    final rawQuery = query.trim();
    final lowerQuery = rawQuery.toLowerCase();
    if (lowerQuery.isEmpty) return [];

    List<SearchResult> results = [];

    // 0. Search Federal Branches (Executive, Legislative, Judicial)
    final isPresMatch = 'the president'.contains(lowerQuery) ||
        'president'.startsWith(lowerQuery) ||
        'executive orders'.contains(lowerQuery) ||
        'executive order'.contains(lowerQuery) ||
        'executive branch'.contains(lowerQuery) ||
        'white house'.contains(lowerQuery) ||
        'donald trump'.contains(lowerQuery) ||
        'trump'.startsWith(lowerQuery) ||
        'joe biden'.contains(lowerQuery) ||
        'biden'.startsWith(lowerQuery);

    if (isPresMatch) {
      results.add(
        SearchResult(
          type: SearchResultType.president,
          title: 'The President of the United States',
          subtitle: 'Article II • Executive Branch & Presidential Orders',
        ),
      );
    }

    final isCongressMatch = 'congress'.contains(lowerQuery) ||
        'the congress'.contains(lowerQuery) ||
        'senate'.startsWith(lowerQuery) ||
        'senator'.startsWith(lowerQuery) ||
        'house of representatives'.contains(lowerQuery) ||
        'representative'.startsWith(lowerQuery) ||
        'legislative'.startsWith(lowerQuery) ||
        'legislative branch'.contains(lowerQuery) ||
        'capitol'.contains(lowerQuery) ||
        'federal bills'.contains(lowerQuery) ||
        'bills'.startsWith(lowerQuery);

    if (isCongressMatch) {
      results.add(
        SearchResult(
          type: SearchResultType.congress,
          title: 'The United States Congress',
          subtitle: 'Article I • Legislative Branch (Senate & House)',
        ),
      );
    }

    final isScotusMatch = 'supreme court'.contains(lowerQuery) ||
        'scotus'.startsWith(lowerQuery) ||
        'judicial'.startsWith(lowerQuery) ||
        'judicial branch'.contains(lowerQuery) ||
        'justice'.startsWith(lowerQuery) ||
        'justices'.startsWith(lowerQuery) ||
        'chief justice'.contains(lowerQuery) ||
        'john roberts'.contains(lowerQuery) ||
        'clarence thomas'.contains(lowerQuery) ||
        'sotomayor'.contains(lowerQuery);

    if (isScotusMatch) {
      results.add(
        SearchResult(
          type: SearchResultType.supremeCourt,
          title: 'The Supreme Court of the United States',
          subtitle: 'Article III • Judicial Branch & Supreme Court Justices',
        ),
      );
    }

    final isElectionMatch = 'upcoming elections'.contains(lowerQuery) ||
        'election'.startsWith(lowerQuery) ||
        'elections'.startsWith(lowerQuery) ||
        'ballot'.startsWith(lowerQuery) ||
        'candidate'.startsWith(lowerQuery) ||
        'candidates'.startsWith(lowerQuery) ||
        'propositions'.startsWith(lowerQuery) ||
        'voting'.startsWith(lowerQuery);

    if (isElectionMatch) {
      results.add(
        SearchResult(
          type: SearchResultType.zipCode,
          title: 'Upcoming 2026 Elections & Ballot Hub',
          subtitle: 'Electoral Candidates, Ballot Propositions, Key Deadlines & Officials',
          stateId: 'US',
        ),
      );
    }

    // 1. SMART ADDRESS & ZIP CODE PARSING
    // Check if query contains a 5-digit ZIP code anywhere (e.g., '123 Main St, 90210' or '90210')
    final zipMatch = RegExp(r'\b(\d{5})\b').firstMatch(rawQuery);
    if (zipMatch != null) {
      final zip = zipMatch.group(1)!;
      final record = _zipMap[zip];
      if (record != null) {
        final streetPart = rawQuery
            .replaceFirst(zip, '')
            .replaceAll(RegExp(r'[,]+$'), '')
            .replaceAll(RegExp(r'^[,]+'), '')
            .trim();

        if (streetPart.isNotEmpty && RegExp(r'[a-zA-Z]').hasMatch(streetPart)) {
          // User entered an address with a ZIP code: auto-fill!
          results.add(
            SearchResult(
              type: SearchResultType.address,
              title: '$streetPart, ${record.city}, ${record.state} $zip',
              subtitle: 'Your Representatives at this address • ${record.city}, ${record.state} (${record.county} County)',
              streetAddress: streetPart,
              cityName: record.city,
              stateId: record.state,
              countyName: record.county,
              latitude: record.latitude,
              longitude: record.longitude,
            ),
          );
        } else {
          // Plain ZIP code or zip with whitespace
          results.add(
            SearchResult(
              type: SearchResultType.zipCode,
              title: '$zip — ${record.city}, ${record.state}',
              subtitle: 'Your Representatives in ${record.city}, ${record.state} (${record.county} County)',
              cityName: record.city,
              stateId: record.state,
              countyName: record.county,
              latitude: record.latitude,
              longitude: record.longitude,
            ),
          );
        }
      }
    }

    // 2. DIGIT PREFIX MATCH (User typing zip code, e.g., '902', '750', etc.)
    if (RegExp(r'^\d+$').hasMatch(rawQuery)) {
      final matchingZips = _zipCodes
          .where((z) => z.zipCode.startsWith(rawQuery) && (zipMatch == null || z.zipCode != zipMatch.group(1)))
          .take(8);

      for (var z in matchingZips) {
        results.add(
          SearchResult(
            type: SearchResultType.zipCode,
            title: '${z.zipCode} — ${z.city}, ${z.state}',
            subtitle: 'Your Representatives in ${z.city}, ${z.state} (${z.county} County)',
            stateId: z.state,
            cityName: z.city,
            countyName: z.county,
            latitude: z.latitude,
            longitude: z.longitude,
          ),
        );
      }
      return results;
    }

    // 3. STREET ADDRESS WITH CITY & STATE (e.g. '123 Main St, Austin, TX' or '1600 Pennsylvania Ave, Washington, DC')
    if (rawQuery.contains(',')) {
      final parts = rawQuery.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        final lastPart = parts.last.toUpperCase();
        final firstPart = parts.first;

        // Check if last part is a 2-letter state code or full state name
        String? targetStateCode;
        if (stateCodeToName.containsKey(lastPart)) {
          targetStateCode = lastPart;
        } else if (stateNameToCode.containsKey(parts.last.toLowerCase())) {
          targetStateCode = stateNameToCode[parts.last.toLowerCase()];
        }

        if (targetStateCode != null) {
          // If 3 parts: [Street, City, State]
          if (parts.length >= 3) {
            final street = firstPart;
            final city = parts[1];
            final key = '${city.toLowerCase()}_${targetStateCode.toLowerCase()}';
            final matchedZips = _cityStateMap[key];
            final county = (matchedZips != null && matchedZips.isNotEmpty)
                ? matchedZips.first.county
                : '';
            final lat = (matchedZips != null && matchedZips.isNotEmpty) ? matchedZips.first.latitude : null;
            final lon = (matchedZips != null && matchedZips.isNotEmpty) ? matchedZips.first.longitude : null;

            results.add(
              SearchResult(
                type: SearchResultType.address,
                title: '$street, $city, $targetStateCode',
                subtitle: 'Your Representatives at this address in $city, $targetStateCode ${county.isNotEmpty ? '($county County)' : ''}',
                streetAddress: street,
                cityName: city,
                stateId: targetStateCode,
                countyName: county.isNotEmpty ? county : null,
                latitude: lat,
                longitude: lon,
              ),
            );
          } else if (parts.length == 2) {
            // Could be [City, State] or [Street, State]
            final cityCandidate = firstPart;
            final key = '${cityCandidate.toLowerCase()}_${targetStateCode.toLowerCase()}';
            final matchedZips = _cityStateMap[key];

            if (matchedZips != null && matchedZips.isNotEmpty) {
              final firstMatch = matchedZips.first;
              results.add(
                SearchResult(
                  type: SearchResultType.city,
                  title: '${firstMatch.city}, $targetStateCode',
                  subtitle: 'Your Representatives in ${firstMatch.city}, $targetStateCode (${firstMatch.county} County)',
                  cityName: firstMatch.city,
                  stateId: targetStateCode,
                  countyName: firstMatch.county,
                  latitude: firstMatch.latitude,
                  longitude: firstMatch.longitude,
                ),
              );
            } else if (RegExp(r'^\d+\s+').hasMatch(cityCandidate)) {
              // Street address with state, e.g. "123 Main St, TX"
              results.add(
                SearchResult(
                  type: SearchResultType.address,
                  title: '$cityCandidate, $targetStateCode',
                  subtitle: 'Your Representatives in $targetStateCode',
                  streetAddress: cityCandidate,
                  stateId: targetStateCode,
                ),
              );
            }
          }
        }
      }
    }

    // 4. STREET ADDRESS STARTER (e.g. '123 Main St' or '742 Evergreen')
    if (RegExp(r'^\d+\s+[a-zA-Z]').hasMatch(rawQuery) && !rawQuery.contains(',')) {
      results.add(
        SearchResult(
          type: SearchResultType.address,
          title: rawQuery,
          subtitle: 'Add your city, state, or ZIP (e.g., "$rawQuery, Springfield, IL") to find your exact representatives',
          streetAddress: rawQuery,
        ),
      );
    }

    // 5. SEARCH STATES (e.g. 'California', 'CA', 'Texas', 'TX')
    if (provider.atlas != null) {
      final stateMatches = provider.atlas!.states.where((s) {
        return s.name.toLowerCase().startsWith(lowerQuery) ||
            s.id.toLowerCase() == lowerQuery;
      }).take(4);

      for (var s in stateMatches) {
        results.add(
          SearchResult(
            type: SearchResultType.state,
            title: '${s.name} (${s.id})',
            subtitle: 'Your Statewide Representatives (Governor & 2 U.S. Senators)',
            stateId: s.id,
          ),
        );
      }
    }

    // 6. SEARCH CITIES (e.g., 'Austin', 'Springfield', 'Seattle')
    final seenCityStates = <String>{};
    final exactMatches = <SearchResult>[];
    final prefixMatches = <SearchResult>[];

    for (var z in _zipCodes) {
      final cityLower = z.city.toLowerCase();
      final key = '${z.city}_${z.state}';
      if (seenCityStates.contains(key)) continue;

      if (cityLower == lowerQuery) {
        seenCityStates.add(key);
        exactMatches.add(
          SearchResult(
            type: SearchResultType.city,
            title: '${z.city}, ${z.state}',
            subtitle: 'Your Representatives in ${z.city}, ${z.state} (${z.county} County)',
            stateId: z.state,
            cityName: z.city,
            countyName: z.county,
            latitude: z.latitude,
            longitude: z.longitude,
          ),
        );
      } else if (cityLower.startsWith(lowerQuery)) {
        seenCityStates.add(key);
        prefixMatches.add(
          SearchResult(
            type: SearchResultType.city,
            title: '${z.city}, ${z.state}',
            subtitle: 'Your Representatives in ${z.city}, ${z.state} (${z.county} County)',
            stateId: z.state,
            cityName: z.city,
            countyName: z.county,
            latitude: z.latitude,
            longitude: z.longitude,
          ),
        );
      }
    }

    results.addAll(exactMatches.take(6));
    final remaining = 8 - results.where((r) => r.type == SearchResultType.city).length;
    if (remaining > 0) {
      results.addAll(prefixMatches.take(remaining));
    }

    // 7. SEARCH COUNTIES
    if (provider.counties != null) {
      final matchingCounties = provider.counties!.where((c) {
        return c.name.toLowerCase().startsWith(lowerQuery) ||
            c.name.toLowerCase().contains(lowerQuery);
      }).take(6);

      for (var county in matchingCounties) {
        results.add(
          SearchResult(
            type: SearchResultType.county,
            title: '${county.name} County',
            subtitle: 'Your County Representatives & Demographics',
            countyName: county.name,
            featureId: county.id,
          ),
        );
      }
    }

    return results;
  }
}
