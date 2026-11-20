"""Government recognition of senators-elect; recognition is never certification."""
import hashlib
from html.parser import HTMLParser
import re
import unicodedata

URL = 'https://employment.senate.gov/2026-senators-elect-resume-collection/'
SOURCE_ID = 'senate-elect-2026'

class Headings(HTMLParser):
    def __init__(self):
        super().__init__(); self.tag=None; self.parts=[]; self.headings=[]
    def handle_starttag(self, tag, attrs):
        if tag in ('h1','h2','h3'): self.tag=tag; self.parts=[]
    def handle_data(self, value):
        if self.tag: self.parts.append(value)
    def handle_endtag(self, tag):
        if tag==self.tag:
            self.headings.append((tag,' '.join(' '.join(self.parts).split())))
            self.tag=None

def parse(raw):
    parser=Headings(); parser.feed(raw.decode('utf-8'))
    active=False; people=[]
    for tag,text in parser.headings:
        if tag=='h2' and text=='New Senators-Elect': active=True; continue
        if active and tag in ('h1','h2'): break
        if active and tag=='h3':
            match=re.fullmatch(r'(.+?)\s+\(([A-Z]{2})\)',text)
            if match: people.append({'name':match[1], 'state':match[2]})
    if not people or len(people)>35 or len({p['state'] for p in people})!=len(people):
        raise ValueError('Senators-elect government directory is missing, changed, or ambiguous')
    return people

def add_to_snapshot(snapshot, registry, fetch, now, evidence_factory, iso):
    source=next(s for s in registry['sources'] if s['id']==SOURCE_ID)
    raw=fetch(URL,source)
    entries=parse(raw)
    people={p['id']:p for p in snapshot['people']}
    terms={t['id']:t for t in snapshot['terms']}
    proofs={p['id']:p for p in snapshot['evidence']}
    offices={o['id']:o for o in snapshot['offices']}
    rule_source=next(s for s in registry['sources'] if s['id']=='constitution')
    rule_raw=fetch(rule_source['url'],rule_source)
    rule_text='and the terms of Senators and Representatives at noon on the 3d day of January, of the years in which such terms would have ended if this article had not been ratified; and the terms of their successors shall then begin.'
    if rule_text not in ' '.join(re.sub('<[^>]+>',' ',rule_raw.decode()).split()):
        raise ValueError('Federal start rule missing')
    for entry in entries:
        state=entry['state']
        # OH's 2026 race is a special election for Class III, not the regular Class II cycle.
        office_id=f'us:senate:{state}:' + ('III' if state=='OH' else 'II')
        if office_id not in offices: raise ValueError('Unmatched Senate seat: '+state)
        regular=state!='OH'
        if regular and not any(t['officeId']==office_id and t.get('scheduledEnd')=='2027-01-03T17:00:00Z' for t in snapshot['terms']):
            raise ValueError('Regular Senate cycle not corroborated: '+state)
        slug=re.sub('[^a-z0-9]+','-',unicodedata.normalize('NFKD',entry['name']).encode('ascii','ignore').decode().lower()).strip('-')
        pid=f'us:person:senate-elect:2026:{state}:{slug}'
        tid=f'{office_id}:2026-election:{slug}'
        old=terms.get(tid)
        if old and (old['status'] in ('ended','withdrawn','disputed','current','incoming') or old.get('certificationStatus')=='certified'): continue
        people[pid]={'id':pid,'name':entry['name']}
        proof=evidence_factory(source,raw,now,office_id,pid,'incomingRecognition',entry['name']+' ('+state+')')
        proofs[proof['id']]=proof
        ids=[proof['id']]
        term={'id':tid,'officeId':office_id,'personId':pid,'status':'incomingRecognized',
              'recognizedAt':old.get('recognizedAt',iso(now)) if old else iso(now),
              'verifiedAt':iso(now),'electionDate':'2026-11-03','certificationStatus':'notVerified',
              'evidenceIds':ids, 'startDateStatus':'verified_regular_term' if regular else 'awaiting_special_election_qualification'}
        if regular:
            term['scheduledStart']='2027-01-03T17:00:00Z'
            start=evidence_factory(rule_source,rule_raw,now,office_id,pid,'scheduledStart',rule_text)
            proofs[start['id']]=start;ids.append(start['id'])
        terms[tid]=term
    snapshot.update(people=list(people.values()),terms=list(terms.values()),evidence=list(proofs.values()))
    return entries
