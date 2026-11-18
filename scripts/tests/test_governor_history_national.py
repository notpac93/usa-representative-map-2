import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).parents[1]))
import import_governor_history as history


class NationalHistoryTest(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads(history.REVIEWED.read_text())

    def test_every_state_has_saved_verified_history(self):
        history.validate(self.manifest)
        archive = json.loads(history.OUTPUT.read_text())
        self.assertEqual(set(archive['states']), history.STATES)
        for state, data in archive['states'].items():
            self.assertTrue(data['people'], state)
            ids = []
            for person in data['people']:
                for service in person['services']:
                    ids.append(service['id'])
                    history.government_url(service['sourceUrl'])
                    self.assertLessEqual(service['startYear'], service['endYear'])
            self.assertEqual(len(ids), len(set(ids)), state)

    def test_nonconsecutive_service_stays_separate(self):
        archive = history.merge({'schemaVersion': 1, 'states': {}}, self.manifest)
        for state, name, years in [
            ('AK', 'William Allen Egan', {1959, 1970}),
            ('MO', 'Christopher S. Bond', {1973, 1981}),
            ('SD', 'William J. Janklow', {1979, 1995}),
            ('MN', 'Rudy Perpich', {1976, 1983}),
        ]:
            person = next(p for p in archive['states'][state]['people'] if p['name'] == name)
            self.assertEqual({s['startYear'] for s in person['services']}, years)

    def test_reimport_is_idempotent_and_removed_rows_are_retained(self):
        first = history.merge({'schemaVersion': 1, 'states': {}}, self.manifest)
        self.assertEqual(first, history.merge(first, self.manifest))
        changed = copy.deepcopy(self.manifest)
        removed = changed['states']['AK']['records'].pop()
        updated = history.merge(first, changed)
        services = [s for p in updated['states']['AK']['people'] for s in p['services']]
        self.assertIn(removed['id'], {s['id'] for s in services})

    def test_correction_preserves_previous_values_and_original_input(self):
        first = history.merge({'schemaVersion': 1, 'states': {}}, self.manifest)
        changed = copy.deepcopy(self.manifest)
        record = changed['states']['AK']['records'][0]
        record['period'] += ' (revised source wording)'
        updated = history.merge(first, changed)
        person = next(p for p in updated['states']['AK']['people'] if p['id'] == record['personId'])
        service = next(s for s in person['services'] if s['id'] == record['id'])
        self.assertEqual(len(service['revisions']), 1)
        self.assertNotIn('revised', service['revisions'][0]['period'])
        self.assertNotEqual(first, updated)
        self.assertEqual(updated, history.merge(updated, changed))

    def test_bad_source_unfinished_future_or_duplicate_rejects_entire_import(self):
        for value in ['https://example.org/archive', 'https://example.gov.evil.com',
                      'https://example.gov@evil.com', 'http://example.gov',
                      'https://example.gov:8080/archive']:
            with self.assertRaises(ValueError):
                history.government_url(value)
        for field, value in [('period', '2020-present'), ('endYear', 2099), ('startYear', 2100)]:
            changed = copy.deepcopy(self.manifest)
            changed['states']['AK']['records'][0][field] = value
            with self.assertRaises(ValueError):
                history.merge({'schemaVersion': 1, 'states': {}}, changed)
        changed = copy.deepcopy(self.manifest)
        changed['states']['AK']['records'].append(changed['states']['AK']['records'][0])
        with self.assertRaises(ValueError):
            history.validate(changed)


if __name__ == '__main__':
    unittest.main()
