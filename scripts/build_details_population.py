"""Refresh the offline state population series from Census Vintage 2024."""
import csv
import io
import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

SOURCE = 'https://www2.census.gov/programs-surveys/popest/datasets/2020-2024/state/totals/NST-EST2024-ALLDATA.csv'
ROOT = Path(__file__).resolve().parents[1]

def main():
    with urllib.request.urlopen(SOURCE, timeout=30) as response:
        rows = csv.DictReader(io.StringIO(response.read().decode('utf-8-sig')))
        codes = 'AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY PR'.split()
        fips = '01 02 04 05 06 08 09 10 11 12 13 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 44 45 46 47 48 49 50 51 53 54 55 56 72'.split()
        ids = dict(zip(fips, codes))
        states = {}
        for row in rows:
            state_id = ids.get(row['STATE'].zfill(2))
            if row['SUMLEV'] == '040' and state_id:
                states[state_id] = {str(y): int(row[f'POPESTIMATE{y}']) for y in range(2020, 2025)}
    if len(states) < 50:
        raise ValueError('Expected at least 50 state series; refusing incomplete output')
    output = {
        'source': 'U.S. Census Bureau, Population Estimates Program',
        'url': SOURCE,
        'vintage': 'Vintage 2024',
        'retrievedAt': datetime.now(timezone.utc).isoformat(),
        'description': 'July 1 resident population estimates, 2020–2024. Historical snapshot; not live data.',
        'states': states,
    }
    (ROOT / 'assets/data/detail_population.json').write_text(json.dumps(output, indent=2) + '\n')

if __name__ == '__main__':
    main()
