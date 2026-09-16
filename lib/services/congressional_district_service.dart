import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/fips_mapping.dart';
import 'congressional_district_transport_io.dart'
    if (dart.library.html) 'congressional_district_transport_web.dart'
    as census_transport;

enum CongressionalDistrictLookupStatus { matched, noMatch, ambiguous }

class CongressionalDistrictAddress {
  const CongressionalDistrictAddress({
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
  });

  final String street;
  final String city;
  final String state;
  final String zip;
}

class CongressionalDistrictMatch {
  const CongressionalDistrictMatch({
    required this.matchedAddress,
    required this.stateAbbreviation,
    required this.stateFips,
    required this.districtNumber,
    required this.districtCode,
    required this.congressionalSession,
    this.benchmark = 'Public_AR_Current',
    this.vintage = 'Current_Current',
  });

  final String matchedAddress;
  final String stateAbbreviation;
  final String stateFips;
  final int districtNumber;

  /// The Census district code, including special delegate codes such as `98`.
  final String districtCode;
  final String? congressionalSession;
  final String benchmark;
  final String vintage;

  bool get isAtLarge => districtNumber == 0;
}

class CongressionalDistrictLookupResult {
  const CongressionalDistrictLookupResult._(this.status, this.match);

  const CongressionalDistrictLookupResult.matched(
    CongressionalDistrictMatch match,
  ) : this._(CongressionalDistrictLookupStatus.matched, match);

  const CongressionalDistrictLookupResult.noMatch()
    : this._(CongressionalDistrictLookupStatus.noMatch, null);

  const CongressionalDistrictLookupResult.ambiguous()
    : this._(CongressionalDistrictLookupStatus.ambiguous, null);

  final CongressionalDistrictLookupStatus status;
  final CongressionalDistrictMatch? match;
}

class CongressionalDistrictServiceException implements Exception {
  const CongressionalDistrictServiceException(this.message);

  final String message;

  @override
  String toString() => 'CongressionalDistrictServiceException: $message';
}

/// Resolves a structured address using the official U.S. Census Geocoder.
///
/// The service intentionally does not infer a district from ZIP code, city, or
/// a partial response. Callers receive [CongressionalDistrictLookupStatus.noMatch]
/// or [CongressionalDistrictLookupStatus.ambiguous] unless one address, state,
/// and current congressional district agree.
class CongressionalDistrictService {
  CongressionalDistrictService({http.Client? client})
    : _client = client ?? http.Client();

  static final Uri _endpoint = Uri.https(
    'geocoding.geo.census.gov',
    '/geocoder/geographies/address',
  );

  final http.Client _client;

  Future<CongressionalDistrictLookupResult> lookup(
    CongressionalDistrictAddress address,
  ) async {
    final uri = _endpoint.replace(
      queryParameters: {
        'street': address.street.trim(),
        'city': address.city.trim(),
        'state': address.state.trim().toUpperCase(),
        'zip': address.zip.trim(),
        'benchmark': 'Public_AR_Current',
        'vintage': 'Current_Current',
        'format': 'json',
      },
    );

    final response = await census_transport.fetchCensusResponse(uri, _client);
    if (response.statusCode != 200) {
      throw CongressionalDistrictServiceException(
        'Census Geocoder returned HTTP ${response.statusCode}.',
      );
    }

    return parseResponse(response.body);
  }

