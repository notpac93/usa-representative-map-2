import importlib.util
import json
import tempfile
import unittest
import sys
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parents[1]))
import refresh_governor_history as m

class GovernorHistoryTest(unittest.TestCase):
    def test_saved_records_have_unique_service_ids_and_sources(self):
        data = json.loads(m.OUTPUT.read_text())['states']['CA']['people']
        self.assertEqual(len(data), 38)
        services = [s for p in data for s in p['services']]
        self.assertEqual(len({s['id'] for s in services}), 39)
        self.assertTrue(all(s['startYear'] <= s['endYear'] for s in services))
        self.assertTrue(all(s['sourceUrl'].startswith('https://governors.library.ca.gov/') for s in services))
        brown = next(p for p in data if p['name'] == 'Edmund G. "Jerry" Brown')
        self.assertEqual({s['startYear'] for s in brown['services']}, {1975, 2011})

    def test_refresh_retains_old_people_and_revision_history(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'history.json'
            output.write_text(json.dumps({'schemaVersion': 1, 'states': {'CA': {'people': [
                {'id': 'old-record', 'name': 'Retained person', 'services': [{'id': 'old', 'endYear': 1900}]},
                {'id': 'ca-test-person', 'name': 'Test Person', 'services': [{'id': 'ca-governor-1', 'ordinal': 1, 'period': '1849–1850', 'startYear': 1849, 'endYear': 1850, 'sourceUrl': m.SOURCE}]},
            ]}}}))
            with patch.object(m, 'OUTPUT', output), patch.object(m, 'fetch', return_value=b''), patch.object(m, 'records', return_value=[1]), patch.object(m, 'enrich', return_value=(1, 'Test Person', '1849–1851', m.SOURCE, 1849, 1851)):
                m.refresh()
            people = json.loads(output.read_text())['states']['CA']['people']
            self.assertTrue(any(p['id'] == 'old-record' for p in people))
            changed = next(p for p in people if p['id'] == 'ca-test-person')['services'][0]
            self.assertEqual(changed['endYear'], 1851)
            self.assertEqual(changed['revisions'][0]['endYear'], 1850)

    def test_incomplete_source_does_not_replace_archive(self):
        before = m.OUTPUT.read_bytes()
        with patch.object(m, 'fetch', return_value=b'<html>incomplete</html>'):
            with self.assertRaises(ValueError): m.refresh()
        self.assertEqual(m.OUTPUT.read_bytes(), before)

if __name__ == '__main__': unittest.main()
