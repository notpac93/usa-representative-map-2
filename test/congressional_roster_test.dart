import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/data/congressional_roster.dart';

void main() {
  test(
    'embedded official snapshot loads both chambers and excludes vacant seats',
    () {
      final json =
          jsonDecode(
                File(
                  'assets/data/congressional_roster.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final roster = CongressionalRoster.fromJson(json);
      expect(roster.congress, 119);
      expect(roster.houseMembers.length, 56);
      expect(roster.senators.values.expand((members) => members).length, 100);
      expect(
        roster.houseMembers.values.expand((members) => members).length +
            roster.vacancies.length,
        441,
      );
      expect(roster.houseMembers['CO']!.length, 8);
      expect(roster.houseMembers['CT']!.length, 5);
      expect(roster.houseMembers['DE']!.length, 1);
      for (final vacancy in roster.vacancies.keys) {
        final seat = vacancy.split(':').last;
        expect(
          roster.houseMembers[seat.substring(0, 2)]!.where(
            (member) => member.districtNumber == int.parse(seat.substring(2)),
          ),
          isEmpty,
        );
      }
    },
  );

  test('unsupported schema fails instead of using stale legacy assets', () {
    expect(
      () => CongressionalRoster.fromJson({'schemaVersion': 2}),
      throwsFormatException,
    );
  });
}