  /// Parses a Census Geocoder response independently from network access.
  CongressionalDistrictLookupResult parseResponse(String responseBody) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(responseBody);
    } on FormatException catch (error) {
      throw CongressionalDistrictServiceException(
        'Census Geocoder returned invalid JSON: ${error.message}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const CongressionalDistrictServiceException(
        'Census Geocoder response was not a JSON object.',
      );
    }

    final result = decoded['result'];
    if (result is! Map<String, dynamic>) {
      throw const CongressionalDistrictServiceException(
        'Census Geocoder response did not contain a result object.',
      );
    }

    final addressMatches = result['addressMatches'];
    if (addressMatches is! List) {
      throw const CongressionalDistrictServiceException(
        'Census Geocoder response did not contain address matches.',
      );
    }
    if (addressMatches.isEmpty) {
      return const CongressionalDistrictLookupResult.noMatch();
    }
    if (addressMatches.length != 1) {
      return const CongressionalDistrictLookupResult.ambiguous();
    }

    final addressMatch = addressMatches.single;
    if (addressMatch is! Map<String, dynamic>) {
      throw const CongressionalDistrictServiceException(
        'Census Geocoder address match was malformed.',
      );
    }

    final matchedAddress = _nonEmptyString(addressMatch['matchedAddress']);
    final geographies = addressMatch['geographies'];
    if (matchedAddress == null || geographies is! Map<String, dynamic>) {
      return const CongressionalDistrictLookupResult.noMatch();
    }

    final states = _mapList(geographies['States']);
    if (states.length != 1) {
      return states.length > 1
          ? const CongressionalDistrictLookupResult.ambiguous()
          : const CongressionalDistrictLookupResult.noMatch();
    }

    final stateFips = _stateFips(states.single);
    final stateAbbreviation = _stateAbbreviation(states.single, stateFips);
    if (stateFips == null || stateAbbreviation == null) {
      return const CongressionalDistrictLookupResult.noMatch();
    }

    final congressionalLayers = geographies.entries.where(
      (entry) => RegExp(
        r'^\d+(?:st|nd|rd|th) Congressional Districts$',
        caseSensitive: false,
      ).hasMatch(entry.key),
    );
    final districts = <Map<String, dynamic>>[
      for (final layer in congressionalLayers) ..._mapList(layer.value),
    ];
    if (districts.isEmpty) {
      return const CongressionalDistrictLookupResult.noMatch();
    }

    final candidates = districts
        .map((district) => _districtCandidate(district, stateFips))
        .whereType<_DistrictCandidate>()
        .toSet();
    if (candidates.isEmpty) {
      return const CongressionalDistrictLookupResult.noMatch();
    }
    if (candidates.length != 1) {
      return const CongressionalDistrictLookupResult.ambiguous();
    }

    final candidate = candidates.single;
    final input = result['input'];
    final benchmark = input is Map<String, dynamic>
        ? _nestedName(input['benchmark'], 'benchmarkName')
        : null;
    final vintage = input is Map<String, dynamic>
        ? _nestedName(input['vintage'], 'vintageName')
        : null;
    return CongressionalDistrictLookupResult.matched(
      CongressionalDistrictMatch(
        matchedAddress: matchedAddress,
        stateAbbreviation: stateAbbreviation,
        stateFips: stateFips,
        districtNumber: candidate.districtNumber,
        districtCode: candidate.districtCode,
        congressionalSession: candidate.congressionalSession,
        benchmark: benchmark ?? 'Public_AR_Current',
        vintage: vintage ?? 'Current_Current',
      ),
    );
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static String? _nonEmptyString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String? _nestedName(dynamic value, String key) {
    if (value is! Map<String, dynamic>) return null;
    return _nonEmptyString(value[key]);
  }

  static String? _stateFips(Map<String, dynamic> state) {
    final value = _nonEmptyString(state['STATE'] ?? state['GEOID']);
    if (value == null || !RegExp(r'^\d{2}$').hasMatch(value)) return null;
    return value;
  }

  static String? _stateAbbreviation(
    Map<String, dynamic> state,
    String? stateFips,
  ) {
    final abbreviation = _nonEmptyString(state['STUSAB'])?.toUpperCase();
    if (abbreviation != null && RegExp(r'^[A-Z]{2}$').hasMatch(abbreviation)) {
      return abbreviation;
    }
    if (stateFips == null) return null;
    for (final entry in FipsMapping.stateToFips.entries) {
      if (entry.value == stateFips) return entry.key;
    }
    return null;
  }

  static _DistrictCandidate? _districtCandidate(
    Map<String, dynamic> district,
    String stateFips,
  ) {
    final districtState = _nonEmptyString(district['STATE']);
    final geoid = _nonEmptyString(district['GEOID']);
    if (districtState != null && districtState != stateFips) return null;
    if (geoid != null && !geoid.startsWith(stateFips)) return null;

    String? districtCode;
    for (final entry in district.entries) {
      if (RegExp(r'^CD\d+$').hasMatch(entry.key)) {
        districtCode = _nonEmptyString(entry.value);
        break;
      }
    }
    if (districtCode == null || !RegExp(r'^\d{2}$').hasMatch(districtCode)) {
      return null;
    }

    final parsedCode = int.tryParse(districtCode);
    if (parsedCode == null) return null;
    final basename = _nonEmptyString(district['BASENAME'])?.toLowerCase() ?? '';
    final isAtLarge =
        parsedCode == 0 ||
        parsedCode == 98 ||
        basename.contains('at large') ||
        basename.contains('at-large');
    final session = _nonEmptyString(district['CDSESSN']);

    return _DistrictCandidate(
      districtCode: districtCode,
      districtNumber: isAtLarge ? 0 : parsedCode,
      congressionalSession: session,
    );
  }
}

class _DistrictCandidate {
  const _DistrictCandidate({
    required this.districtCode,
    required this.districtNumber,
    required this.congressionalSession,
  });

  final String districtCode;
  final int districtNumber;
  final String? congressionalSession;

  @override
  bool operator ==(Object other) {
    return other is _DistrictCandidate &&
        other.districtCode == districtCode &&
        other.districtNumber == districtNumber &&
        other.congressionalSession == congressionalSession;
  }

  @override
  int get hashCode =>
      Object.hash(districtCode, districtNumber, congressionalSession);
}
