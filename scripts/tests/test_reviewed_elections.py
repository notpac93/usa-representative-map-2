"""Synthetic official-binding fixtures; these tests create no real result claims."""
import copy
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from election_adapters import reviewed as r
import election_results

NOW = datetime(2026, 11, 19, 18, tzinfo=timezone.utc)
REVIEW = {'reviewer': 'Fixture reviewer', 'reviewedAt': '2026-11-19T17:00:00Z'}

def sha(raw): return hashlib.sha256(raw).hexdigest()

def make_fixture(state='MS', format='json', pdf_cert=False):
    contest = {'id': state+':2026:governor', 'state': state, 'electionDate': '2026-11-03',
               'officeId': 'state:'+state+':governor', 'officeKind': 'governor', 'officeTitle': 'Fixture Governor',
               'seats': 1, 'outcome': 'final', 'runoffPending': False, 'tiePending': False, 'electionType':'general',
               'winner': {'name': 'Fixture Winner', 'votes': 600}}
    if format == 'json':
        results = {'state': state, 'electionDate': '2026-11-03', 'contests': [{'title':'Fixture Governor','seats':1,'outcome':'final','electionType':'general','candidates':[{'name':'Fixture Winner','votes':600,'winner':True},{'name':'Fixture Other','votes':400,'winner':False}]}]}
        raw = json.dumps(results).encode()
        contest['resultBinding'] = {'documentId':'results','statePointer':'/state','electionDatePointer':'/electionDate','contestPointer':'/contests/0',
                                    'fields':{'title':'/title','seats':'/seats','outcome':'/outcome','electionType':'/electionType','candidates':'/candidates'},
                                    'candidateFields':{'name':'/name','votes':'/votes','winner':'/winner'}}
    elif format == 'csv':
        raw = f'state,date,contest,seats,outcome,type,name,votes,winner\n{state},2026-11-03,Fixture Governor,1,final,general,Fixture Winner,600,YES\n{state},2026-11-03,Fixture Governor,1,final,general,Fixture Other,400,NO\n'.encode()
        contest['resultBinding'] = {'documentId':'results','columns':{'state':'state','electionDate':'date','contest':'contest','seats':'seats','outcome':'outcome','electionType':'type','name':'name','votes':'votes','winner':'winner'},'winnerTrueValue':'YES','winnerFalseValue':'NO'}
    else:
        raw = b'%PDF-1.7\nFixture scanned result document\n%%EOF'
        contest['resultBinding'] = {'documentId':'results','state':state,'electionDate':'2026-11-03','officeTitle':'Fixture Governor','electionType':'general','district':None,
            'pages':[1], 'review':{**REVIEW,'reviewerType':'human','method':'visually_reviewed_government_document'},'statement':'Fixture complete final result table reviewed.',
            'completeCandidateSetReviewed':True,'finalOutcomeReviewed':True,
            'reviewedCandidates':[{'name':'Fixture Winner','votes':600,'winner':True},{'name':'Fixture Other','votes':400,'winner':False}]}
    results_doc = {'id':'results','url':'https://elections.example.gov/'+state+'/results','sha256':sha(raw),'format':format,'role':'results'}
    cert = {'state':state,'electionDate':'2026-11-03','level':'state','kind':'certification','certifiedOn':'2026-11-10','timeZone':'America/Chicago',
            'contestIds':[contest['id']],'documentId':'certificate','resultDocuments':{'results':sha(raw)}}
    if pdf_cert:
        cert_raw = b'%PDF-1.7\nFixture scanned signed certificate\n%%EOF'
        cert.update(pages=[1,2],statement='Fixture signed state certificate and adopted final results reviewed.',signedDocumentReviewed=True,
                    review={**REVIEW,'reviewerType':'human','method':'visually_reviewed_government_document'})
    else:
        cert_raw = json.dumps({'state':state,'electionDate':'2026-11-03','certifiedOn':'2026-11-10','status':'certified','contestIds':[contest['id']],'resultDocuments':{'results':sha(raw)}}).encode()
        cert['bindings']={key:'/'+key for key in ['state','electionDate','certifiedOn','status','contestIds','resultDocuments']}
    cert_doc={'id':'certificate','url':'https://elections.example.gov/'+state+'/certificate','sha256':sha(cert_raw),'format':'pdf' if pdf_cert else 'json','role':'certification'}
    package={'schemaVersion':1,'state':state,'electionDate':'2026-11-03','review':dict(REVIEW),'documents':[results_doc,cert_doc],'certification':cert,'contests':[contest]}
    responses={results_doc['url']:raw,cert_doc['url']:cert_raw}
    return package,responses


def repin(package,responses,doc_id):
    doc=next(d for d in package['documents'] if d['id']==doc_id)
    doc['sha256']=sha(responses[doc['url']])
    if doc_id=='results':
        package['certification']['resultDocuments']['results']=doc['sha256']
        cert_doc=next(d for d in package['documents'] if d['id']=='certificate')
        if cert_doc['format']=='json':
            data=json.loads(responses[cert_doc['url']]);data['resultDocuments']=dict(package['certification']['resultDocuments'])
            responses[cert_doc['url']]=json.dumps(data).encode();cert_doc['sha256']=sha(responses[cert_doc['url']])


