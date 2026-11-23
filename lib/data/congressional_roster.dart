import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

/// Prepared at development/release time from official bulk sources.
/// Loading this snapshot never performs a network request.
class CongressionalRoster {
  const CongressionalRoster({
    required this.version,
    required this.retrievedAt,
    required this.congress,
    required this.senators,
    required this.houseMembers,
    required this.vacancies,
  });

  final String version;
  final DateTime retrievedAt;
  final int congress;
  final Map<String, List<Senator>> senators;
  final Map<String, List<Representative>> houseMembers;
  final Map<String, String> vacancies;

  static Future<CongressionalRoster> load({AssetBundle? bundle}) async {
    final source = await (bundle ?? rootBundle).loadString(
      'assets/data/congressional_roster.json',
    );
    return CongressionalRoster.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }

  factory CongressionalRoster.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported congressional roster version');
    }
    return CongressionalRoster(
      version: json['version'] as String,
      retrievedAt: DateTime.parse(json['retrievedAt'] as String),
      congress: json['congress'] as int,
      senators: {
        for (final group in json['senate'] as List)
          group['stateId'] as String: [
            for (final member in group['senators'] as List)
              Senator.fromJson(member as Map<String, dynamic>),
          ],
      },
      houseMembers: {
        for (final group in json['house'] as List)
          group['stateId'] as String: [
            for (final member in group['representatives'] as List)
              Representative.fromJson(member as Map<String, dynamic>),
          ],
      },
      vacancies: {
        for (final vacancy in json['vacancies'] as List)
          vacancy['officeId'] as String: vacancy['reason'] as String,
      },
    );
  }
}
