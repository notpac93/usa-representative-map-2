from datetime import datetime, timezone
import hashlib
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from election_adapters import certified as c


class WyomingCertifiedAdapterTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.results = (ROOT / 'scripts/tests/fixtures/wy_2026_official_results.zip').read_bytes()

    def test_real_government_workbook_integrity_and_contest_coverage(self):
        self.assertEqual(hashlib.sha256(self.results).hexdigest(), c.WY_RESULTS_SHA256)
        contests = c.parse_wyoming_results(self.results)
        self.assertEqual(len(contests), 86)
        expected = {'United States Senator': ('Harriet Hageman', 122174),
                    'United States Representative': ('Chuck Gray', 99906),
                    'Governor': ('Eric Barlow', 128496)}
        for title, (name, votes) in expected.items():
            record = next(x for x in contests if x['officeTitle']==title)
            self.assertEqual((record['winner']['name'],record['winner']['votes']),(name,votes))
            self.assertEqual(record['certificationLevel'],'state')
        self.assertEqual(sum(x['officeKind']=='stateHouse' for x in contests),62)
        self.assertEqual(sum(x['officeKind']=='stateSenate' for x in contests),17)
        self.assertEqual(next(x for x in contests if x['officeTitle']=='Senate District 6')['electionType'],'special')

    def sample_rows(self):
        rows = {1:{2:'Statewide Candidates Official Summary Wyoming General Election - November 3, 2026'},
                3:{2:'Governor'},4:{2:'Fixture First (R)',3:'Fixture Second (D)',4:'Write-Ins',5:'Overvotes',6:'Undervotes'}}
        for n in range(5,28):rows[n]={1:'Fixture County '+str(n),2:'10',3:'1',4:'0',5:'0',6:'0'}
        rows[28]={1:'Total',2:'230',3:'23',4:'0',5:'0',6:'0'}
        return rows

    def test_county_sum_mismatch_is_blocked(self):
        rows=self.sample_rows();rows[28][2]='229'
        with self.assertRaisesRegex(ValueError,'county vote sum'):c._contests(rows,'Statewide Candidates Official Summary')

    def test_tie_and_unidentified_write_in_winners_require_review(self):
        for mode in ('tie','write-in'):
            rows=self.sample_rows()
            if mode=='tie':
                for n in range(5,28):rows[n][3]='10'
                rows[28][3]='230'
            else:
                for n in range(5,28):rows[n][4]='11'
                rows[28][4]='253'
            with self.assertRaisesRegex(ValueError,'tie/write-in'):c._contests(rows,'Statewide Candidates Official Summary')

    def test_partial_county_coverage_and_changed_year_are_rejected(self):
        rows=self.sample_rows();del rows[5]
        with self.assertRaisesRegex(ValueError,'23 counties'):c._contests(rows,'Statewide Candidates Official Summary')
        rows=self.sample_rows();rows[1][2]=rows[1][2].replace('2026','2024')
        with self.assertRaisesRegex(ValueError,'heading changed'):c._contests(rows,'Statewide Candidates Official Summary')

    def test_changed_scanned_certificate_never_gets_automatic_certification(self):
        raw={c.WY_RESULTS_PAGE:b'2026 Official General Election Results '+c.WY_RESULTS_ZIP.split('/')[-1].encode(),c.WY_CERTIFICATE:b'changed PDF'}
        with self.assertRaisesRegex(ValueError,'signed certification changed'):
            c.collect_wyoming(raw.__getitem__,datetime(2026,11,19,tzinfo=timezone.utc))

    def test_future_certification_and_naive_clock_are_rejected(self):
        with self.assertRaises(ValueError):c.collect_wyoming(lambda _:b'',datetime(2026,11,9,tzinfo=timezone.utc))
        with self.assertRaises(ValueError):c.collect_wyoming(lambda _:b'',datetime(2026,11,19))

    def test_certified_records_keep_civil_dates_separate_from_utc_instants(self):
        certificate=b'fixture certificate';constitution=b'fixture constitution';calendar=b'fixture calendar'
        values={c.WY_RESULTS_PAGE:b'2026 Official General Election Results '+c.WY_RESULTS_ZIP.split('/')[-1].encode(),
                c.WY_CERTIFICATE:certificate,c.WY_RESULTS_ZIP:self.results,c.WY_CONSTITUTION:constitution,c.WY_CALENDAR:calendar}
        with patch.object(c,'WY_CERTIFICATE_SHA256',c._sha(certificate)),patch.object(c,'WY_CONSTITUTION_SHA256',c._sha(constitution)),patch.object(c,'WY_CALENDAR_SHA256',c._sha(calendar)):
            result=c.collect_wyoming(values.__getitem__,datetime(2026,11,19,tzinfo=timezone.utc))
        self.assertEqual(result['certifiedOn'],'2026-11-10')
        self.assertEqual(result['certificationReview']['datePrecision'],'day')
        gov=next(x for x in result['contests'] if x['officeKind']=='governor')
        self.assertEqual(gov['scheduledStartDate'],'2027-01-04')
        self.assertEqual(gov['startTimeZone'],'America/Denver')
        self.assertNotIn('scheduledStart',gov)
        special=next(x for x in result['contests'] if x['electionType']=='special')
        self.assertNotIn('scheduledStartDate',special)
        self.assertEqual(result['coverage']['verifiedStateCivilStartDates'],83)
        self.assertEqual(len(result['sourceDocuments']),5)


if __name__=='__main__':unittest.main()
