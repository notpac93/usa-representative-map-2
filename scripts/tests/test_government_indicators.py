import importlib.util
import json
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('indicators', Path(__file__).parents[1] / 'refresh_government_indicators.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class GovernmentIndicatorsTest(unittest.TestCase):
    def test_only_agency_https_sources(self):
        for u in ['https://www2.census.gov/data', 'https://apps.bea.gov/regional/zip/SAGDP.zip', 'https://api.bls.gov/publicAPI/v2/timeseries/data/']:
            m.verify_url(u)
        for u in ['http://www.census.gov/data', 'https://census.gov.example.com/data', 'https://example.com/data', 'file:///etc/passwd', 'https://other.gov/data']:
            with self.assertRaises(ValueError): m.verify_url(u)

    def test_suppressed_values_are_missing(self):
        for value in ['-666666666', '(NA)', '', 'NaN', 'inf', None]:
            self.assertIsNone(m.number(value))
        self.assertEqual(m.number('1,234'), 1234)

    def test_state_rows_exclude_counties(self):
        rows = m.acs_rows(b'GEO_ID|B19013_E001|B19013_M001\n0400000US06|100000|100\n0500000US06001|200000|100\n')
        self.assertEqual(list(rows), ['06'])

    def test_bundled_data_valid_and_all_states_present(self):
        data = json.loads(m.OUTPUT.read_text())
        self.assertEqual(len(data['requiredStates']), 51)
        m.validate(data)
        data['states']['CA'].pop('income')
        with self.assertRaises(ValueError): m.validate(data)

    def test_rejects_missing_or_mismatched_history(self):
        data = json.loads(m.OUTPUT.read_text())
        data['states']['CA']['income']['history'] = {}
        with self.assertRaises(ValueError): m.validate(data)
        data = json.loads(m.OUTPUT.read_text())
        period = data['states']['CA']['gdp']['period']
        data['states']['CA']['gdp']['history'][period] += 1e6
        with self.assertRaises(ValueError): m.validate(data)

    def test_suppressed_historical_estimate_is_not_plotted(self):
        output = {'CA': {'income': {}, 'rent': {}}}
        m.add_acs_history(output, {'06': 'CA'}, 2021, {
            'B19013': b'GEO_ID|B19013_E001|B19013_M001\n0400000US06|-666666666|10\n',
            'B25064': b'GEO_ID|B25064_E001|B25064_M001\n0400000US06|1000|10\n',
            'B25077': b'GEO_ID|B25077_E001|B25077_M001\n',
            'B25003': b'GEO_ID|B25003_E001|B25003_E002\n',
        })
        self.assertNotIn('history', output['CA']['income'])
        self.assertEqual(output['CA']['rent']['history']['2021'], 1000)

    def test_network_failure_preserves_last_good_bundle(self):
        before = m.OUTPUT.read_bytes()
        with patch.object(m, 'fetch', side_effect=ConnectionError('offline')):
            with self.assertRaises(ConnectionError): m.refresh()
        self.assertEqual(m.OUTPUT.read_bytes(), before)

if __name__ == '__main__': unittest.main()
