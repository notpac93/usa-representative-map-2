#!/usr/bin/env python3
"""Publish government-backed federal snapshots. No election predictions or client-clock promotion."""
import argparse
import copy
import hashlib
import html
import json
import os
from pathlib import Path
import re
import tempfile
from datetime import datetime, timedelta, timezone
from urllib.parse import urlparse
from urllib.request import Request
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
UTC = timezone.utc

def instant(value):
    result = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if result.tzinfo is None:
        raise ValueError('Every effective time must include a UTC offset')
    return result.astimezone(UTC)

def iso(value):
    return value.astimezone(UTC).isoformat().replace('+00:00', 'Z')

def text_content(raw):
    return ' '.join(html.unescape(re.sub('<[^>]+>', ' ', raw.decode('utf-8'))).split())

def allowed_url(url, source):
    u = urlparse(url)
    delegated=source.get('delegatedUrls',[])
    if u.hostname in {urlparse(value).hostname for value in delegated} and url not in delegated:
        return False
    return u.scheme == 'https' and u.hostname in source['hosts'] and not u.username and not u.password and u.port in (None, 443)

def fetch(url, source):
    if not allowed_url(url, source):
        raise ValueError('Unregistered source URL: ' + url)
    # Reject redirects before following them (no requests to arbitrary redirect targets).
    import urllib.request
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            raise ValueError('Source redirected; review registry: ' + url)
    with urllib.request.build_opener(NoRedirect()).open(Request(url, headers={'User-Agent': 'USARepresentativeMap/1.0 civic-directory'}), timeout=30) as response:
        if not allowed_url(response.url, source):
            raise ValueError('Unapproved redirect')
        limit=min(int(source.get('maxBytes',8_000_000)),25_000_000)
        raw = response.read(limit+1)
    if len(raw) > limit:
        raise ValueError('Source exceeds size limit')
    return raw

def evidence(source, raw, now, office_id, person_id, claim, excerpt=None):
    digest = hashlib.sha256(raw).hexdigest()
    key = hashlib.sha256(f'{source["id"]}|{office_id}|{person_id}|{claim}|{digest}'.encode()).hexdigest()[:24]
    return {'id': key, 'sourceId': source['id'], 'url': source['url'], 'retrievedAt': iso(now),
            'sha256': digest, 'officeId': office_id, 'personId': person_id, 'claim': claim,
            'excerpt': excerpt}

def parse_house(raw):
    root = ET.fromstring(raw)
    congress = int(root.findtext('title-info/congress-num'))
    records = []
    for node in root.findall('members/member'):
        info = node.find('member-info')
        seat = node.findtext('statedistrict', '')
        bio = info.findtext('bioguideID', '')
        if not bio or not re.fullmatch(r'[A-Z]\d{6}', bio):
            continue  # Vacancies never become people.
        if not re.fullmatch(r'[A-Z]{2}\d{2}', seat):
            raise ValueError('Invalid House seat')
        sworn = info.find('sworn-date')
        records.append({'officeId': 'us:house:' + seat, 'kind': 'house', 'state': seat[:2],
            'district': int(seat[2:]), 'congress': congress, 'period': str(congress), 'name': info.findtext('official-name'), 'personId': bio,
            'party': info.findtext('party'), 'phone': info.findtext('phone'),
            'address': ' '.join(filter(None, [info.findtext('office-room'), info.findtext('office-building'), 'Washington, DC', info.findtext('office-zip')])),
            'swornDate': sworn.get('date') if sworn is not None else None,
            'scheduledEnd': f'{1789 + congress * 2}-01-03T17:00:00Z'})
    if len({r['officeId'] for r in records}) != len(records) or len({r['personId'] for r in records}) != len(records):
        raise ValueError('Duplicate House seat or person in government feed')
    if not 400 <= len(records) <= 441:
        raise ValueError('Unexpected House coverage; preserve last snapshot')
    return records

