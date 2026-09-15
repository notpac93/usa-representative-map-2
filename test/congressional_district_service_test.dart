import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:usa_map_app/data/models.dart';
import 'package:usa_map_app/services/congressional_district_service.dart';

import 'fixtures/census_geocoder_fixtures.dart';

void main() {
  group('CongressionalDistrictService', () {
    test('requests current Census benchmark and vintage', () async {
      late Uri requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(jsonEncode(censusGeocoderFixture()), 200);
      });
      final service = CongressionalDistrictService(client: client);

      final result = await service.lookup(
        const CongressionalDistrictAddress(
          street: ' 123 Main St ',
          city: ' Austin ',
          state: ' tx ',
          zip: ' 78701 ',
        ),
      );

      expect(result.status, CongressionalDistrictLookupStatus.matched);
      expect(requestedUri.scheme, 'https');
      expect(requestedUri.host, 'geocoding.geo.census.gov');
      expect(requestedUri.path, '/geocoder/geographies/address');
      expect(requestedUri.queryParameters['street'], '123 Main St');
      expect(requestedUri.queryParameters['city'], 'Austin');
      expect(requestedUri.queryParameters['state'], 'TX');
      expect(requestedUri.queryParameters['zip'], '78701');
      expect(requestedUri.queryParameters['benchmark'], 'Public_AR_Current');
      expect(requestedUri.queryParameters['vintage'], 'Current_Current');
      expect(requestedUri.queryParameters['format'], 'json');
    });

    test('parses one exact address and congressional district', () {
      final result = CongressionalDistrictService().parseResponse(
        jsonEncode(censusGeocoderFixture()),
      );

      expect(result.status, CongressionalDistrictLookupStatus.matched);
      expect(result.match?.matchedAddress, '123 MAIN ST, AUSTIN, TX, 78701');
      expect(result.match?.stateAbbreviation, 'TX');
      expect(result.match?.stateFips, '48');
      expect(result.match?.districtNumber, 35);
      expect(result.match?.districtCode, '35');
      expect(result.match?.congressionalSession, '119');
      expect(result.match?.isAtLarge, isFalse);
    });

    test('returns no match when Census finds no address', () {
      final result = CongressionalDistrictService().parseResponse(
        jsonEncode(censusGeocoderFixture(addressMatches: [])),
      );

      expect(result.status, CongressionalDistrictLookupStatus.noMatch);
      expect(result.match, isNull);
    });

    test('returns ambiguous when Census finds more than one address', () {
      final addressMatch = censusAddressMatchFixture();
      final result = CongressionalDistrictService().parseResponse(
        jsonEncode(
          censusGeocoderFixture(addressMatches: [addressMatch, addressMatch]),
        ),
      );

      expect(result.status, CongressionalDistrictLookupStatus.ambiguous);
      expect(result.match, isNull);
    });

    test('returns ambiguous for multiple different districts', () {
      final result = CongressionalDistrictService().parseResponse(
        jsonEncode(
          censusGeocoderFixture(
            addressMatches: [
              censusAddressMatchFixture(
                districts: [
                  {
                    'STATE': '48',
                    'GEOID': '4835',
                    'CD119': '35',
                    'CDSESSN': '119',
                  },
                  {
                    'STATE': '48',
                    'GEOID': '4837',
                    'CD119': '37',
                    'CDSESSN': '119',
                  },
                ],
              ),
            ],
          ),
        ),
      );

      expect(result.status, CongressionalDistrictLookupStatus.ambiguous);
    });

    test('does not accept a district from a conflicting state', () {
      final result = CongressionalDistrictService().parseResponse(
        jsonEncode(
          censusGeocoderFixture(
            addressMatches: [
              censusAddressMatchFixture(
                districts: [
                  {
                    'STATE': '06',
                    'GEOID': '0612',
                    'CD119': '12',
                    'CDSESSN': '119',
                  },
                ],
              ),
            ],
          ),
        ),
      );

      expect(result.status, CongressionalDistrictLookupStatus.noMatch);
    });

    test('normalizes Census delegate code 98 to an at-large district', () {
      final result = CongressionalDistrictService().parseResponse(
        jsonEncode(
          censusGeocoderFixture(
            addressMatches: [
              censusAddressMatchFixture(
                state: 'DC',
                stateFips: '11',
                districts: [
                  {
                    'STATE': '11',
                    'GEOID': '1198',
                    'CD119': '98',
                    'CDSESSN': '119',
                    'BASENAME': 'Delegate District (at Large)',
                  },
                ],
              ),
            ],
          ),
        ),
      );

      expect(result.status, CongressionalDistrictLookupStatus.matched);
      expect(result.match?.districtCode, '98');
      expect(result.match?.districtNumber, 0);
      expect(result.match?.isAtLarge, isTrue);
    });

    test('throws a typed exception for invalid service JSON', () {
      expect(
        () => CongressionalDistrictService().parseResponse('not json'),
        throwsA(isA<CongressionalDistrictServiceException>()),
      );
    });

    test('throws a typed exception for an HTTP failure', () async {
      final service = CongressionalDistrictService(
        client: MockClient(
          (request) async => http.Response('unavailable', 503),
        ),
      );

      expect(
        service.lookup(
          const CongressionalDistrictAddress(
            street: '123 Main St',
            city: 'Austin',
            state: 'TX',
            zip: '78701',
          ),
        ),
        throwsA(isA<CongressionalDistrictServiceException>()),
      );
    });
  });

  group('Congressional contact model fields', () {
    test('Senator retains contact and bioguide identifiers', () {
      final senator = Senator.fromJson({
        'name': 'Example Senator',
        'contactUrl': 'https://example.senate.gov/contact',
        'bioguideId': 'S000001',
      });

      expect(senator.contactUrl, 'https://example.senate.gov/contact');
      expect(senator.bioguideId, 'S000001');
    });

    test('Representative retains contact, bioguide, and district number', () {
      final representative = Representative.fromJson({
        'name': 'Example Representative',
        'contactUrl': 'https://example.house.gov/contact',
        'bioguideId': 'R000001',
        'districtNumber': '7',
      });

      expect(representative.contactUrl, 'https://example.house.gov/contact');
      expect(representative.bioguideId, 'R000001');
      expect(representative.districtNumber, 7);
    });
  });
}
