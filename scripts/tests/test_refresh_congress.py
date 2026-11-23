import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

SPEC = importlib.util.spec_from_file_location('refresh_congress', Path(__file__).parents[1] / 'refresh_congress.py')
pipeline = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pipeline)


class CongressImportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bodies, cls.manifest = pipeline.read_snapshot(pipeline.ROOT / 'data/sources/congress')

    def build(self, bodies=None, congress=119):
        return pipeline.build(bodies or self.bodies, self.manifest, congress)

    def test_official_snapshot_has_all_seats_and_explicit_vacancies(self):
        result = self.build()
        house = [r for g in result['house'] for r in g['representatives']]
        senate = [r for g in result['senate'] for r in g['senators']]
        self.assertEqual(len(house) + len(result['vacancies']), 441)
        self.assertEqual(len(senate), 100)
        self.assertEqual(len(result['house']), 56)
        for state, count in [('CO', 8), ('CT', 5), ('DE', 1)]:
            self.assertEqual(sum(r['stateId'] == state for r in house), count)
        self.assertTrue(any(r['officeId'] == 'house:AS00' for r in house))
        self.assertTrue(all(r['email'] is None and r['fax'] is None for r in house + senate))
        self.assertTrue(all(r['contactUrl'].startswith(('https:', 'http:')) for r in senate))
        self.assertFalse(result['delivery']['configured'])

    def test_missing_house_seat_rejected(self):
        bodies = dict(self.bodies)
        root = ET.fromstring(bodies['house.xml'])
        members = root.find('members')
        members.remove(members[0])
        bodies['house.xml'] = ET.tostring(root)
        with self.assertRaisesRegex(ValueError, 'Incomplete House seat coverage'):
            self.build(bodies)

    def test_duplicate_house_identity_rejected(self):
        bodies = dict(self.bodies)
        root = ET.fromstring(bodies['house.xml'])
        members = root.findall('members/member')
        members[1].find('member-info/bioguideID').text = members[0].findtext('member-info/bioguideID')
        bodies['house.xml'] = ET.tostring(root)
        with self.assertRaisesRegex(ValueError, 'duplicate House Bioguide'):
            self.build(bodies)

    def test_missing_identity_is_not_automatically_a_vacancy(self):
        bodies = dict(self.bodies)
        root = ET.fromstring(bodies['house.xml'])
        info = root.find('members/member/member-info')
        info.find('bioguideID').text = ''
        info.find('official-name').text = ''
        bodies['house.xml'] = ET.tostring(root)
        with self.assertRaisesRegex(ValueError, 'Unexplained missing House member'):
            self.build(bodies)

    def test_partial_senate_response_rejected(self):
        bodies = dict(self.bodies)
        root = ET.fromstring(bodies['senate.xml'])
        root.remove(root[0])
        bodies['senate.xml'] = ET.tostring(root)
        with self.assertRaisesRegex(ValueError, 'Incomplete Senate coverage'):
            self.build(bodies)

    def test_directory_occupant_conflict_rejected(self):
        bodies = dict(self.bodies)
        bodies['house-directory.html'] = bodies['house-directory.html'].replace(b'Begich, Nicholas', b'Different, Person')
        with self.assertRaisesRegex(ValueError, 'disagree on occupant'):
            self.build(bodies)

    def test_unreviewed_congress_rollover_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Unexpected House Congress'):
            self.build(congress=120)

    def test_nonofficial_contact_url_rejected(self):
        bodies = dict(self.bodies)
        root = ET.fromstring(bodies['senate.xml'])
        root.find('member/email').text = 'https://senate.gov.attacker.example/contact'
        bodies['senate.xml'] = ET.tostring(root)
        with self.assertRaisesRegex(ValueError, 'Unexpected official URL'):
            self.build(bodies)

    def test_offline_rebuild_is_deterministic_and_does_not_reset_retrieval_time(self):
        self.assertEqual(self.build(), self.build())
        self.assertEqual(self.build()['retrievedAt'], self.manifest['retrievedAt'])

    def test_portrait_does_not_follow_a_replaced_officeholder(self):
        result = pipeline.build(self.bodies, self.manifest, 119, {'REMOVED': {'photoLocalPath': 'old.jpg'}})
        self.assertFalse(any(r.get('photoLocalPath') == 'old.jpg' for g in result['house'] for r in g['representatives']))

    def test_atomic_snapshot_write_and_failed_validation_preserve_previous(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'roster.json'
            pipeline.atomic_json(path, {'version': 'last-good'})
            with self.assertRaises(ValueError):
                pipeline.atomic_json(path, self.build(congress=120))
            self.assertEqual(json.loads(path.read_text()), {'version': 'last-good'})
            self.assertEqual(list(Path(directory).iterdir()), [path])


if __name__ == '__main__':
    unittest.main()
