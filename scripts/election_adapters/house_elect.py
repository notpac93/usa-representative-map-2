"""Partial official House caucus recognition, never election certification.

The named caucus release recognizes forty new members-elect. It is not a full
House roster, does not cover reelected incumbents, and supplies no party labels,
contact details, portraits, vote totals, certification, or assumption of office.
The caller enforces source hosts and archives each fetched government response.
"""
from html.parser import HTMLParser
import re
import unicodedata

URL = 'https://newdemocratcoalition.house.gov/media-center/press-releases/new-dems-welcome-40-new-members-coalition-grows-to-record-142-members'
SOURCE_ID = 'house-elect-newdem-2026'
EXPECTED_COUNT = 40
PUBLICATION_DATE = '2026-11-11'
TITLE_PREFIX = 'New Dems Welcome 40 New Members'
LIST_PREFIX = 'The following Members-Elect were admitted to the Coalition'
STATES = set('AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY'.split())
COVERAGE = {'scope': 'new_democrat_coalition_new_members_elect_only',
            'completeHouseRoster': False, 'includesReelectedMembers': False,
            'expectedRecords': EXPECTED_COUNT, 'certificationLevel': 'government_recognition_only'}


def compact(parts):
    return ' '.join(' '.join(parts).split())


class RecognitionList(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.div_depth = 0
        self.article_depth = None
        self.article_count = 0
        self.date = None
        self.heading = None
        self.headings = []
        self.paragraph = None
        self.armed = False
        self.list_depth = 0
        self.list_count = 0
        self.list_complete = False
        self.item = None
        self.items = []
        self.error = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'meta' and attrs.get('name') == 'date':
            if self.date is not None and self.date != attrs.get('content'):
                self.error = True
            self.date = attrs.get('content')
        if tag == 'div':
            self.div_depth += 1
            if attrs.get('id') == 'newscontent':
                self.article_depth = self.div_depth
                self.article_count += 1
        if self.article_depth is None:
            return
        if tag == 'h1':
            self.heading = []
            if self.armed: self.error = True
        if tag == 'p' and not self.list_depth:
            self.paragraph = []
        if tag == 'ul':
            if self.list_depth:
                self.error = True  # Nested lists are not a flat district roster.
                self.list_depth += 1
            elif self.armed:
                self.list_depth = 1
                self.list_count += 1
                self.armed = False
        if tag == 'li' and self.list_depth:
            if self.item is not None: self.error = True
            self.item = []
        if tag in ('script', 'style', 'table') and self.list_depth:
            self.error = True

    def handle_data(self, value):
        if self.article_depth is None: return
        if self.heading is not None: self.heading.append(value)
        if self.paragraph is not None: self.paragraph.append(value)
        if self.item is not None: self.item.append(value)

    def handle_endtag(self, tag):
        if self.article_depth is not None:
            if tag == 'h1' and self.heading is not None:
                self.headings.append(compact(self.heading))
                self.heading = None
            if tag == 'p' and self.paragraph is not None:
                if compact(self.paragraph).startswith(LIST_PREFIX):
                    if self.list_count: self.error = True
                    self.armed = True
                self.paragraph = None
            if tag == 'li' and self.list_depth:
                if self.item is None: self.error = True
                else: self.items.append(compact(self.item))
                self.item = None
            if tag == 'ul' and self.list_depth:
                self.list_depth -= 1
                if not self.list_depth:
                    self.list_complete = True
                    if self.item is not None: self.error = True
        if tag == 'div':
            if self.article_depth == self.div_depth:
                self.article_depth = None
            self.div_depth -= 1


def parse(raw):
    """Return only identities explicitly inside the reviewed members-elect list."""
    parser = RecognitionList()
    parser.feed(raw.decode('utf-8'))
    parser.close()
    if (parser.error or parser.article_count != 1 or parser.date != PUBLICATION_DATE or
            not any(h.startswith(TITLE_PREFIX) for h in parser.headings) or
            parser.list_count != 1 or not parser.list_complete or parser.list_depth or parser.item is not None):
        raise ValueError('House caucus recognition source edition or bounded list changed; review required')
    entries = []
    for value in parser.items:
        match = re.fullmatch(r'(.+?)\s+\(([A-Z]{2})-(\d{2})\)', value)
        if not match or match[2] not in STATES or not 0 <= int(match[3]) <= 99:
            raise ValueError('Unrecognized House member-elect identity or district')
        entries.append({'name': match[1], 'state': match[2], 'district': int(match[3])})
    if len(entries) != EXPECTED_COUNT or len({(e['state'], e['district']) for e in entries}) != EXPECTED_COUNT or len({e['name'].casefold() for e in entries}) != EXPECTED_COUNT:
        raise ValueError('House caucus recognition list must contain exactly forty distinct members and seats')
    return entries


def add_to_snapshot(snapshot, registry, fetch, now, evidence_factory, iso):
    """Add recognition-only records for this explicitly partial caucus source."""
    source = next(s for s in registry['sources'] if s['id'] == SOURCE_ID)
    raw = fetch(URL, source)
    entries = parse(raw)
    people = {p['id']: p for p in snapshot['people']}
    terms = {t['id']: t for t in snapshot['terms']}
    proofs = {p['id']: p for p in snapshot['evidence']}
    offices = {o['id']: o for o in snapshot['offices']}
    rule_source = next(s for s in registry['sources'] if s['id'] == 'constitution')
    rule_raw = fetch(rule_source['url'], rule_source)
    rule_text = 'and the terms of Senators and Representatives at noon on the 3d day of January, of the years in which such terms would have ended if this article had not been ratified; and the terms of their successors shall then begin.'
    if rule_text not in ' '.join(re.sub('<[^>]+>', ' ', rule_raw.decode('utf-8')).split()):
        raise ValueError('Federal start rule missing')
    for entry in entries:
        state, district = entry['state'], entry['district']
        oid = f'us:house:{state}{district:02}'
        office = offices.get(oid)
        if office is None or office['kind'] != 'house' or office['state'] != state or office.get('district') != district:
            raise ValueError('Unmatched House district: ' + oid)
        if not any(t['officeId'] == oid and t.get('scheduledEnd') == '2027-01-03T17:00:00Z' for t in snapshot['terms']):
            raise ValueError('Regular House cycle not corroborated: ' + oid)
        slug = re.sub('[^a-z0-9]+', '-', unicodedata.normalize('NFKD', entry['name']).encode('ascii', 'ignore').decode().lower()).strip('-')
        pid = f'us:person:house-elect:2026:{state}:{district:02}:{slug}'
        tid = f'{oid}:2026-election:{slug}'
        old = terms.get(tid)
        if old and old['status'] in ('current', 'ended', 'withdrawn', 'disputed', 'incoming'):
            continue  # Recognition must not downgrade certification or revive a closed term.
        people[pid] = {'id': pid, 'name': entry['name']}
        excerpt = f'{entry["name"]} ({state}-{district:02})'
        recognition = evidence_factory(source, raw, now, oid, pid, 'incomingRecognition', excerpt)
        start = evidence_factory(rule_source, rule_raw, now, oid, pid, 'scheduledStart', rule_text)
        for proof in (recognition, start): proofs[proof['id']] = proof
        terms[tid] = {'id': tid, 'officeId': oid, 'personId': pid, 'status': 'incomingRecognized',
                      'recognizedAt': old.get('recognizedAt', iso(now)) if old else iso(now),
                      'verifiedAt': iso(now), 'electionDate': '2026-11-03',
                      'recognitionSourcePublishedDate': PUBLICATION_DATE,
                      'certificationStatus': 'notVerified', 'scheduledStart': '2027-01-03T17:00:00Z',
                      'startDateStatus': 'verified_regular_term',
                      'evidenceIds': [recognition['id'], start['id']]}
    snapshot.update(people=list(people.values()), terms=list(terms.values()), evidence=list(proofs.values()))
    return entries
