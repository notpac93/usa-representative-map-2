Map<String, dynamic> censusGeocoderFixture({
  List<Map<String, dynamic>>? addressMatches,
}) {
  return {
    'result': {
      'input': {
        'benchmark': {'benchmarkName': 'Public_AR_Current'},
        'vintage': {'vintageName': 'Current_Current'},
      },
      'addressMatches': addressMatches ?? [censusAddressMatchFixture()],
    },
  };
}

Map<String, dynamic> censusAddressMatchFixture({
  String matchedAddress = '123 MAIN ST, AUSTIN, TX, 78701',
  String state = 'TX',
  String stateFips = '48',
  List<Map<String, dynamic>>? districts,
}) {
  return {
    'matchedAddress': matchedAddress,
    'addressComponents': {'state': state, 'zip': '78701'},
    'geographies': {
      'States': [
        {'STUSAB': state, 'STATE': stateFips, 'GEOID': stateFips},
      ],
      '119th Congressional Districts':
          districts ??
          [
            {
              'STATE': stateFips,
              'GEOID': '${stateFips}35',
              'CD119': '35',
              'CDSESSN': '119',
              'BASENAME': '35',
            },
          ],
    },
  };
}