def parse_senate(raw):
    records = []
    for node in ET.fromstring(raw).findall('member'):
        bio = node.findtext('bioguide_id', '')
        if not bio or not re.fullmatch(r'[A-Z]\d{6}', bio):
            continue
        state = node.findtext('state', '')
        klass = node.findtext('class', '').replace('Class ', '')
        if klass not in ('I', 'II', 'III') or not re.fullmatch('[A-Z]{2}', state):
            raise ValueError('Invalid Senate seat')
        records.append({'officeId': f'us:senate:{state}:{klass}', 'kind': 'senate', 'state': state, 'class': klass,
            'name': node.findtext('first_name') + ' ' + node.findtext('last_name'), 'personId': bio,
            'party': node.findtext('party'), 'phone': node.findtext('phone'), 'address': node.findtext('address'),
            'website': node.findtext('website'), 'contactUrl': node.findtext('email')})
    if len({r['officeId'] for r in records}) != len(records) or len({r['personId'] for r in records}) != len(records):
        raise ValueError('Duplicate Senate seat or person in government feed')
    if not 90 <= len(records) <= 100:
        raise ValueError('Unexpected Senate coverage; preserve last snapshot')
    return records

def validate(snapshot, registry):
    if snapshot['schemaVersion'] != 1:
        raise ValueError('Unsupported snapshot')
    now = instant(snapshot['publishedAt'])
    sources = {s['id']: s for s in registry['sources']}
    def index(items):
        result = {x['id']: x for x in items}
        if len(result) != len(items):
            raise ValueError('Duplicate identifiers')
        return result
    people, offices, terms, proofs = [index(snapshot[k]) for k in ('people', 'offices', 'terms', 'evidence')]
    for proof in proofs.values():
        source = sources[proof['sourceId']]
        office = offices[proof['officeId']]
        if source.get('states') and office['state'] not in source['states']:
            raise ValueError('Evidence outside election jurisdiction')
        if proof['personId'] not in people or office['kind'] not in source['officeKinds'] or proof['claim'] not in source['claims'] or not allowed_url(proof['url'], source):
            raise ValueError('Evidence outside source authority')
        if not re.fullmatch('[0-9a-f]{64}', proof['sha256']) or instant(proof['retrievedAt']) > now:
            raise ValueError('Invalid evidence timestamp/hash')
    occupied = set()
    incoming_slots = set()
    for term in terms.values():
        if term['personId'] not in people or term['officeId'] not in offices:
            raise ValueError('Dangling term')
        if term['status'] not in ('current', 'incoming', 'incomingRecognized', 'ended', 'disputed', 'withdrawn'):
            raise ValueError('Unknown term status')
        for key in ('scheduledStart', 'scheduledEnd', 'actualStart', 'actualEnd', 'certifiedAt'):
            if term.get(key): instant(term[key])
        for proof_id in term['evidenceIds']:
            proof = proofs[proof_id]
            if proof['officeId'] != term['officeId'] or proof['personId'] != term['personId']:
                raise ValueError('Evidence identity mismatch')
        if term.get('actualStart') and instant(term['actualStart']) > now:
            raise ValueError('Future actual service start')
        if term.get('actualStart') and term.get('scheduledStartDate'):
            civil_start_is_due(term,instant(term['actualStart']))
        if term['status'] == 'current':
            if term['officeId'] in occupied:
                raise ValueError('Two current occupants of one seat')
            occupied.add(term['officeId'])
            if not any(proofs[p]['claim'] in ('current', 'assumedOffice') for p in term['evidenceIds']):
                raise ValueError('Current service lacks official evidence')
        claims = {proofs[p]['claim'] for p in term['evidenceIds']}
        if term.get('scheduledEnd') and 'scheduledEnd' not in claims:
            raise ValueError('Term expiration lacks authoritative schedule')
        if term['status'] in ('incoming','incomingRecognized'):
            if term['officeId'] in incoming_slots: raise ValueError('Conflicting incoming occupants')
            incoming_slots.add(term['officeId'])
        if term['status'] == 'incomingRecognized':
            if not term.get('recognizedAt') or instant(term['recognizedAt']) > now or not ({'incomingRecognition','certification'} & claims):
                raise ValueError('Incoming recognition lacks government evidence')
            if term.get('scheduledStart') and 'scheduledStart' not in claims:
                raise ValueError('Recognized incoming start lacks authoritative rule')
            if term.get('certifiedAt') and ('certification' not in claims or term.get('certificationStatus')!='certified' or instant(term['certifiedAt']) > now):
                raise ValueError('Recognition must not imply certification')
        if term['status'] == 'incoming':
            claims = {proofs[p]['claim'] for p in term['evidenceIds']}
            if not {'certification', 'scheduledStart'} <= claims or not term.get('certifiedAt') or not (term.get('scheduledStart') or term.get('scheduledStartDate')) or instant(term['certifiedAt']) > now:
                raise ValueError('Incoming term requires certified result and verified schedule')
        if term.get('scheduledStartDate'):
            from datetime import date
            from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
            if term.get('scheduledStart'):
                raise ValueError('Term start cannot mix a civil date with an exact instant')
            date.fromisoformat(term['scheduledStartDate'])
            if 'scheduledStart' not in claims: raise ValueError('Civil start date lacks authoritative evidence')
            if not isinstance(term.get('startTimeZone'), str) or not term['startTimeZone']:
                raise ValueError('Civil term start requires an explicit official local time zone')
            try: ZoneInfo(term['startTimeZone'])
            except (ZoneInfoNotFoundError, ValueError) as error:
                raise ValueError('Civil term start has an invalid local time zone') from error
        if term.get('scheduledStart') and term.get('scheduledEnd') and instant(term['scheduledEnd']) <= instant(term['scheduledStart']):
            raise ValueError('Invalid term interval')
    return snapshot

