import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('federal', ROOT / 'scripts/refresh_federal_officials.py')
f = importlib.util.module_from_spec(spec)
spec.loader.exec_module(f)

class FederalTransitionsTest(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((ROOT / 'scripts/tests/fixtures/federal_transition.json').read_text())
        self.registry = json.loads((ROOT / 'scripts/data/federal_sources.json').read_text())
        self.registry['sources'].append({'id':'test-election','name':'Fixture election office','url':'https://elections.example.gov/certified','hosts':['elections.example.gov'],'officeKinds':['house'],'states':['CA'],'claims':['certification']})

    def assumption(self, actual='2027-01-03T17:00:00Z'):
        self.data['evidence'].append({**self.data['evidence'][0], 'id':'assumed','personId':'next','claim':'assumedOffice','retrievedAt':self.data['publishedAt']})
        t = self.data['terms'][1]
        t['evidenceIds'].append('assumed')
        t['actualStart'] = actual

    def test_valid_certified_incoming(self):
        f.validate(self.data, self.registry)
        self.assertEqual(f.transition(self.data)['terms'][1]['status'], 'incoming')

    def test_clock_alone_never_promotes(self):
        self.data['publishedAt'] = '2027-01-03T17:00:00Z'
        f.transition(self.data)
        self.assertEqual([t['status'] for t in self.data['terms']], ['ended','incoming'])

    def test_fresh_assumption_promotes_and_is_idempotent(self):
        self.data['publishedAt'] = '2027-01-03T18:00:00Z'
        self.assumption()
        f.validate(self.data, self.registry)
        f.transition(self.data)
        f.validate(self.data, self.registry)
        self.assertEqual([t['status'] for t in self.data['terms']], ['ended','current'])
        once = copy.deepcopy(self.data)
        self.assertEqual(f.transition(self.data), once)

    def test_no_early_promotion(self):
        self.assumption()
        f.transition(self.data)
        self.assertEqual(self.data['terms'][1]['status'],'incoming')
        with self.assertRaises(ValueError): f.validate(self.data,self.registry)

    def test_stale_assumption_does_not_promote(self):
        self.data['publishedAt']='2027-01-06T17:00:00Z'
        self.assumption()
        self.data['evidence'][-1]['retrievedAt']='2027-01-03T17:00:00Z'
        f.transition(self.data)
        self.assertEqual(self.data['terms'][1]['status'],'incoming')

    def test_disputed_term_never_promotes(self):
        self.data['publishedAt']='2027-01-03T18:00:00Z'
        self.assumption()
        self.data['terms'][1]['status']='disputed'
        f.transition(self.data)
        self.assertEqual(self.data['terms'][1]['status'],'disputed')

    def test_duplicate_current_rejected(self):
        self.data['terms'][1]['status']='current'
        self.data['evidence'][2]['claim']='current'
        with self.assertRaises(ValueError): f.validate(self.data,self.registry)

    def test_uncertified_and_wrong_identity_rejected(self):
        for change in ('missing-cert','wrong-person','wrong-jurisdiction','bad-host','unverified-end','future-proof'):
            with self.subTest(change=change):
                data=copy.deepcopy(self.data)
                if change=='missing-cert': data['terms'][1]['evidenceIds']=['start-proof']
                if change=='wrong-person': data['evidence'][2]['personId']='current'
                if change=='wrong-jurisdiction': data['offices'][0]['state']='NY'
                if change=='bad-host': data['evidence'][2]['url']='https://elections.example.gov.attacker.com/certified'
                if change=='unverified-end': data['terms'][0]['evidenceIds']=['current-proof']
                if change=='future-proof': data['evidence'][0]['retrievedAt']='2030-01-01T00:00:00Z'
                with self.assertRaises(ValueError): f.validate(data,self.registry)

    def test_parse_coverage_failure(self):
        with self.assertRaises(ValueError): f.parse_house(b'<MemberData><title-info><congress-num>119</congress-num></title-info><members/></MemberData>')
        with self.assertRaises(ValueError): f.parse_senate(b'<contact_information/>')

    def test_invalid_baseline_preserves_published_file(self):
        # Fixture authority is not in the production registry: the compatibility CLI must fail closed.
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'snapshot.json'
            path.write_text(json.dumps(self.data))
            before=path.read_bytes()
            with patch('sys.argv',['refresh','--snapshot',str(path),'--runs-dir',str(Path(temp)/'runs')]):
                self.assertEqual(f.main(),1)
            self.assertEqual(path.read_bytes(),before)

    def test_repeated_collection_and_reelection_preserve_distinct_terms(self):
        # Synthetic complete feeds exercise the publisher; no network or real candidate claims.
        def feeds(congress=119, sworn='20250103', class_two=2027):
            house='<MemberData><title-info><congress-num>'+str(congress)+'</congress-num></title-info><members>'
            for n in range(400):
                seat=['CA','TX','FL','NY'][n//100]+f'{n%100:02}'
                house+=f'<member><statedistrict>{seat}</statedistrict><member-info><bioguideID>A{n:06}</bioguideID><official-name>Fixture House {n}</official-name><party>I</party><sworn-date date="{sworn}"/></member-info></member>'
            house+='</members></MemberData>'
            senate='<contact_information>'
            for n in range(90):
                state=chr(65+(n//2)//26)+chr(65+(n//2)%26)
                klass=['I','II'][n%2]
                senate+=f'<member><bioguide_id>B{n:06}</bioguide_id><state>{state}</state><class>Class {klass}</class><first_name>Fixture</first_name><last_name>Senate {n}</last_name></member>'
            senate+='</contact_information>'
            values={'house-clerk':house,'senate-roster':senate,'constitution':'The terms of the President and Vice President shall end at noon on the 20th day of January'}
            for klass,year in [('I',2031),('II',class_two),('III',2029)]:
                values['senate-term-'+klass]=f'Class {klass} - Senators Whose Terms of Service Expire in {year}'
            return lambda url,source:values[source['id']].encode()
        plans={'people':[],'offices':[],'terms':[],'evidence':[]}
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            (root/'assets/data').mkdir(parents=True)
            (root/'scripts/data').mkdir(parents=True)
            for name in ['senators.json','houseMembers.json']:
                (root/'assets/data'/name).write_text('[]')
            (root/'scripts/data/federal_reviewed_offices.json').write_text('[]')
            with patch.object(f,'ROOT',root):
                now=f.instant('2026-11-18T17:00:00Z')
                first=f.refresh(None,self.registry,plans,now,feeds())
                second=f.refresh(first,self.registry,plans,now+f.timedelta(hours=1),feeds())
                self.assertEqual(len(first['terms']),490)
                self.assertEqual(len(second['terms']),490)
                self.assertTrue(all(t['status']=='current' for t in second['terms']))
                with self.assertRaises(ValueError):
                    f.refresh(second,self.registry,plans,now+f.timedelta(hours=2),feeds(class_two=2033))
                reelected=f.refresh(second,self.registry,plans,f.instant('2027-01-03T18:00:00Z'),feeds(120,'20270103',2033))
                self.assertEqual(sum(t['status']=='current' for t in reelected['terms']),490)
                self.assertEqual(sum(t['status']=='ended' for t in reelected['terms']),445)

    def test_registry_asset_matches_canonical_authorities(self):
        self.assertEqual(json.loads((ROOT / 'assets/data/federal_sources.json').read_text()), json.loads((ROOT / 'scripts/data/federal_sources.json').read_text()))

    def test_conflicting_incoming_for_one_start_rejected(self):
        self.data['terms'].append({**self.data['terms'][1], 'id':'conflicting'})
        with self.assertRaises(ValueError): f.validate(self.data,self.registry)

    def test_naive_dates_and_unapproved_urls_rejected(self):
        with self.assertRaises(ValueError): f.instant('2027-01-03T12:00:00')
        source=self.registry['sources'][0]
        self.assertFalse(f.allowed_url('http://clerk.house.gov/foo',source))
        self.assertFalse(f.allowed_url('https://clerk.house.gov@attacker.com/foo',source))

if __name__=='__main__': unittest.main()
