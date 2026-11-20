"""Incoming terms keep stable identities and independently bound source history."""
import copy
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import election_results
import federal_data_pipeline as pipeline
import refresh_federal_officials as federal
from election_adapters import reviewed

NOW = datetime(2026, 11, 19, 20, tzinfo=timezone.utc)


def report_for(contests, state='CA'):
    certificate = {'url': 'https://elections.example.gov/certificate', 'sha256': 'a' * 64, 'role': 'certification'}
    results = {'url': 'https://elections.example.gov/results', 'sha256': 'b' * 64, 'role': 'results'}
    values = []
    for contest in contests:
        values.append({'id': '2026:' + contest['officeId'], 'state': state, 'electionDate': '2026-11-03',
                       'electionType': 'general', 'district': None, 'certifiedOn': '2026-11-10',
                       'certificationDocumentUrl': certificate['url'], 'certificationDocumentSha256': certificate['sha256'],
                       'resultDocumentUrl': results['url'], 'resultDocumentSha256': results['sha256'], **contest})
    return {'state': state, 'certificationStatus': 'certified', 'contests': values,
            'sourceDocuments': [certificate, results]}


class ElectionIdentityRegressionTest(unittest.TestCase):
    def setUp(self):
        self.registry = json.loads((ROOT / 'scripts/data/federal_sources.json').read_text())
        self.registry['sources'].append({'id': 'test-election', 'url': 'https://elections.example.gov/certificate',
                                        'hosts': ['elections.example.gov'], 'states': ['CA'],
                                        'officeKinds': ['house'], 'claims': ['certification']})
        for source in self.registry['sources']:
            if source['id'].startswith('state-election-'):
                source['hosts'].append('elections.example.gov')

    def empty(self):
        return {'schemaVersion': 1, 'publishedAt': federal.iso(NOW),
                'people': [], 'offices': [], 'terms': [], 'evidence': []}

    def test_reviewed_state_and_judicial_office_ids_are_preserved(self):
        snapshot = self.empty()
        contests = [{'officeId': 'state:MS:governor', 'officeKind': 'governor', 'officeTitle': 'Governor', 'winner': {'name': 'Fixture Governor'}},
                    {'officeId': 'state:MS:stateJudge:seat-1', 'officeKind': 'stateJudge', 'officeTitle': 'Supreme Court Justice', 'winner': {'name': 'Fixture Judge One'}},
                    {'officeId': 'state:MS:stateJudge:seat-2', 'officeKind': 'stateJudge', 'officeTitle': 'Supreme Court Justice', 'winner': {'name': 'Fixture Judge Two'}}]
        election_results.add_certified(snapshot, self.registry, {'MS': report_for(contests, 'MS')}, NOW, None)
        self.assertEqual({o['id'] for o in snapshot['offices']}, {'us:'+c['officeId'] for c in contests})
        self.assertTrue(all(o['branch'] == 'judicial' for o in snapshot['offices'] if o['kind'] == 'stateJudge'))
        federal.validate(snapshot, self.registry)

    def test_unidentified_judicial_seat_and_unsupported_local_kind_are_rejected(self):
        for kind in ('stateJudge', 'county'):
            contest = {'officeId': 'state:MS:test', 'officeKind': kind, 'officeTitle': 'Fixture Office', 'winner': {'name': 'Fixture Winner'}}
            result = report_for([contest], 'MS')
            if kind == 'stateJudge': result['contests'][0].pop('officeId')
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                election_results.add_certified(self.empty(), self.registry, {'MS': result}, NOW, None)
        self.assertEqual(reviewed.KINDS, set(election_results.KINDS))
        for supplied in ('state:MS:garbage','us:state:MS:governor:second-seat','state:NY:governor'):
            with self.subTest(supplied=supplied),self.assertRaises(ValueError):
                election_results.state_office_id({'officeId':supplied,'officeKind':'governor'},'MS')

    def test_reelection_reuses_person_but_retains_distinct_term_and_metadata(self):
        snapshot = self.empty()
        person = {'id': 'A000001', 'name': 'Fixture Incumbent', 'bioguideId': 'A000001',
                  'photoLocalPath': 'assets/official.jpg', 'party': 'I'}
        snapshot['people'].append(copy.deepcopy(person))
        oid = 'us:house:CA01'
        snapshot['offices'].append({'id': oid, 'state': 'CA', 'kind': 'house', 'district': 1})
        source = next(s for s in self.registry['sources'] if s['id'] == 'house-clerk')
        current = federal.evidence(source, b'Fixture sworn roster', NOW, oid, person['id'], 'current')
        rule_source = next(s for s in self.registry['sources'] if s['id'] == 'constitution')
        congress_rule='and the terms of Senators and Representatives at noon on the 3d day of January, of the years in which such terms would have ended if this article had not been ratified; and the terms of their successors shall then begin.'
        rule = federal.evidence(rule_source, b'Fixture constitutional rule', NOW, oid, person['id'], 'scheduledEnd',congress_rule)
        snapshot['evidence'] = [current, rule]
        snapshot['terms'] = [{'id': 'current-term', 'officeId': oid, 'personId': person['id'], 'status': 'current',
                              'evidenceIds': [current['id'], rule['id']], 'scheduledEnd': '2027-01-03T17:00:00Z'}]
        report = report_for([{'officeId': oid, 'officeKind': 'house', 'officeTitle': 'U.S. Representative', 'district': 1,
                              'winner': {'name': 'FIXTURE INCUMBENT', 'party': 'Independent'}}])
        election_results.add_certified(snapshot, self.registry, {'CA': report}, NOW, None)
        self.assertEqual(snapshot['people'], [person])
        incoming = next(t for t in snapshot['terms'] if t['status'] == 'incoming')
        self.assertEqual(incoming['personId'], person['id'])
        self.assertNotEqual(incoming['id'], 'current-term')
        self.assertEqual(len(snapshot['terms']), 2)
        federal.validate(snapshot, self.registry)
        version = pipeline.version(snapshot)
        later=NOW + federal.timedelta(hours=1)
        for proof in snapshot['evidence']:
            if proof['sourceId']=='constitution':proof['retrievedAt']=federal.iso(later)
        election_results.add_certified(snapshot, self.registry, {'CA': report}, later, None)
        self.assertEqual(pipeline.version(snapshot), version)
        self.assertEqual(snapshot['people'], [person])

    def test_explicit_civil_rule_does_not_receive_federal_default_instant(self):
        snapshot = self.empty()
        # An existing constitutional observation must not override a separately
        # reviewed office-specific start rule supplied by the result adapter.
        snapshot['evidence'] = [{'id': 'old-rule', 'sourceId': 'constitution', 'sha256': 'c' * 64}]
        contest = {'officeId': 'us:house:CA01', 'officeKind': 'house', 'officeTitle': 'U.S. Representative', 'district': 1,
                   'winner': {'name': 'Fixture Winner'}, 'scheduledStartDate': '2027-01-03', 'startTimeZone': 'America/New_York',
                   'startRule': {'url': 'https://elections.example.gov/law', 'sha256': 'd' * 64, 'excerpt': 'Fixture civil-date rule'}}
        election_results.add_certified(snapshot, self.registry, {'CA': report_for([contest])}, NOW, None)
        term = snapshot['terms'][0]
        self.assertEqual(term['scheduledStartDate'], '2027-01-03')
        self.assertNotIn('scheduledStart', term)
        self.assertEqual(term['startTimeZone'], 'America/New_York')

    def test_presidency_rule_cannot_supply_congress_start_evidence(self):
        snapshot=self.empty()
        snapshot['evidence']=[{'id':'presidency-only','sourceId':'constitution','sha256':'c'*64,
                               'retrievedAt':federal.iso(NOW),
                               'excerpt':'The terms of the President and Vice President shall end at noon on the 20th day of January'}]
        contest={'officeId':'us:house:CA01','officeKind':'house','officeTitle':'U.S. Representative','district':1,
                 'winner':{'name':'Fixture Winner'}}
        election_results.add_certified(snapshot,self.registry,{'CA':report_for([contest])},NOW,None)
        self.assertEqual(snapshot['terms'][0]['status'],'incomingRecognized')
        self.assertNotIn('scheduledStart',snapshot['terms'][0])

    def test_future_certification_and_missing_zone_and_mixed_precision_fail_validation(self):
        base = json.loads((ROOT / 'scripts/tests/fixtures/federal_transition.json').read_text())
        for change in ('future-certification', 'missing-zone', 'mixed-precision'):
            snapshot = copy.deepcopy(base)
            term = snapshot['terms'][1]
            if change == 'future-certification':
                term.update(status='incomingRecognized', recognizedAt=snapshot['publishedAt'],
                            certificationStatus='certified', certifiedAt='2030-01-01T00:00:00Z')
            else:
                term['scheduledStartDate'] = '2027-01-03'
                if change == 'missing-zone': term.pop('scheduledStart')
                else: term['startTimeZone'] = 'America/New_York'
            with self.subTest(change=change), self.assertRaises(ValueError):
                federal.validate(snapshot, self.registry)

    def test_roster_resolves_incoming_identity_without_losing_its_evidence(self):
        def feeds(congress=119, sworn='20250103', expiry=2027):
            members = ''.join(f'<member><statedistrict>{["CA","TX","FL","NY"][n//100]}{n%100:02}</statedistrict><member-info><bioguideID>A{n:06}</bioguideID><official-name>Fixture House {n}</official-name><sworn-date date="{sworn}"/></member-info></member>' for n in range(400))
            senate = ''.join(f'<member><bioguide_id>B{n:06}</bioguide_id><state>{chr(65+(n//2)//26)}{chr(65+(n//2)%26)}</state><class>Class {["I","II"][n%2]}</class><first_name>Fixture</first_name><last_name>Senate {n}</last_name></member>' for n in range(90))
            values = {'house-clerk': f'<MemberData><title-info><congress-num>{congress}</congress-num></title-info><members>{members}</members></MemberData>',
                      'senate-roster': '<contact_information>' + senate + '</contact_information>',
                      'constitution': 'The terms of the President and Vice President shall end at noon on the 20th day of January and the terms of Senators and Representatives at noon on the 3d day of January, of the years in which such terms would have ended if this article had not been ratified; and the terms of their successors shall then begin.'}
            for klass, year in [('I', 2031), ('II', expiry), ('III', 2029)]:
                values['senate-term-' + klass] = f'Class {klass} - Senators Whose Terms of Service Expire in {year}'
            return lambda url, source: values[source['id']].encode()
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'assets/data').mkdir(parents=True)
            (root / 'scripts/data').mkdir(parents=True)
            for filename in ('senators.json', 'houseMembers.json'):
                (root / 'assets/data' / filename).write_text('[]')
            (root / 'scripts/data/federal_reviewed_offices.json').write_text('[]')
            plans = {'people': [], 'offices': [], 'terms': [], 'evidence': []}
            with patch.object(federal, 'ROOT', root):
                complete=feeds()
                presidency_only=lambda url,source:(b'The terms of the President and Vice President shall end at noon on the 20th day of January' if source['id']=='constitution' else complete(url,source))
                with self.assertRaisesRegex(ValueError,'Congress term-start'):
                    federal.refresh(None,self.registry,plans,NOW,presidency_only)
                first = federal.refresh(None, self.registry, plans, NOW, feeds())
                first['people'].append({'id': 'incoming-alias', 'name': 'Fixture House 0', 'photoLocalPath': 'assets/official.jpg'})
                proof_source = next(s for s in self.registry['sources'] if s['id'] == 'test-election')
                cert = federal.evidence(proof_source, b'Fixture certified result', NOW, 'us:house:CA00', 'incoming-alias', 'certification')
                rule_source = next(s for s in self.registry['sources'] if s['id'] == 'constitution')
                start = federal.evidence(rule_source, b'Fixture start rule', NOW, 'us:house:CA00', 'incoming-alias', 'scheduledStart')
                first['evidence'].extend([cert, start])
                first['terms'].append({'id': 'reelected-next-term', 'officeId': 'us:house:CA00', 'personId': 'incoming-alias',
                                       'status': 'incoming', 'certificationStatus': 'certified', 'certifiedAt': federal.iso(NOW),
                                       'scheduledStart': '2027-01-03T17:00:00Z', 'evidenceIds': [cert['id'], start['id']]})
                second = federal.refresh(first, self.registry, plans, NOW + federal.timedelta(hours=1), feeds())
                term = next(t for t in second['terms'] if t['id'] == 'reelected-next-term')
                self.assertEqual(term['personId'], 'A000000')
                self.assertEqual(term['status'], 'incoming')
                proofs = {p['id']: p for p in second['evidence']}
                self.assertTrue(all(proofs[p]['personId'] == term['personId'] for p in term['evidenceIds']))
                self.assertEqual(cert['personId'], 'incoming-alias')  # Original source history was not mutated.
                third = federal.refresh(second, self.registry, plans, NOW + federal.timedelta(hours=2), feeds())
                self.assertEqual(pipeline.version(second), pipeline.version(third))
                def partial_failure(candidate, *args):
                    candidate['people'].append({'id':'partial-import','name':'Must Not Be Committed'})
                    candidate['terms'].clear()
                    raise ValueError('Fixture source parsing changed')
                with patch('election_adapters.senate_elect.add_to_snapshot', side_effect=partial_failure):
                    optional = federal.refresh(third, self.registry, plans, NOW + federal.timedelta(hours=3), feeds(), include_elections=True)
                self.assertNotIn('partial-import', {p['id'] for p in optional['people']})
                self.assertEqual({t['id'] for t in optional['terms']}, {t['id'] for t in third['terms']})
                self.assertTrue(all(c['status']=='unavailable' for c in optional['incomingSourceCoverage']))
                promoted = federal.refresh(third, self.registry, plans, datetime(2027, 1, 3, 18, tzinfo=timezone.utc), feeds(120, '20270103', 2033))
                term = next(t for t in promoted['terms'] if t['id'] == 'reelected-next-term')
                self.assertEqual(term['status'], 'current')
                proofs = {p['id']: p for p in promoted['evidence']}
                self.assertTrue({'current', 'certification', 'scheduledStart'} <= {proofs[p]['claim'] for p in term['evidenceIds']})
                person = next(p for p in promoted['people'] if p['id'] == 'A000000')
                self.assertEqual(person['bioguideId'], 'A000000')
                self.assertEqual(person['photoLocalPath'], 'assets/official.jpg')

    def test_repeated_state_check_preserves_first_recognition_time(self):
        from election_adapters import mississippi
        snapshot=self.empty()
        old='2026-11-12T20:00:00Z'
        snapshot['electionResults']=[{'id':'2026-MS-SENATE','governmentRecognizedIncoming':{'name':'Scott Colom','recognizedAt':old}}]
        report={'certificationStatus':'statewide_declaration_not_verified','contests':[
            {'id':'2026-MS-SENATE','officeKind':'senate','district':None,
             'governmentRecognizedIncoming':{'name':'Scott Colom','recognizedAt':federal.iso(NOW)}}],
            'sourceDocuments':[],'coverage':{}}
        with patch.object(mississippi,'collect_mississippi',return_value=report):
            election_results.collect(snapshot,self.registry,ROOT,lambda *args:b'Fixture government source',NOW,federal.evidence,states=['MS'])
        self.assertEqual(snapshot['electionResults'][0]['governmentRecognizedIncoming']['recognizedAt'],old)


if __name__ == '__main__':
    unittest.main()