def civil_start_is_due(term, now):
    """Compare civil dates in the official local zone without inventing a time.

    Reaching this day is only a prerequisite. It is never assumption-of-office
    evidence, and cannot itself promote an incoming official.
    """
    if not term.get('scheduledStartDate'):
        return True
    from datetime import date
    from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
    civil_start = date.fromisoformat(term['scheduledStartDate'])
    zone_name = term.get('startTimeZone')
    if not isinstance(zone_name, str) or not zone_name:
        raise ValueError('Civil term start requires an explicit official local time zone')
    try:
        zone = ZoneInfo(zone_name)
    except (ZoneInfoNotFoundError, ValueError) as error:
        raise ValueError('Civil term start has an invalid local time zone') from error
    if term.get('actualStart') and instant(term['actualStart']).astimezone(zone).date() < civil_start:
        raise ValueError('Actual service start precedes the verified local civil start date; review required')
    return now.astimezone(zone).date() >= civil_start


def transition(snapshot):
    """Only freshly fetched assumption evidence permits automatic promotion."""
    now = instant(snapshot['publishedAt'])
    proofs = {p['id']: p for p in snapshot['evidence']}
    for term in snapshot['terms']:
        if term['status'] not in ('incoming','incomingRecognized'):
            continue
        civil_due = civil_start_is_due(term, now)
        if not civil_due or (term.get('scheduledStart') and instant(term['scheduledStart']) > now):
            continue
        assumption = [proofs[p] for p in term['evidenceIds'] if proofs[p]['claim'] == 'assumedOffice' and now - instant(proofs[p]['retrievedAt']) <= timedelta(hours=24)]
        actual = term.get('actualStart')
        if not assumption or not actual or instant(actual) > now:
            continue
        for old in snapshot['terms']:
            if old['officeId'] == term['officeId'] and old['status'] == 'current':
                old['status'] = 'ended'
                old['actualEnd'] = actual
        term['status'] = 'current'
    for term in snapshot['terms']:
        if term['status'] == 'current' and term.get('scheduledEnd') and instant(term['scheduledEnd']) <= now:
            term['status'] = 'ended'
            term['actualEnd'] = term['scheduledEnd']
    return snapshot

def rebind_term_person(term, person_id, proofs):
    """Clone source bindings when a roster resolves a stable person identity."""
    if term['personId'] == person_id:
        return
    ids = []
    for proof_id in term['evidenceIds']:
        proof = dict(proofs[proof_id])
        proof['personId'] = person_id
        identity = '|'.join((proof['sourceId'], proof['officeId'], person_id,
                             proof['claim'], proof['sha256'], proof['url']))
        proof['id'] = hashlib.sha256(identity.encode()).hexdigest()[:24]
        proofs[proof['id']] = proof
        ids.append(proof['id'])
    term['personId'] = person_id
    term['evidenceIds'] = ids


