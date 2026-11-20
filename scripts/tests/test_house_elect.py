"""Recognition intake tests use synthetic names and seats, never candidate results."""
import copy
from datetime import datetime, timezone
import hashlib
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from election_adapters import house_elect as house


def fixture(*, count=40, date='2026-11-11', before='', after='', rows=None):
    rows = rows if rows is not None else [f'<li>Fixture Member {n} (CA-{n:02})</li>' for n in range(1, count + 1)]
    return (f'<html><head><meta name="date" content="{date}"></head><body>{before}'
            '<div id="newscontent"><h1>New Dems Welcome 40 New Members, Coalition Grows to Record 142 Members</h1>'
            '<p>The following Members-Elect were admitted to the Coalition during the reviewed meeting:</p><ul>'
            + ''.join(rows) + '</ul>' + after + '</div></body></html>').encode('utf-8')


def evidence(source, raw, now, oid, pid, claim, excerpt):
    key = hashlib.sha256((oid + pid + claim + source['id']).encode()).hexdigest()
    return {'id': key, 'sourceId': source['id'], 'url': source['url'], 'officeId': oid,
            'personId': pid, 'claim': claim, 'excerpt': excerpt,
            'sha256': hashlib.sha256(raw).hexdigest(), 'retrievedAt': now.isoformat()}


class HouseRecognitionTest(unittest.TestCase):
    def test_exact_bounded_caucus_list(self):
        decoy = '<ul><li>Not Elected (NY-01)</li></ul>'
        entries = house.parse(fixture(before=decoy, after=decoy))
        self.assertEqual(len(entries), 40)
        self.assertEqual(entries[0], {'name': 'Fixture Member 1', 'state': 'CA', 'district': 1})
        self.assertFalse(house.COVERAGE['completeHouseRoster'])
        self.assertFalse(house.COVERAGE['includesReelectedMembers'])
        self.assertEqual(house.COVERAGE['certificationLevel'], 'government_recognition_only')
        self.assertTrue(all(set(p) == {'name', 'state', 'district'} for p in entries))

    def test_inline_markup_and_character_entities(self):
        rows = [f'<li><p>Fixture Member {n} (CA-{n:02})</p></li>' for n in range(1, 41)]
        rows[0] = '<li><strong>Jos&eacute; Fixture</strong> (CA-01)</li>'
        self.assertEqual(house.parse(fixture(rows=rows))[0]['name'], 'José Fixture')

    def test_old_or_missing_source_edition_and_count_fail_closed(self):
        for raw in [fixture(date='2024-11-11'), fixture(count=39), fixture(count=41),
                    fixture().replace(b'New Dems Welcome 40', b'Candidate Filing 40'),
                    fixture().replace(b'id="newscontent"', b'id="unrelated"'),
                    fixture().replace(b'The following Members-Elect were admitted to the Coalition', b'Candidates who might run'),
                    b'<html><h1>Error</h1></html>']:
            with self.subTest(raw=raw[:80]):
                with self.assertRaises(ValueError): house.parse(raw)

    def test_missing_name_invalid_state_duplicate_seat_and_nested_lists_fail(self):
        for replacement in ['Fixture Member 1 (XX-01)', 'Fixture Member 1 (CA-00-extra)',
                            'Fixture Member 2 (CA-02)', '(CA-01)',
                            '<ul><li>Nested Fixture (CA-01)</li></ul>']:
            raw = fixture().replace(b'Fixture Member 1 (CA-01)', replacement.encode())
            with self.subTest(replacement=replacement):
                with self.assertRaises(ValueError): house.parse(raw)

    def snapshot(self):
        return {'people': [{'id': f'old-{n}', 'name': f'Serving Member {n}'} for n in range(1, 41)],
                'offices': [{'id': f'us:house:CA{n:02}', 'kind': 'house', 'state': 'CA', 'district': n} for n in range(1, 41)],
                'terms': [{'id': f'old-term-{n}', 'officeId': f'us:house:CA{n:02}', 'personId': f'old-{n}', 'status': 'current',
                           'scheduledEnd': '2027-01-03T17:00:00Z', 'evidenceIds': []} for n in range(1, 41)],
                'evidence': []}

    def add(self, snapshot, *, raw=None, rule=None):
        registry = {'sources': [{'id': house.SOURCE_ID, 'url': house.URL}, {'id': 'constitution', 'url': 'https://www.archives.gov/founding-docs/amendments-11-27'}]}
        rule = rule if rule is not None else b'and the terms of Senators and Representatives at noon on the 3d day of January, of the years in which such terms would have ended if this article had not been ratified; and the terms of their successors shall then begin.'
        raw = raw if raw is not None else fixture()
        seen = []
        def fetch(url, source):
            seen.append((url, source['id']))
            return raw if url == house.URL else rule
        house.add_to_snapshot(snapshot, registry, fetch, datetime(2026, 11, 19, tzinfo=timezone.utc), evidence, lambda d: d.isoformat().replace('+00:00', 'Z'))
        return seen

    def test_adds_recognition_and_verified_regular_start_without_changing_current(self):
        snapshot = self.snapshot()
        seen = self.add(snapshot)
        self.assertEqual(seen[0], (house.URL, house.SOURCE_ID))
        current = [t for t in snapshot['terms'] if t['status'] == 'current']
        recognized = [t for t in snapshot['terms'] if t['status'] == 'incomingRecognized']
        self.assertEqual(len(current), 40)
        self.assertEqual(len(recognized), 40)
        self.assertTrue(all(t['scheduledStart'] == '2027-01-03T17:00:00Z' for t in recognized))
        self.assertTrue(all(t['certificationStatus'] == 'notVerified' and 'certifiedAt' not in t and 'actualStart' not in t for t in recognized))
        self.assertEqual({e['claim'] for e in snapshot['evidence']}, {'incomingRecognition', 'scheduledStart'})
        self.assertTrue(all('party' not in p and 'phone' not in p for p in snapshot['people']))

    def test_repeat_is_idempotent_and_preserves_first_recognition(self):
        snapshot = self.snapshot()
        self.add(snapshot)
        first = copy.deepcopy(snapshot)
        self.add(snapshot)
        self.assertEqual(snapshot, first)

    def test_does_not_revive_closed_or_downgrade_certified_terms(self):
        for status in ('current', 'ended', 'withdrawn', 'disputed', 'incoming'):
            snapshot = self.snapshot()
            self.add(snapshot)
            changed = next(t for t in snapshot['terms'] if t['status'] == 'incomingRecognized')
            changed['status'] = status
            changed['certifiedAt'] = '2026-11-18T17:00:00Z'
            before = copy.deepcopy(changed)
            self.add(snapshot)
            self.assertEqual(next(t for t in snapshot['terms'] if t['id'] == changed['id']), before)

    def test_unknown_district_and_missing_term_rule_are_blocked(self):
        snapshot = self.snapshot()
        snapshot['offices'][0]['district'] = 9
        with self.assertRaisesRegex(ValueError, 'Unmatched'): self.add(snapshot)
        snapshot = self.snapshot()
        snapshot['terms'][0]['scheduledEnd'] = '2029-01-03T17:00:00Z'
        with self.assertRaisesRegex(ValueError, 'cycle not corroborated'): self.add(snapshot)
        with self.assertRaisesRegex(ValueError, 'start rule missing'): self.add(self.snapshot(), rule=b'Unrelated archives page')


if __name__ == '__main__': unittest.main()
