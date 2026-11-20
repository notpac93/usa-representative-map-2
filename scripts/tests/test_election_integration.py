import copy
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
import refresh_federal_officials as federal
import election_results
from election_adapters import senate_elect
from election_adapters import mississippi

class ElectionIntegrationTest(unittest.TestCase):
    def setUp(self):
        self.snapshot=json.loads((ROOT/'assets/data/federal_officials.json').read_text())
        self.registry=json.loads((ROOT/'scripts/data/federal_sources.json').read_text())
        self.now=datetime(2026,11,19,20,tzinfo=timezone.utc)
        self.heading=b'<h1>2026 Senators-Elect Resume Collection</h1><h2>New Senators-Elect</h2><h3>Scott Colom (MS)</h3><h2>Other jobs</h2><h3>Someone Else (CA)</h3>'
        self.rule=b'and the terms of Senators and Representatives at noon on the 3d day of January, of the years in which such terms would have ended if this article had not been ratified; and the terms of their successors shall then begin.'
    def loader(self,url,source):return self.heading if url==senate_elect.URL else self.rule
    def test_recognition_is_official_incoming_not_certification(self):
        senate_elect.add_to_snapshot(self.snapshot,self.registry,self.loader,self.now,federal.evidence,federal.iso)
        t=next(t for t in self.snapshot['terms'] if t['status']=='incomingRecognized' and t['officeId']=='us:senate:MS:II')
        self.assertEqual(t['scheduledStart'],'2027-01-03T17:00:00Z')
        self.assertEqual(t['certificationStatus'],'notVerified')
        self.assertNotIn('certifiedAt',t)
        self.snapshot['publishedAt']=federal.iso(self.now)
        federal.validate(self.snapshot,self.registry)
        self.snapshot['publishedAt']='2027-01-03T18:00:00Z'
        federal.transition(self.snapshot)
        self.assertEqual(t['status'],'incomingRecognized')
    def test_ohio_special_start_is_not_january_third(self):
        self.heading=self.heading.replace(b'Scott Colom (MS)',b'Sherrod Brown (OH)')
        senate_elect.add_to_snapshot(self.snapshot,self.registry,self.loader,self.now,federal.evidence,federal.iso)
        t=next(t for t in self.snapshot['terms'] if t['status']=='incomingRecognized' and t['officeId']=='us:senate:OH:III')
        self.assertNotIn('scheduledStart',t)
        self.assertEqual(t['startDateStatus'],'awaiting_special_election_qualification')
    def test_recognition_never_downgrades_certified_term(self):
        senate_elect.add_to_snapshot(self.snapshot,self.registry,self.loader,self.now,federal.evidence,federal.iso)
        t=next(t for t in self.snapshot['terms'] if t['status']=='incomingRecognized')
        t['status']='incoming';t['certificationStatus']='certified'
        before=copy.deepcopy(t)
        senate_elect.add_to_snapshot(self.snapshot,self.registry,self.loader,self.now,federal.evidence,federal.iso)
        self.assertEqual(t,before)
    def test_all_state_directories_are_not_complete_contest_coverage(self):
        with patch.object(election_results,'add_certified'):
            coverage,_=election_results.collect(self.snapshot,self.registry,ROOT,lambda *args:b'Official results directory',self.now,federal.evidence,states=[])
        self.assertEqual(coverage['registeredStates'],50)
        self.assertFalse(coverage['complete'])
        self.assertTrue(all(s['contestCoverage']=='notImported' for s in coverage['states']))
    def test_scoped_result_source_cannot_certify_another_state(self):
        source=next(s for s in self.registry['sources'] if s['id']=='state-election-WY')
        self.assertEqual(source['states'],['WY'])
    def test_parsing_does_not_read_unrelated_heading(self):
        self.assertEqual(senate_elect.parse(self.heading),[{'name':'Scott Colom','state':'MS'}])

    def test_presidential_rule_alone_cannot_prove_a_congressional_start(self):
        self.rule = b'The terms of the President and Vice President shall end at noon on the 20th day of January'
        with self.assertRaisesRegex(ValueError, 'start rule missing'):
            senate_elect.add_to_snapshot(self.snapshot,self.registry,self.loader,self.now,federal.evidence,federal.iso)

    def test_partial_review_package_cannot_discard_a_native_state_report(self):
        native = {'certificationStatus': 'notVerified', 'contests': [{'id': 'native-MS-recognition'}], 'coverage': {}}
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'scripts/data').mkdir(parents=True)
            (root / 'scripts/data/state_election_sources.json').write_bytes((ROOT / 'scripts/data/state_election_sources.json').read_bytes())
            (root / 'scripts/data/election_result_reviews.json').write_text(json.dumps({'packages': [{'state': 'MS', 'electionDate': '2026-11-03'}]}))
            with patch.object(mississippi, 'collect_mississippi', return_value=native), patch.object(election_results, 'add_certified'):
                coverage, reports = election_results.collect(self.snapshot, self.registry, root, lambda *args: b'directory', self.now, federal.evidence, states=['MS'])
        self.assertEqual(reports['MS'], native)
        state = next(s for s in coverage['states'] if s['stateId'] == 'MS')
        self.assertIn('native adapter', state['reviewedImportError'])

if __name__=='__main__':unittest.main()