def atomic_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = None
    try:
        with tempfile.NamedTemporaryFile('w', dir=path.parent, encoding='utf-8', delete=False) as f:
            temp = f.name
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write('\n')
            f.flush()
            os.fsync(f.fileno())
        os.replace(temp, path)
    finally:
        if temp and os.path.exists(temp): os.unlink(temp)

def refresh(previous, registry, plans, now, loader=fetch, include_elections=False):
    result = copy.deepcopy(previous or {'schemaVersion': 1, 'people': [], 'offices': [], 'terms': [], 'evidence': []})
    result['publishedAt'] = iso(now)
    result['displayPolicy'] = {'incomingDays': 90, 'pendingGraceDays': 7}
    sources = {s['id']: s for s in registry['sources']}
    people = {x['id']: x for x in result['people']}
    offices = {x['id']: x for x in result['offices']}
    terms = {x['id']: x for x in result['terms']}
    proofs = {x['id']: x for x in result['evidence']}
    cache = {}
    def download(source, url=None):
        url = url or source['url']
        if url not in cache:
            cache[url] = loader(url, source)
        return cache[url]
    legacy = {}
    for filename, key in [('senators.json', 'senators'), ('houseMembers.json', 'representatives')]:
        for state in json.loads((ROOT / 'assets/data' / filename).read_text()):
            for p in state[key]:
                if p.get('bioguideId'): legacy[p['bioguideId']] = p
    constitution = sources['constitution']
    constitution_raw = download(constitution)
    rule = 'The terms of the President and Vice President shall end at noon on the 20th day of January'
    if rule not in text_content(constitution_raw):
        raise ValueError('Constitutional term rule changed; review required')
    congress_rule = 'and the terms of Senators and Representatives at noon on the 3d day of January, of the years in which such terms would have ended if this article had not been ratified; and the terms of their successors shall then begin.'
    if congress_rule not in text_content(constitution_raw):
        raise ValueError('Constitutional Congress term-start and successor rule changed; review required')
    for source_id, parser in [('house-clerk', parse_house), ('senate-roster', parse_senate)]:
        source = sources[source_id]
        raw = download(source)
        records = parser(raw)
        if source_id == 'house-clerk':
            records = [r for r in records if r.get('swornDate') and datetime.strptime(r['swornDate'], '%Y%m%d').date() <= now.date()]
            if len(records) < 400: raise ValueError('Insufficient sworn House membership; preserve last snapshot')
        if source_id == 'senate-roster':
            for r in records:
                class_source = sources['senate-term-' + r['class']]
                class_raw = download(class_source)
                match = re.search(r'Class ' + r['class'] + r' - Senators Whose Terms? of Service Expire in (\d{4})', text_content(class_raw))
                if not match: raise ValueError('Senate class expiration not found')
                r['scheduledEnd'] = match[1] + '-01-03T17:00:00Z'
                r['period'] = r['class'] + ':' + match[1]
        observed = {r['officeId']: r['personId'] for r in records}
        for old in terms.values():
            office = offices[old['officeId']]
            if office['kind'] == records[0]['kind'] and old['status'] == 'current' and observed.get(old['officeId']) != old['personId']:
                old['status'] = 'ended'
                # Observation time is not an asserted historical resignation time.
                old['endedObservedAt'] = iso(now)
        for r in records:
            pid, oid = r['personId'], r['officeId']
            person = people.setdefault(pid, {'id': pid, 'name': r['name'], 'bioguideId': pid})
            person.update(name=r['name'], party=r.get('party'))
            # Existing portrait/website follows identity, never a seat number.
            old = legacy.get(pid, {})
            if old.get('photoLocalPath'): person['photoLocalPath'] = old['photoLocalPath']
            offices[oid] = {'id': oid, 'kind': r['kind'], 'branch': 'legislative', 'state': r['state'], 'district': r.get('district'), 'title': 'U.S. Senator' if r['kind'] == 'senate' else 'U.S. Representative'}
            for prior in terms.values():
                if prior['officeId'] == oid and prior['personId'] == pid and prior['status'] == 'current' and prior.get('scheduledEnd') and r.get('scheduledEnd') != prior['scheduledEnd'] and now < instant(prior['scheduledEnd']):
                    raise ValueError('Term calendar advanced before existing service expires; review required')
            if r.get('period'):
                for old_term in terms.values():
                    if old_term['officeId'] == oid and old_term['status'] == 'current' and old_term.get('period') != r['period']:
                        old_term['status'] = 'ended'
                        old_term['endedObservedAt'] = iso(now)
            for candidate in terms.values():
                if candidate['officeId']==oid and candidate['status'] in ('incoming','incomingRecognized'):
                    normalize=lambda value: re.sub(r'[^a-z0-9]','',value.lower())
                    if normalize(people[candidate['personId']]['name'])==normalize(r['name']):
                        alias = people[candidate['personId']]
                        people[pid] = {**alias, **people[pid], 'id': pid, 'bioguideId': pid}
                        rebind_term_person(candidate, pid, proofs)
            existing = [t for t in terms.values() if t['officeId'] == oid and t['personId'] == pid and t['status'] in ('current', 'incoming', 'incomingRecognized')]
            t = next((t for t in existing if t['status'] == 'current'), None)
            if t is None:
                # An incoming term can only be adopted once its verified start arrives.
                t = next((t for t in existing if (not t.get('scheduledStart') or instant(t['scheduledStart']) <= now)), None)
            tid = t['id'] if t else (f'{oid}:{pid}:congress:{r["congress"]}' if r.get('congress') else f'{oid}:{pid}:class:{r["period"]}')
            t = terms.setdefault(tid, {'id': tid, 'officeId': oid, 'personId': pid, 'status': 'current', 'evidenceIds': []})
            proof = evidence(source, raw, now, oid, pid, 'current')
            proofs[proof['id']] = proof
            # Keep the term's certification and start-law history when its
            # service is confirmed; replace only current-roster observations.
            t['evidenceIds'] = [p for p in t['evidenceIds']
                                if proofs[p]['claim'] not in ('current', 'scheduledEnd')]
            t['evidenceIds'].append(proof['id'])
            if r.get('scheduledEnd'):
                end_proof = evidence(constitution, constitution_raw, now, oid, pid, 'scheduledEnd', congress_rule)
                proofs[end_proof['id']] = end_proof
                t['evidenceIds'].append(end_proof['id'])
                if r['kind'] == 'senate':
                    class_source = sources['senate-term-' + r['class']]
                    class_raw = download(class_source)
                    class_proof = evidence(class_source, class_raw, now, oid, pid, 'scheduledEnd', r['scheduledEnd'][:4])
                    proofs[class_proof['id']] = class_proof
                    t['evidenceIds'].append(class_proof['id'])
            if t['status'] in ('incoming','incomingRecognized'):
                t['status'] = 'current'
                t['serviceConfirmedAt'] = iso(now)
            t['verifiedAt'] = iso(now)
            if r.get('congress'): t['congress'] = r['congress']
            t['period'] = r['period']
            if r.get('scheduledEnd'): t['scheduledEnd'] = r['scheduledEnd']
            if r.get('swornDate'): t['swornDate'] = datetime.strptime(r['swornDate'], '%Y%m%d').date().isoformat()
            t['contact'] = {k: r.get(k) for k in ('phone', 'address', 'website', 'contactUrl') if r.get(k)}
            # House XML omits websites: do not elevate the legacy website to verified.
            if r.get('website') and not allowed_url(r['website'], {'hosts': [urlparse(r['website']).hostname]}):
                raise ValueError('Unsafe contact URL')
    # Reviewed executive/judicial entries require exact excerpts from their official roster.
    reviewed = json.loads((ROOT / 'scripts/data/federal_reviewed_offices.json').read_text())
    for item in reviewed:
        source = sources[item['sourceId']]
        raw = download(source)
        if office_kind := item['office']['kind']:
            if office_kind in ('president', 'vicePresident'):
                headings = [text_content(x.encode()) for x in re.findall(r'<h2\b[^>]*>(.*?)</h2>', raw.decode(), re.S)]
                found = item['excerpt'] in headings
            elif office_kind == 'justice':
                headings = [text_content(x.encode()).rstrip(',') for x in re.findall(r'<strong\b[^>]*>(.*?)</strong>', raw.decode(), re.S)]
                found = item['excerpt'] in headings
            else:
                found = item['excerpt'] in text_content(raw)
        if not found:
            raise ValueError('Reviewed official is absent from roster: ' + item['person']['name'])
        person, office = item['person'], item['office']
        if office['kind'] in ('houseLeadership', 'senateLeadership') and person['id'] not in people:
            raise ValueError('Leadership identity absent from current federal roster')
        people.setdefault(person['id'], person)
        offices[office['id']] = office
        for old in terms.values():
            if old['officeId'] == office['id'] and old['personId'] != person['id'] and old['status'] == 'current':
                old['status'] = 'ended'
                old['endedObservedAt'] = iso(now)
        proof = evidence(source, raw, now, office['id'], person['id'], 'current', item['excerpt'])
        proofs[proof['id']] = proof
        tid = item['termId']
        extra_proofs = []
        if item.get('term', {}).get('scheduledEnd'):
            end_proof = evidence(constitution, constitution_raw, now, office['id'], person['id'], 'scheduledEnd', rule)
            proofs[end_proof['id']] = end_proof
            extra_proofs.append(end_proof['id'])
        terms[tid] = {'id': tid, 'officeId': office['id'], 'personId': person['id'], 'status': 'current', 'verifiedAt': iso(now), 'evidenceIds': [proof['id'], *extra_proofs], **item.get('term', {})}
    for person in plans['people']: people[person['id']] = person
    for office in plans['offices']: offices[office['id']] = office
    plan_proofs = {}
    for spec in plans['evidence']:
        source = sources[spec['sourceId']]
        if not allowed_url(spec['url'], source): raise ValueError('Unapproved evidence URL')
        raw = download(source, spec['url'])
        if not spec.get('excerpt') or spec['excerpt'] not in text_content(raw):
            raise ValueError('Transition evidence excerpt missing')
        if not spec.get('expectedSha256'):
            raise ValueError('Reviewed transition evidence requires a pinned source hash')
        if hashlib.sha256(raw).hexdigest() != spec['expectedSha256']:
            raise ValueError('Transition evidence changed; review required')
        proof = {**spec, 'sha256': hashlib.sha256(raw).hexdigest(), 'retrievedAt': iso(now)}
        proofs[spec['id']] = proof
        plan_proofs[spec['id']] = proof
    for t in plans['terms']:
        # Never reset an already promoted or ended term to incoming on the next run.
        if t['id'] in terms and terms[t['id']]['status'] in ('current', 'ended'): continue
        if any(p not in plan_proofs for p in t['evidenceIds']): raise ValueError('Plan lacks freshly checked evidence')
        terms[t['id']] = copy.deepcopy(t)
    result.update(people=list(people.values()), offices=list(offices.values()), terms=list(terms.values()), evidence=list(proofs.values()))
    if include_elections:
        try:
            from .election_adapters.senate_elect import add_to_snapshot
        except ImportError:
            from election_adapters.senate_elect import add_to_snapshot
        try:
            from .election_adapters.house_elect import add_to_snapshot as add_house
        except ImportError:
            from election_adapters.house_elect import add_to_snapshot as add_house
        coverage=[]
        for source_id, adapter in [('senate-elect-2026', add_to_snapshot), ('house-elect-newdem-2026', add_house)]:
            record={'sourceId':source_id,'checkedAt':iso(now)}
            candidate=copy.deepcopy(result)
            try:
                entries=adapter(candidate, registry,
                                lambda url,source: download({**source,'required':False},url),
                                now, evidence, iso)
                # Optional source errors cannot commit half an incoming list or
                # discard the last successfully verified recognition records.
                result=candidate
                record.update(status='retrieved',recognizedRecords=len(entries))
            except Exception as error:
                record.update(status='unavailable',error=f'{type(error).__name__}: {error}')
            coverage.append(record)
        result['incomingSourceCoverage']=coverage
    validate(result, registry)
    transition(result)
    validate(result, registry)
    used_proofs = {p for t in result['terms'] for p in t['evidenceIds']}
    result['evidence'] = [p for p in result['evidence'] if p['id'] in used_proofs]
    return result

def main():
    # Keep the original command as a safe compatibility entry point: checks only by default.
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from federal_data_pipeline import main as pipeline_main
    return pipeline_main()

if __name__ == '__main__':
    import sys
    sys.exit(main())
