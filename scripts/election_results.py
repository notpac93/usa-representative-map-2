"""All-state official election source intake, coverage, and evidence-bound incoming records.

A reachable directory is not a parsed contest, and recognition is not certification.
"""
from concurrent.futures import ThreadPoolExecutor
from datetime import timezone
import hashlib
import json
from pathlib import Path
import re
import unicodedata
from urllib.parse import urlparse

STATES=set('AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY'.split())
KINDS=['house','senate','governor','stateSenate','stateHouse','stateExecutive','stateJudge']

def source_for(state):
    delegated=[f['url'] for f in state.get('machineReadableFeeds',[]) if f.get('approvedHost') not in state['allowedHosts']]
    hosts=sorted(set(state['allowedHosts']+[urlparse(u).hostname for u in delegated]))
    return {'id':'state-election-'+state['stateId'],'name':state['name']+' election authority',
            'url':state['resultsUrl'],'hosts':hosts,'delegatedUrls':delegated,'states':[state['stateId']],
            'officeKinds':KINDS,'claims':['reportedResult','certification','incomingRecognition','scheduledStart'],
            'required':False, 'maxBytes':20_000_000}

def load_states(root):
    data=json.loads((root/'scripts/data/state_election_sources.json').read_text())
    entries=data['states']
    if len(entries)!=50 or {s['stateId'] for s in entries}!=STATES: raise ValueError('Exactly 50 distinct state election authorities required')
    return entries

def slug(value):
    return re.sub('[^a-z0-9]+','-',unicodedata.normalize('NFKD',value).encode('ascii','ignore').decode().lower()).strip('-')

def state_office_id(contest,state):
    """Use one namespace and require an identified seat for every state office."""
    kind=contest['officeKind'];district=contest.get('district')
    supplied=contest.get('officeId')
    prefix=f'us:state:{state}:{kind}'
    canonical=supplied
    if supplied and supplied.startswith(f'state:{state}:'):canonical='us:'+supplied
    if kind=='governor':
        if district is not None:raise ValueError('Governor is a statewide singleton office')
        expected=prefix
    elif kind in ('stateHouse','stateSenate'):
        if district is None or isinstance(district,bool) or not str(district).strip():
            raise ValueError('Legislative contests require an explicitly reviewed district')
        expected=prefix+':'+slug(str(district))
    elif kind in ('stateExecutive','stateJudge'):
        if canonical:
            suffix=canonical[len(prefix)+1:] if canonical.startswith(prefix+':') else ''
            if not suffix or not re.fullmatch(r'[a-z0-9]+(?:[a-z0-9:-]*[a-z0-9])?',suffix):
                raise ValueError('Executive and judicial office IDs require a canonical kind and unique seat suffix')
            return canonical
        if kind=='stateJudge' or district is not None:
            raise ValueError('This contest requires an explicitly reviewed unique office ID')
        suffix=slug(contest['officeTitle'])
        if not suffix:raise ValueError('State executive office title does not identify a unique office')
        expected=prefix+':'+suffix
    else:raise ValueError('Unsupported state office kind')
    if canonical and canonical!=expected:
        raise ValueError('Reviewed state office ID disagrees with its kind or district')
    return expected

def _iso(now): return now.astimezone(timezone.utc).isoformat().replace('+00:00','Z')