class ReviewedStateImportTest(unittest.TestCase):
    def collect(self,package,responses,now=NOW):
        with patch.object(r,'pdf_pages',return_value=2):
            return r.collect_reviewed(responses.__getitem__,now,package)

    def test_structured_path_supports_each_of_fifty_states_without_default_facts(self):
        for state in sorted(r.STATES):
            package,responses=make_fixture(state)
            report=self.collect(package,responses)
            self.assertEqual(report['state'],state)
            self.assertEqual(report['contests'][0]['winner'],{'name':'Fixture Winner','votes':600})
            self.assertEqual(report['contests'][0]['startDateStatus'],'requires_office_specific_verification')
            self.assertFalse(report['coverage']['completeStateCoverage'])
            self.assertEqual(report['contests'][0]['resultVerificationMethod'],'machine_verified_json_binding')

    def test_csv_rows_bind_explicit_state_date_names_votes_and_winner_flags(self):
        package,responses=make_fixture(format='csv')
        report=self.collect(package,responses)
        self.assertEqual(report['contests'][0]['resultVerificationMethod'],'machine_verified_csv_binding')
        package['contests'][0]['winner']['votes']=601
        with self.assertRaisesRegex(ValueError,'Normalized winner differs'):self.collect(package,responses)

    def test_pinned_hash_alone_does_not_prove_json_name_votes_or_win(self):
        for field,value in [('name','Different Winner'),('votes',401),('winner',False)]:
            package,responses=make_fixture();doc=package['documents'][0]
            data=json.loads(responses[doc['url']]);data['contests'][0]['candidates'][0][field]=value
            responses[doc['url']]=json.dumps(data).encode();repin(package,responses,'results')
            with self.subTest(field=field):
                with self.assertRaises(ValueError):self.collect(package,responses)

    def test_cross_state_office_date_and_future_review_rejected(self):
        for mutate in [lambda p:p['contests'][0].update(state='NY'),lambda p:p['contests'][0].update(officeId='state:NY:governor'),
                       lambda p:p.update(electionDate='2028-11-07'),lambda p:p['review'].update(reviewedAt='2027-01-01T00:00:00Z')]:
            package,responses=make_fixture();mutate(package)
            with self.assertRaises(ValueError):self.collect(package,responses)

    def test_json_feed_state_and_election_year_must_match_even_with_new_hash(self):
        for key,value in [('state','NY'),('electionDate','2024-11-05')]:
            package,responses=make_fixture();doc=package['documents'][0]
            data=json.loads(responses[doc['url']]);data[key]=value
            responses[doc['url']]=json.dumps(data).encode();repin(package,responses,'results')
            with self.assertRaisesRegex(ValueError,'state or election date'):self.collect(package,responses)

    def test_ties_runoffs_multiseat_and_multiple_winners_never_become_one_winner(self):
        for mutate in [lambda p:p['contests'][0].update(seats=2),lambda p:p['contests'][0].update(seats=True),lambda p:p['contests'][0].update(tiePending=True),lambda p:p['contests'][0].update(runoffPending=True),lambda p:p['contests'][0].update(outcome='runoff')]:
            package,responses=make_fixture();mutate(package)
            with self.assertRaises(ValueError):self.collect(package,responses)
        for row_update in [{'votes':600},{'winner':True}]:
            package,responses=make_fixture();doc=package['documents'][0]
            data=json.loads(responses[doc['url']]);data['contests'][0]['candidates'][1].update(row_update)
            responses[doc['url']]=json.dumps(data).encode();repin(package,responses,'results')
            with self.assertRaises(ValueError):self.collect(package,responses)

    def test_recognition_county_totals_and_future_certification_are_not_state_certification(self):
        for mutate in [lambda p:p['certification'].update(kind='recognition'),lambda p:p['certification'].update(level='county'),lambda p:p['certification'].update(certifiedOn='2026-12-03')]:
            package,responses=make_fixture();mutate(package)
            with self.assertRaises(ValueError):self.collect(package,responses)

    def test_certification_must_bind_contest_ids_and_exact_results_revision(self):
        for mutate in [lambda p:p['certification'].update(contestIds=['another contest']),lambda p:p['certification'].update(resultDocuments={'results':'b'*64})]:
            package,responses=make_fixture();mutate(package)
            with self.assertRaises(ValueError):self.collect(package,responses)

    def test_pdf_transcription_and_signed_certificate_are_explicit_human_review(self):
        package,responses=make_fixture(format='pdf',pdf_cert=True)
        report=self.collect(package,responses)
        contest=report['contests'][0]
        self.assertEqual(contest['resultVerificationMethod'],'human_reviewed_government_pdf')
        self.assertEqual(contest['certificationVerificationMethod'],'human_reviewed_signed_government_pdf')
        self.assertNotIn('actualStart',contest)
        package['certification']['signedDocumentReviewed']=False
        with self.assertRaises(ValueError):self.collect(package,responses)

    def test_pdf_missing_human_identity_pages_or_complete_table_review_is_rejected(self):
        for mutate in [lambda p:p['contests'][0]['resultBinding']['review'].update(reviewerType='agent'),lambda p:p['contests'][0]['resultBinding'].update(pages=[]),lambda p:p['contests'][0]['resultBinding'].update(pages=[3]),lambda p:p['contests'][0]['resultBinding'].update(completeCandidateSetReviewed=False)]:
            package,responses=make_fixture(format='pdf',pdf_cert=True);mutate(package)
            with self.assertRaises(ValueError):self.collect(package,responses)

    def add_rule(self,package,responses,instant=False):
        rule={'state':package['state'],'officeKind':'governor','officeTitle':'Fixture Governor','district':None,'documentId':'rule','datePrecision':'instant' if instant else 'day','timeZone':'America/Chicago'}
        source={'state':package['state'],'officeTitle':'Fixture Governor','officeKind':'governor'}
        if instant:
            rule.update(scheduledStart='2027-01-04T12:00:00-06:00',timeExplicit=True,timeZoneExplicit=True)
            source['scheduledStart']=rule['scheduledStart']
            source['timeZone']=rule['timeZone']
        else:rule['scheduledStartDate']='2027-01-04';source['scheduledStartDate']=rule['scheduledStartDate']
        rule['bindings']={key:'/'+key for key in source}
        raw=json.dumps(source).encode();url='https://elections.example.gov/'+package['state']+'/start-rule'
        package['documents'].append({'id':'rule','url':url,'sha256':sha(raw),'format':'json','role':'startRule'});responses[url]=raw
        package['contests'][0]['startRule']=rule
        return rule

    def test_state_civil_start_date_never_becomes_guessed_utc_midnight(self):
        package,responses=make_fixture();self.add_rule(package,responses)
        contest=self.collect(package,responses)['contests'][0]
        self.assertEqual(contest['scheduledStartDate'],'2027-01-04')
        self.assertEqual(contest['startDatePrecision'],'day')
        self.assertNotIn('scheduledStart',contest)
        package['contests'][0]['startRule']['scheduledStart']='2027-01-04T00:00:00Z'
        with self.assertRaises(ValueError):self.collect(package,responses)

    def test_exact_start_instant_needs_explicit_clock_zone_and_matching_offset(self):
        package,responses=make_fixture();rule=self.add_rule(package,responses,instant=True)
        contest=self.collect(package,responses)['contests'][0]
        self.assertEqual(contest['scheduledStart'],'2027-01-04T18:00:00Z')
        rule['timeExplicit']=False
        with self.assertRaises(ValueError):self.collect(package,responses)

    def test_special_election_type_cannot_be_omitted_or_relabelled_general(self):
        for change in [None, 'special']:
            package,responses=make_fixture()
            if change is None:del package['contests'][0]['electionType']
            else:package['contests'][0]['electionType']=change
            with self.assertRaises(ValueError):self.collect(package,responses)

    def test_instant_start_time_zone_must_be_bound_to_source_fact(self):
        package,responses=make_fixture();rule=self.add_rule(package,responses,instant=True)
        rule['timeZone']='America/Winnipeg' # Same offset on this day is insufficient evidence.
        with self.assertRaisesRegex(ValueError,'time zone differs'):self.collect(package,responses)

    def test_wrong_office_or_cross_state_start_rule_is_rejected(self):
        for change in [{'state':'NY'},{'officeTitle':'Different Office'},{'officeKind':'stateHouse'}]:
            package,responses=make_fixture();rule=self.add_rule(package,responses);rule.update(change)
            with self.assertRaises(ValueError):self.collect(package,responses)

    def test_changed_document_bytes_are_rejected_before_fact_import(self):
        package,responses=make_fixture();responses[package['documents'][0]['url']]+=b' '
        with self.assertRaisesRegex(ValueError,'changed'):self.collect(package,responses)

    def test_no_contests_is_a_gap_not_certified_empty_coverage(self):
        package,responses=make_fixture();package['contests']=[]
        with self.assertRaises(ValueError):self.collect(package,responses)

    def test_verified_package_can_create_dated_incoming_record_without_publishing(self):
        package,responses=make_fixture();self.add_rule(package,responses)
        report=self.collect(package,responses)
        snapshot={'people':[],'offices':[],'terms':[],'evidence':[],'publishedAt':'2026-11-01T00:00:00Z'}
        registry={'sources':[{'id':'constitution'}, {'id':'state-election-MS'}]}
        election_results.add_certified(snapshot,registry,{'MS':report},NOW,None)
        self.assertEqual(len(snapshot['terms']),1)
        term=snapshot['terms'][0]
        self.assertEqual(term['status'],'incoming')
        self.assertEqual(term['certificationStatus'],'certified')
        self.assertEqual(term['scheduledStartDate'],'2027-01-04')
        self.assertNotIn('scheduledStart',term)
        self.assertEqual(snapshot['publishedAt'],'2026-11-01T00:00:00Z')
        self.assertEqual({e['claim'] for e in snapshot['evidence']},{'certification','reportedResult','scheduledStart'})


if __name__=='__main__':unittest.main()
