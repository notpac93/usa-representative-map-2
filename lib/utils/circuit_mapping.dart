class CircuitMapping {
  static const Map<String, String> stateToCircuit = {
    'ME': 'U.S. Court of Appeals for the First Circuit',
    'MA': 'U.S. Court of Appeals for the First Circuit',
    'NH': 'U.S. Court of Appeals for the First Circuit',
    'PR': 'U.S. Court of Appeals for the First Circuit',
    'RI': 'U.S. Court of Appeals for the First Circuit',

    'CT': 'U.S. Court of Appeals for the Second Circuit',
    'NY': 'U.S. Court of Appeals for the Second Circuit',
    'VT': 'U.S. Court of Appeals for the Second Circuit',

    'DE': 'U.S. Court of Appeals for the Third Circuit',
    'NJ': 'U.S. Court of Appeals for the Third Circuit',
    'PA': 'U.S. Court of Appeals for the Third Circuit',
    'VI': 'U.S. Court of Appeals for the Third Circuit',

    'MD': 'U.S. Court of Appeals for the Fourth Circuit',
    'NC': 'U.S. Court of Appeals for the Fourth Circuit',
    'SC': 'U.S. Court of Appeals for the Fourth Circuit',
    'VA': 'U.S. Court of Appeals for the Fourth Circuit',
    'WV': 'U.S. Court of Appeals for the Fourth Circuit',

    'LA': 'U.S. Court of Appeals for the Fifth Circuit',
    'MS': 'U.S. Court of Appeals for the Fifth Circuit',
    'TX': 'U.S. Court of Appeals for the Fifth Circuit',

    'KY': 'U.S. Court of Appeals for the Sixth Circuit',
    'MI': 'U.S. Court of Appeals for the Sixth Circuit',
    'OH': 'U.S. Court of Appeals for the Sixth Circuit',
    'TN': 'U.S. Court of Appeals for the Sixth Circuit',

    'IL': 'U.S. Court of Appeals for the Seventh Circuit',
    'IN': 'U.S. Court of Appeals for the Seventh Circuit',
    'WI': 'U.S. Court of Appeals for the Seventh Circuit',

    'AR': 'U.S. Court of Appeals for the Eighth Circuit',
    'IA': 'U.S. Court of Appeals for the Eighth Circuit',
    'MN': 'U.S. Court of Appeals for the Eighth Circuit',
    'MO': 'U.S. Court of Appeals for the Eighth Circuit',
    'NE': 'U.S. Court of Appeals for the Eighth Circuit',
    'ND': 'U.S. Court of Appeals for the Eighth Circuit',
    'SD': 'U.S. Court of Appeals for the Eighth Circuit',

    'AK': 'U.S. Court of Appeals for the Ninth Circuit',
    'AZ': 'U.S. Court of Appeals for the Ninth Circuit',
    'CA': 'U.S. Court of Appeals for the Ninth Circuit',
    'GU': 'U.S. Court of Appeals for the Ninth Circuit',
    'HI': 'U.S. Court of Appeals for the Ninth Circuit',
    'ID': 'U.S. Court of Appeals for the Ninth Circuit',
    'MT': 'U.S. Court of Appeals for the Ninth Circuit',
    'NV': 'U.S. Court of Appeals for the Ninth Circuit',
    'MP': 'U.S. Court of Appeals for the Ninth Circuit',
    'OR': 'U.S. Court of Appeals for the Ninth Circuit',
    'WA': 'U.S. Court of Appeals for the Ninth Circuit',

    'CO': 'U.S. Court of Appeals for the Tenth Circuit',
    'KS': 'U.S. Court of Appeals for the Tenth Circuit',
    'NM': 'U.S. Court of Appeals for the Tenth Circuit',
    'OK': 'U.S. Court of Appeals for the Tenth Circuit',
    'UT': 'U.S. Court of Appeals for the Tenth Circuit',
    'WY': 'U.S. Court of Appeals for the Tenth Circuit',

    'AL': 'U.S. Court of Appeals for the Eleventh Circuit',
    'FL': 'U.S. Court of Appeals for the Eleventh Circuit',
    'GA': 'U.S. Court of Appeals for the Eleventh Circuit',

    'DC': 'U.S. Court of Appeals for the District of Columbia Circuit',
  };

  static String? getCircuitForState(String stateId) {
    return stateToCircuit[stateId.toUpperCase()];
  }
}