def collect(snapshot, registry, root, fetch, now, evidence_factory, *, states=None, county_names=None):
    """Collect all 50 directories and available reviewed adapters. Never fill gaps with guesses."""
    entries=load_states(root)
    if states is not None:
        if set(states)-STATES: raise ValueError('Unknown requested state')
        requested=set(states)
    else: requested=STATES
    state_sources={s['stateId']:next(source for source in registry['sources'] if source['id']=='state-election-'+s['stateId']) for s in entries}
    def download(entry):
        state=entry['stateId'];source=state_sources[state]
        record={'stateId':state,'name':entry['name'],'resultsUrl':entry['resultsUrl'],
                'directoryStatus':'notRequested','certificationStatus':'notVerified',
                'contestCoverage':'notImported','startDateCoverage':'notVerified',
                'governmentRecognizedIncoming':sum(t['status']=='incomingRecognized' and next((o.get('state') for o in snapshot['offices'] if o['id']==t['officeId']),None)==state for t in snapshot['terms']),
                'checkedAt':_iso(now)}
        if state not in requested:return record
        record['exports']=[]
        if state=='NV':
            record.update(directoryStatus='accessRestricted',error='Official results site restricts automated traffic; use an authorized government export or reviewed download.')
            return record
        try:
            raw=fetch(source['url'],source)
            record.update(directoryStatus='retrieved',resultsSha256=hashlib.sha256(raw).hexdigest())
        except Exception as error:
            record.update(directoryStatus='unavailable',error=f'{type(error).__name__}: {error}')
        for feed in entry.get('machineReadableFeeds',[]):
            item={'url':feed['url'],'format':feed['format'],'resultStatus':feed.get('resultStatus','notVerified')}
            if feed['format'] not in ('csv','json','xml','xlsx','zip','zip_xlsx'):
                item['status']='manualExportSelectionRequired'
            else:
                try:
                    raw=fetch(feed['url'],source)
                    item.update(status='downloaded',sha256=hashlib.sha256(raw).hexdigest(),bytes=len(raw))
                except Exception as error:item.update(status='unavailable',error=str(error))
            record['exports'].append(item)
        return record
    with ThreadPoolExecutor(max_workers=6) as pool:
        records=list(pool.map(download,entries))
    reports={}
    for state in ['MS','WY','DE']:
        if state not in requested:continue
        source=state_sources[state]
        def get(url):
            selected=source
            host=urlparse(url).hostname
            if state=='MS' and host not in source['hosts']:
                selected=next(s for s in registry['sources'] if host in s['hosts'] and 'incomingRecognition' in s['claims'])
                selected={**selected,'required':False}
            return fetch(url,selected)
        try:
            if state=='MS':
                try: from .election_adapters.mississippi import collect_mississippi
                except ImportError: from election_adapters.mississippi import collect_mississippi
                result=collect_mississippi(get,now,county_names=county_names)
            elif state=='DE':
                try: from .election_adapters.delaware import collect_delaware
                except ImportError: from election_adapters.delaware import collect_delaware
                result=collect_delaware(get,now)
            else:
                try: from .election_adapters.certified import collect_wyoming
                except ImportError: from election_adapters.certified import collect_wyoming
                result=collect_wyoming(get,now)
            reports[state]=result
            record=next(r for r in records if r['stateId']==state)
            record.update(certificationStatus=result['certificationStatus'], details=result.get('coverage',{}),
                          contestCoverage='imported' if result.get('contests') else 'notImported')
            if result.get('certificationCalendar'):record['certificationCalendar']=result['certificationCalendar']
        except Exception as error:
            next(r for r in records if r['stateId']==state)['adapterError']=f'{type(error).__name__}: {error}'
    packages=json.loads((root/'scripts/data/election_result_reviews.json').read_text())['packages']
    if len({p['state'] for p in packages})!=len(packages): raise ValueError('One reviewed election package per state is required')
    for package in packages:
        state=package['state']
        if package.get('electionDate')!='2026-11-03': raise ValueError('This intake is scoped to the November 3, 2026 election; use a separately reviewed cycle for other elections.')
        if state not in requested:continue
        source=state_sources[state]
        try:
            if state in reports:
                raise ValueError('This state already has a native adapter report. Extend that adapter or explicitly review a complete migration before adding a replacement package; partial packages cannot discard its contests or county evidence.')
            try: from .election_adapters.reviewed import collect_reviewed
            except ImportError: from election_adapters.reviewed import collect_reviewed
            result=collect_reviewed(lambda url:fetch(url,source),now,package)
            reports[state]=result
            record=next(r for r in records if r['stateId']==state)
            record.update(certificationStatus='certified',contestCoverage='reviewedContestsImported',details=result['coverage'])
        except Exception as error:
            next(r for r in records if r['stateId']==state)['reviewedImportError']=str(error)
    add_certified(snapshot,registry,reports,now,evidence_factory)
    old={r['id']:r for r in snapshot.get('electionResults',[])}
    for state,result in reports.items():
        for contest in result.get('contests',[]):
            contest=dict(contest)
            contest.setdefault('id',state+':2026:'+contest.get('officeKind','unknown')+':'+str(contest.get('district')))
            contest['sourceDocuments']=result.get('sourceDocuments',[])
            recognized=contest.get('governmentRecognizedIncoming')
            previous=old.get(contest['id'],{}).get('governmentRecognizedIncoming')
            if recognized and previous and slug(recognized.get('name',''))==slug(previous.get('name','')) and previous.get('recognizedAt'):
                contest['governmentRecognizedIncoming']={**recognized,'recognizedAt':previous['recognizedAt']}
            old[contest['id']]=contest
    snapshot['electionResults']=list(old.values())
    for record in records:
        terms=[t for t in snapshot['terms'] if t['status'] in ('incoming','incomingRecognized') and next((o.get('state') for o in snapshot['offices'] if o['id']==t['officeId']),None)==record['stateId']]
        record['verifiedStartDates']=sum(bool(t.get('scheduledStart') or t.get('scheduledStartDate')) for t in terms)
        record['certifiedIncomingRecords']=sum(t['status']=='incoming' for t in terms)
        record['startDateCoverage']='partial' if record['verifiedStartDates'] else 'notVerified'
    snapshot['electionCoverage']={'electionDate':'2026-11-03','checkedAt':_iso(now),
         'registeredStates':50,'requestedStates':len(requested),'resultsDirectoriesRetrieved':sum(r['directoryStatus']=='retrieved' for r in records),
         'complete':all(r.get('contestCoverage')=='complete' and r.get('certificationStatus')=='certified' and r.get('startDateCoverage')=='complete' for r in records),'scope':'federal_and_statewide_and_state_legislative_contests; local elections excluded',
         'statesWithParsedContests':sum(bool(r.get('contests')) for r in reports.values()),
         'statesWithCertifiedContests':sum(r.get('certificationStatus')=='certified' for r in reports.values()),
         'statesWithCompleteReviewedBallotInventory':sum(r.get('contestCoverage')=='complete' for r in records),
         'stateContestsWithCivilStartDate':sum(bool(c.get('scheduledStartDate')) for r in reports.values() for c in r.get('contests',[])),
         'states':records,
         'meaning':'Directory reachability is source coverage only. Unimported contests and unverified certifications remain explicit gaps.'}
    return snapshot['electionCoverage'],reports

