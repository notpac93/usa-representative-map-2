"""Replay exact government JSON bytes archived November 20, 2026 UTC.

The ZIP preserves the two original responses (124 candidate rows), rather than
manufacturing an expected format from the implementation under test.
"""
import hashlib
import json
from pathlib import Path
import sys
import unittest
from datetime import datetime, timezone
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from election_adapters import delaware as de


class DelawareElectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with zipfile.ZipFile(Path(__file__).parent / 'fixtures/de_2026_official_results.zip') as fixture:
            cls.primary = fixture.read('Election_StatewideResults_ID_GE2026.json')
            cls.comparison = fixture.read('4hbv-7brf_GE2026.json')
        cls.law = (b'<p>The terms of Senators and Representatives begin on the day next after their election.</p>'
                   b'<p>The terms of office of all State and County officers made elective by this Constitution begin on '
                   b'the first Tuesday in January next after their election, unless otherwise provided in this Constitution.</p>')

    def changed(self, key, value):
        rows = json.loads(self.primary)
        rows[0][key] = value
        return json.dumps(rows).encode()

    def test_fixture_identity_and_actual_results(self):
        self.assertEqual(hashlib.sha256(self.primary).hexdigest(), '367f31e3cefd073544cf75ac51a6d1525e3c11b3fdf72218f6c635da6e9f48f0')
        self.assertEqual(hashlib.sha256(self.comparison).hexdigest(), 'e391cc6b9445884c0f2b6b2803ab3114b26e78a6d349fdd0140177c373befb71')
        contests, coverage = de.parse_results(self.primary, self.comparison)
        self.assertEqual(coverage['candidateRows'], 124)
        self.assertEqual(coverage['supportedContests'], 57)
        senate = next(c for c in contests if c['officeKind'] == 'senate')
        self.assertEqual(senate['leader']['name'], 'CHRIS COONS')
        self.assertEqual(senate['leader']['votes'], 240587)
        house = next(c for c in contests if c['officeKind'] == 'house')
        self.assertEqual(house['leader']['name'], 'SARAH MCBRIDE')
        self.assertEqual(house['leader']['votes'], 243687)
        self.assertEqual(sum(c['officeKind'] == 'stateSenate' for c in contests), 11)
        self.assertEqual(sum(c['officeKind'] == 'stateHouse' for c in contests), 41)
        self.assertTrue(all(not c['certified'] and c['scheduledStart'] is None and 'winner' not in c for c in contests))

    def test_publication_disagreement_fails_closed(self):
        for key, value in [('Total Votes', '240,588'), ('Machine Votes', '140,839'),
                           ('Total Votes', '-1'), ('Total Votes', '240,587oops'),
                           ('Election Date', '2024-11-05'), ('Precincts Reported', 529),
                           ('Results Type', 'CERTIFIED'), ('ReportTime', '2026-11-10T13:49:42')]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                de.parse_results(self.changed(key, value), self.comparison)

    def test_identical_omission_in_both_publications_fails_closed(self):
        primary = [r for r in json.loads(self.primary) if r['Contest Title'] != 'U.S. Senator']
        comparison = [r for r in json.loads(self.comparison) if r['office'] != 'U.S. Senator']
        with self.assertRaisesRegex(ValueError, 'inventory'):
            de.parse_results(json.dumps(primary).encode(), json.dumps(comparison).encode())

    def test_duplicate_candidates_are_rejected(self):
        rows = json.loads(self.primary)
        rows.append(rows[0])
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            de.parse_results(json.dumps(rows).encode(), self.comparison)

    def test_tied_contest_has_no_leader(self):
        primary, comparison = json.loads(self.primary), json.loads(self.comparison)
        tied = primary[0]['Total Votes']
        for row in primary[:2]:
            row.update({'Total Votes': tied, 'Machine Votes': tied, 'Absentee Votes': '0', 'Early Voting Votes': '0'})
        for row in comparison:
            if row['office'] == 'U.S. Senator':
                row.update({'totalvotessum': tied, 'machinevotessum': tied, 'absenteevotessum': '0', 'earlyvotessum': '0'})
        contests, _ = de.parse_results(json.dumps(primary).encode(), json.dumps(comparison).encode())
        self.assertIsNone(next(c for c in contests if c['officeKind'] == 'senate')['leader'])

    def test_law_preserves_date_precision_and_review(self):
        rules = de.parse_start_rules(self.law)
        self.assertIsNone(rules['legislative']['scheduledStartDate'])
        self.assertEqual(rules['executive']['scheduledStartDate'], '2027-01-05')
        self.assertEqual(rules['executive']['datePrecision'], 'day')
        self.assertFalse(rules['executive']['actualAssumptionVerified'])
        with self.assertRaises(ValueError):
            de.parse_start_rules(b'<p>Terms begin on another day.</p>')

    def test_collector_archives_and_does_not_certify(self):
        sources = {de.RESULTS_JSON_URL: self.primary, de.CROSSCHECK_URL: self.comparison, de.CONSTITUTION_URL: self.law}
        report = de.collect_delaware(sources.__getitem__, datetime(2026, 11, 20, tzinfo=timezone.utc))
        self.assertEqual(len(report['contests']), 57)
        self.assertFalse(report['errors'])
        self.assertEqual(report['certificationStatus'], 'official_results_certification_unverified')
        self.assertTrue(all(len(d['sha256']) == 64 for d in report['sourceDocuments']))
        executive = next(c for c in report['contests'] if c['officeKind'] == 'stateExecutive')
        self.assertEqual(executive['startDateEvidence']['scheduledStartDate'], '2027-01-05')
        self.assertIsNone(executive['scheduledStart'])

    def test_collector_preserves_failure_without_partial_results(self):
        sources = {de.RESULTS_JSON_URL: self.primary, de.CROSSCHECK_URL: b'[]', de.CONSTITUTION_URL: self.law}
        report = de.collect_delaware(sources.__getitem__, datetime(2026, 11, 20, tzinfo=timezone.utc))
        self.assertFalse(report['contests'])
        self.assertTrue(report['errors'])
        self.assertEqual(len(report['sourceDocuments']), 3)
        with self.assertRaises(ValueError):
            de.collect_delaware(sources.__getitem__, datetime(2026, 11, 20))


if __name__ == '__main__':
    unittest.main()