def add_certified(snapshot,registry,reports,now,evidence_factory):
    people={p['id']:p for p in snapshot['people']};offices={o['id']:o for o in snapshot['offices']}
    terms={t['id']:t for t in snapshot['terms']};proofs={e['id']:e for e in snapshot['evidence']}
    source_map={s['id']:s for s in registry['sources']}
    constitution=source_map['constitution']
    # Regular federal start evidence has already been fetched and checked by the federal collector.
    congress_rule='and the terms of Senators and Representatives at noon on the 3d day of January, of the years in which such terms would have ended if this article had not been ratified; and the terms of their successors shall then begin.'
    rule_proofs=[e for e in snapshot['evidence'] if e['sourceId']=='constitution'
                 and congress_rule in (e.get('excerpt') or '') and e.get('retrievedAt')==_iso(now)]
    for state,result in reports.items():
        if result.get('certificationStatus')!='certified':continue
        source=source_map['state-election-'+state]
        docs=result.get('sourceDocuments',[])
        cert=next((d for d in docs if d.get('role') in ('signed_state_certification','certification')),None)
        returns=next((d for d in docs if d.get('role') in ('certified_results_workbooks','results')),None)
        if not cert or not returns:raise ValueError('Certified result lacks signed certification or official returns')
        for contest in result['contests']:
            winner=contest.get('winner')
            if not winner:continue
            if contest.get('electionDate')!='2026-11-03': raise ValueError('Contest election cycle differs from the active intake')
            contest_cert=cert;contest_returns=returns
            if contest.get('certificationDocumentUrl'):
                contest_cert=next((d for d in docs if d['url']==contest['certificationDocumentUrl'] and d['sha256']==contest['certificationDocumentSha256']),None)
                contest_returns=next((d for d in docs if d['url']==contest['resultDocumentUrl'] and d['sha256']==contest['resultDocumentSha256']),None)
                if not contest_cert or not contest_returns: raise ValueError('Contest is not bound to its exact government documents')
            kind=contest['officeKind'];district=contest.get('district')
            if kind not in KINDS: raise ValueError('Office kind is outside the supported election scope')
            if kind=='senate':
                if contest.get('electionType')!='general':
                    oid=contest.get('officeId')
                    if oid not in offices:raise ValueError('Special Senate election requires a reviewed existing seat ID')
                else:oid=f'us:senate:{state}:II'
            elif kind=='house':oid=f'us:house:{state}{district:02}'
            else:
                oid=state_office_id(contest,state)
                if contest.get('officeId') in offices and contest['officeId']!=oid:
                    raise ValueError('Existing legacy office identity requires an explicit migration review')
            if kind in ('house','senate') and contest.get('officeId') and contest['officeId']!=oid:
                raise ValueError('Reviewed office ID disagrees with the federal seat')
            if oid in offices and (offices[oid]['state']!=state or offices[oid]['kind']!=kind or
                                   (district is not None and str(offices[oid].get('district'))!=str(district))):
                raise ValueError('Reviewed office conflicts with an existing office identity')
            normalized=slug(winner['name'])
            for prior in terms.values():
                if prior['officeId']==oid and prior['status'] in ('incoming','incomingRecognized') and slug(people[prior['personId']]['name'])!=normalized:
                    if prior['status']=='incoming': raise ValueError('Conflicting certified winners require review: '+oid)
                    prior['status']='disputed'
                    prior['conflictingCertifiedResult']=cert['url']
            same=[t for t in terms.values() if t['officeId']==oid and t['status'] in ('incomingRecognized','incoming') and slug(people[t['personId']]['name'])==normalized]
            serving=[t for t in terms.values() if t['officeId']==oid and t['status']=='current' and slug(people[t['personId']]['name'])==normalized]
            pid=serving[0]['personId'] if serving else (same[0]['personId'] if same else 'us:person:elected:2026:'+state+':'+normalized)
            tid=same[0]['id'] if same else oid+':2026-election:'+normalized
            if tid in terms and terms[tid]['status'] in ('current','ended','withdrawn','disputed'):continue
            person=people.setdefault(pid,{'id':pid,'name':winner['name']})
            if winner.get('party') is not None:person.setdefault('party',winner['party'])
            offices.setdefault(oid,{'id':oid,'state':state,'kind':kind,'branch':'legislative' if kind in ('house','senate','stateSenate','stateHouse') else ('judicial' if kind=='stateJudge' else 'executive'),
                                    'district':district,'title':contest['officeTitle']})
            ids=[]
            for doc,claim in [(contest_cert,'certification'),(contest_returns,'reportedResult')]:
                proof={'id':hashlib.sha256((doc['sha256']+oid+pid+claim).encode()).hexdigest()[:24],
                       'sourceId':source['id'],'url':doc['url'],'sha256':doc['sha256'],'retrievedAt':_iso(now),
                       'officeId':oid,'personId':pid,'claim':claim}
                proofs[proof['id']]=proof;ids.append(proof['id'])
            term={'id':tid,'officeId':oid,'personId':pid,'status':'incomingRecognized','recognizedAt':terms.get(tid,{}).get('recognizedAt',_iso(now)),
                  'certificationStatus':'certified','certifiedAt':terms.get(tid,{}).get('certifiedAt',_iso(now)),'certificationDate':contest['certifiedOn'],
                  'certificationDatePrecision':'day','evidenceIds':ids,'startDateStatus':'awaiting_office_specific_rule'}
            if contest.get('scheduledStart') and contest.get('scheduledStartDate'):
                raise ValueError('Reviewed start cannot mix a civil date with an exact instant')
            explicit_start=bool(contest.get('startRule') and (contest.get('scheduledStart') or contest.get('scheduledStartDate')))
            if kind in ('house','senate') and contest.get('electionType')=='general' and rule_proofs and not explicit_start:
                template=rule_proofs[0]
                proof={**template,'id':hashlib.sha256((template['sha256']+oid+pid+'scheduledStart').encode()).hexdigest()[:24],
                       'officeId':oid,'personId':pid,'claim':'scheduledStart','excerpt':congress_rule}
                proofs[proof['id']]=proof;ids.append(proof['id'])
                term.update(status='incoming',scheduledStart='2027-01-03T17:00:00Z',startDateStatus='verified_regular_term')
            if contest.get('scheduledStartDate') and contest.get('startRule'):
                rule=contest['startRule']
                proof={'id':hashlib.sha256((rule['sha256']+oid+pid+'scheduledStart').encode()).hexdigest()[:24],
                       'sourceId':source['id'],'url':rule['url'],'sha256':rule['sha256'],'retrievedAt':_iso(now),
                       'officeId':oid,'personId':pid,'claim':'scheduledStart','excerpt':rule['excerpt']}
                proofs[proof['id']]=proof;ids.append(proof['id'])
                term.update(status='incoming',scheduledStartDate=contest['scheduledStartDate'],startTimeZone=contest.get('startTimeZone'),startDateStatus='verified_day_only')
            if contest.get('scheduledStart') and contest.get('startRule'):
                rule=contest['startRule']
                proof={'id':hashlib.sha256((rule['sha256']+oid+pid+'scheduledStart').encode()).hexdigest()[:24],
                       'sourceId':source['id'],'url':rule['url'],'sha256':rule['sha256'],'retrievedAt':_iso(now),
                       'officeId':oid,'personId':pid,'claim':'scheduledStart'}
                proofs[proof['id']]=proof;ids.append(proof['id'])
                term.update(status='incoming',scheduledStart=contest['scheduledStart'],startDateStatus='verified_instant')
            terms[tid]=term
    snapshot.update(people=list(people.values()),offices=list(offices.values()),terms=list(terms.values()),evidence=list(proofs.values()))
