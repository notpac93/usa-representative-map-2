#!/usr/bin/env python3
"""Build a public, versioned index of bills with official floor roll calls."""

import argparse
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta, timezone
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import sys
from threading import Lock
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET
from zoneinfo import ZoneInfo

HOUSE = 'https://clerk.house.gov'
SENATE = 'https://www.senate.gov/legislative/LIS'
GOVINFO = 'https://www.govinfo.gov'
FIRST_CONGRESS = 119
SENATE_PENDING_PAGE = b'<title>U.S. Senate: Roll Call Vote Unavailable</title>'
PENDING = object()
POSITIONS = {
    'yea': 'yes', 'aye': 'yes', 'nay': 'no', 'no': 'no',
    'present': 'present', 'present, giving live pair': 'present',
    'not voting': 'notVoting',
}
BILL_TYPES = {
    'hr': ('H.R.', 'house-bill'),
    's': ('S.', 'senate-bill'),
    'hjres': ('H.J.Res.', 'house-joint-resolution'),
    'sjres': ('S.J.Res.', 'senate-joint-resolution'),
    'hconres': ('H.Con.Res.', 'house-concurrent-resolution'),
    'sconres': ('S.Con.Res.', 'senate-concurrent-resolution'),
    'hres': ('H.Res.', 'house-resolution'),
    'sres': ('S.Res.', 'senate-resolution'),
}


class OfficialSources:
    def __init__(self, cache):
        self.cache = cache
        cache.mkdir(parents=True, exist_ok=True)
        self.lock = Lock()
        self.next_request = {}

    def get(self, url, hours=0, allow_missing=False):
        host = urlsplit(url).netloc
        key = hashlib.sha256(url.encode()).hexdigest()
        cached = self.cache / key
        if cached.exists() and time.time() - cached.stat().st_mtime < hours * 3600:
            return cached.read_bytes()
        for attempt in range(4):
            with self.lock:
                now = time.monotonic()
                start = max(now, self.next_request.get(host, now))
                self.next_request[host] = start + 0.25
            time.sleep(max(0, start - time.monotonic()))
            try:
                request = Request(url, headers={'User-Agent': 'USA-Representative-Map/1.0 congressional-data-sync'})
                with urlopen(request, timeout=30) as response:
                    if urlsplit(response.url).hostname != urlsplit(url).hostname:
                        raise ValueError(f'Unexpected redirect for {url}')
                    raw = response.read(25_000_001)
                    if not raw or len(raw) > 25_000_000:
                        raise ValueError(f'Unexpected document size for {url}')
                if not url.endswith('.xml') or 'html' not in response.headers.get('Content-Type', '').lower():
                    cached.write_bytes(raw)
                return raw
            except HTTPError as exc:
                if exc.code == 404 and allow_missing:
                    return None
                if exc.code not in (408, 429, 500, 502, 503, 504):
                    raise
                retry_after = exc.headers.get('Retry-After', '')
            except (URLError, TimeoutError):
                retry_after = ''
            if attempt < 3:
                delay = int(retry_after) if retry_after.isdigit() else 2 ** attempt
                time.sleep(min(60, delay))
        raise RuntimeError(f'Could not retrieve {url} after four attempts')


def xml(raw, root_tag):
    root = ET.fromstring(raw)
    for node in root.iter():
        node.tag = node.tag.rsplit('}', 1)[-1]
    if root.tag != root_tag:
        raise ValueError(f'Expected {root_tag} document, found {root.tag}')
    return root


def value(node, path):
    return (node.findtext(path) or '').strip()


def bill_key(congress, reference):
    match = re.fullmatch(r'([a-z]+)([1-9][0-9]*)', re.sub(r'[.\s]', '', reference.lower()))
    if match and match[1] in BILL_TYPES and str(congress).isdigit():
        return int(congress), match[1], int(match[2])
    return None


def member(identifier, name, state, party, vote, district=''):
    return {
        'id': identifier or f'{state}:{name}', 'name': name, 'state': state,
        'party': party, 'district': district, 'vote': vote,
        'position': POSITIONS.get(vote.casefold(), 'other'),
    }


def validate_members(rows, official, context):
    if not rows or any(not row['name'] or not row['vote'] or not row['id'] for row in rows):
        raise ValueError(f'{context}: missing member vote data')
    if len({row['id'] for row in rows}) != len(rows):
        raise ValueError(f'{context}: duplicate member IDs')
    counts = Counter(row['position'] for row in rows)
    expected = {key: int(total) for key, total in official.items() if total}
    if not {'yes', 'no', 'notVoting'} <= expected.keys():
        raise ValueError(f'{context}: missing official vote totals')
    if any(counts[key] != count for key, count in expected.items()) or counts['other']:
        raise ValueError(f'{context}: published totals {expected} disagree with member rows {counts}')
    return {key: counts[key] for key in ('yes', 'no', 'present', 'notVoting')}


def ordinal(text):
    match = re.fullmatch(r'(\d+)(?:st|nd|rd|th)?', text, re.I)
    if not match:
        raise ValueError(f'Invalid ordinal: {text}')
    return int(match[1])


def house_record(raw, congress, session, number, year):
    root = xml(raw, 'rollcall-vote')
    meta = root.find('vote-metadata')
    if meta is None or (
        ordinal(value(meta, 'congress')),
        ordinal(value(meta, 'session')),
        int(value(meta, 'rollcall-num')),
    ) != (congress, session, number):
        raise ValueError(f'House {year} roll {number}: source identity mismatch')
    key = bill_key(congress, value(meta, 'legis-num'))
    if not key:
        return None
    rows = []
    for entry in root.findall('vote-data/recorded-vote'):
        legislator = entry.find('legislator')
        rows.append(member(
            legislator.get('name-id', ''), legislator.get('unaccented-name') or (legislator.text or '').strip(),
            legislator.get('state', ''), legislator.get('party', ''), value(entry, 'vote'),
            legislator.get('district', ''),
        ))
    tally = 'vote-totals/totals-by-vote/'
    totals = {
        'yes': value(meta, tally + 'yea-total') or value(meta, tally + 'aye-total'),
        'no': value(meta, tally + 'nay-total') or value(meta, tally + 'no-total'),
        'present': value(meta, tally + 'present-total'),
        'notVoting': value(meta, tally + 'not-voting-total'),
    }
    return key, {
        'chamber': 'House', 'congress': congress, 'session': session, 'roll': number,
        'date': datetime.strptime(value(meta, 'action-date'), '%d-%b-%Y').date().isoformat(),
        'time': value(meta, 'action-time'), 'question': value(meta, 'vote-question'),
        'description': value(meta, 'vote-desc'), 'result': value(meta, 'vote-result'),
        'amendment': value(meta, 'amendment-num'), 'amendmentDetail': value(meta, 'amendment-author'),
        'url': f'{HOUSE}/Votes/{year}{number}',
        'xmlUrl': f'{HOUSE}/evs/{year}/roll{number:03d}.xml',
        'counts': validate_members(rows, totals, f'House {year} roll {number}'),
        'members': rows,
    }


def senate_record(raw, congress, session, number):
    root = xml(raw, 'roll_call_vote')
    if tuple(int(value(root, field)) for field in ('congress', 'session', 'vote_number')) != (congress, session, number):
        raise ValueError(f'Senate {congress}/{session}/{number}: source identity mismatch')
    key = bill_key(congress, value(root, 'amendment/amendment_to_document_number'))
    if key is None:
        key = bill_key(
            value(root, 'document/document_congress') or congress,
            value(root, 'document/document_type') + value(root, 'document/document_number'),
        )
    if not key:
        return None
    rows = [
        member(
            value(entry, 'lis_member_id'),
            ', '.join(part for part in (value(entry, 'last_name'), value(entry, 'first_name')) if part)
            or value(entry, 'member_full'),
            value(entry, 'state'), value(entry, 'party'), value(entry, 'vote_cast'),
        )
        for entry in root.findall('members/member')
    ]
    # The Secretary leaves tally fields empty when a category has no votes.
    totals = {
        position: value(root, f'count/{field}') or '0'
        for position, field in (('yes', 'yeas'), ('no', 'nays'), ('present', 'present'), ('notVoting', 'absent'))
        if root.find(f'count/{field}') is not None
    }
    tie_breaker = value(root, 'tie_breaker/tie_breaker_vote')
    # Senate tallies can include the separately reported vice-presidential vote.
    tie_position = POSITIONS.get(tie_breaker.casefold())
    if tie_position in ('yes', 'no') and totals[tie_position]:
        member_total = sum(row['position'] == tie_position for row in rows)
        if int(totals[tie_position]) == member_total + 1:
            totals[tie_position] = str(member_total)
    url = f'{SENATE}/roll_call_votes/vote{congress}{session}/vote_{congress}_{session}_{number:05d}'
    month_day, year, *clock = value(root, 'vote_date').split(', ')
    amendment = value(root, 'amendment/amendment_number')
    return key, {
        'chamber': 'Senate', 'congress': congress, 'session': session, 'roll': number,
        'date': datetime.strptime(f'{month_day}, {year}', '%B %d, %Y').date().isoformat(),
        'time': ', '.join(clock).strip(), 'question': value(root, 'vote_question_text') or value(root, 'vote_question'),
        'description': value(root, 'vote_title'), 'result': value(root, 'vote_result_text') or value(root, 'vote_result'),
        'amendment': amendment,
        'amendmentDetail': value(root, 'amendment/amendment_purpose') if amendment else '',
        'tieBreaker': tie_breaker, 'url': url + '.htm', 'xmlUrl': url + '.xml',
        'counts': validate_members(rows, totals, f'Senate {congress}/{session}/{number}'),
        'members': rows,
    }


class BillSummary(HTMLParser):
    def __init__(self, markup):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.feed(markup)
        self.close()

    def handle_starttag(self, tag, attrs):
        if tag in ('li', 'br'):
            self.parts.append('\n')

    def handle_endtag(self, tag):
        if tag in ('p', 'ul', 'ol', 'div'):
            self.parts.append('\n\n')

    def handle_data(self, text):
        self.parts.append(re.sub(r'\s+', ' ', text))

    def text(self):
        return re.sub(r'\n{3,}', '\n\n', ''.join(self.parts)).strip()


def ordinal_label(number):
    suffix = 'th' if 11 <= number % 100 <= 13 else {1: 'st', 2: 'nd', 3: 'rd'}.get(number % 10, 'th')
    return f'{number}{suffix}'


def congress_url(key):
    congress, kind, number = key
    return f'https://www.congress.gov/bill/{ordinal_label(congress)}-congress/{BILL_TYPES[kind][1]}/{number}'


def bill_details(raw, key):
    congress, kind, number = key
    if raw is None:
        return None
    bill = xml(raw, 'billStatus').find('bill')
    if bill is None or (int(value(bill, 'congress')), value(bill, 'type').lower(), int(value(bill, 'number'))) != key:
        raise ValueError(f'GovInfo bill identity mismatch for {key}')
    if not value(bill, 'title'):
        raise ValueError(f'GovInfo bill has no title for {key}')
    summaries = [
        {'date': value(item, 'actionDate'), 'stage': value(item, 'actionDesc') or value(item, 'name'),
         'text': BillSummary(value(item, 'text')).text()}
        for item in bill.findall('summaries/summary') + bill.findall('summaries/billSummaries/item')
        if value(item, 'text')
    ]
    related = []
    for item in bill.findall('relatedBills/item'):
        reference = bill_key(value(item, 'congress'), value(item, 'type') + value(item, 'number'))
        if reference:
            related.append({
                'title': value(item, 'title'),
                'relationship': value(item, 'relationshipDetails/item/type'),
                'url': congress_url(reference),
            })
    return {
        'title': value(bill, 'title'), 'introduced': value(bill, 'introducedDate'),
        'latestAction': value(bill, 'latestAction/text'), 'latestActionDate': value(bill, 'latestAction/actionDate'),
        'policyArea': value(bill, 'policyArea/name') or value(bill, 'subjects/billSubjects/primarySubjects/name'),
        'subjects': [
            value(item, 'name') for item in (
                bill.findall('subjects/legislativeSubjects/item')
                + bill.findall('subjects/billSubjects/otherSubjects/item')
            )
        ],
        'sponsors': [value(item, 'fullName') or value(item, 'name') for item in bill.findall('sponsors/item')],
        'cosponsors': [value(item, 'fullName') for item in bill.findall('cosponsors/item')],
        'committees': [value(item, 'name') for item in bill.findall('committees/item')],
        'laws': [f"{value(item, 'type')} {value(item, 'number')}".strip() for item in bill.findall('laws/item')],
        'committeeReports': [
            value(item, 'citation') for item in bill.findall('committeeReports/committeeReport')
        ],
        'costEstimates': [
            {'title': value(item, 'title'), 'description': value(item, 'description'), 'url': url}
            for item in bill.findall('cboCostEstimates/item')
            if (url := value(item, 'url')).startswith('https://www.cbo.gov/')
        ],
        'relatedBills': related,
        'textVersions': [
            {'date': value(item, 'date')[:10], 'stage': value(item, 'type'), 'url': url}
            for item in bill.findall('textVersions/item')
            if (url := value(item, 'formats/item/url')).startswith(GOVINFO + '/')
        ],
        'summaries': sorted(summaries, key=lambda item: item['date'], reverse=True),
        'actions': [
            {'date': value(item, 'actionDate'), 'text': value(item, 'text')}
            for item in bill.findall('actions/item') if value(item, 'text')
        ],
    }


def session_year(congress, session):
    return 1789 + (congress - 1) * 2 + session - 1


def house_rolls(source, congress, session, previous, archived, executor):
    year = session_year(congress, session)
    archive = f'{HOUSE}/evslegacy/{year}'
    session_label = '1st' if session == 1 else '2nd'
    legacy = source.get(f'{archive}/index.asp', hours=1, allow_missing=True)
    current = source.get(
        f'{HOUSE}/Votes/MemberVotes?CongressNum={congress}&Session={session_label}',
        hours=1,
    )
    published = set(int(n) for n in re.findall(rb'/Votes/' + str(year).encode() + rb'(\d+)(?=\b)', current, re.I))
    if legacy:
        pages = re.findall(rb'href=["\']?(ROLL_\d+\.asp)', legacy, flags=re.I)
        documents = [legacy]
        documents.extend(executor.map(
            lambda path: source.get(f'{archive}/{path.decode()}', hours=6), sorted(set(pages))
        ))
        for document in documents:
            published.update(int(n) for n in re.findall(rb'rollnumber=(\d+)', document, re.I))
    if missing := set(previous) - published:
        raise ValueError(f'House {year}: missing Clerk roll calls {sorted(missing)}')
    if archived and not published:
        raise ValueError(f'House {year}: archived session has no roll calls')
    # House numbers are sequential within the session. A missing index page
    # should not silently turn into missing saved member records.
    numbers = range(1, max(published, default=0) + 1)

    def load(number):
        url = f'{HOUSE}/evs/{year}/roll{number:03d}.xml'
        raw = source.get(url, hours=168 if archived else 24)
        try:
            return house_record(raw, congress, session, number, year)
        except (ValueError, ET.ParseError) as error:
            raise ValueError(f'{url}: {error}') from error

    return dict(zip(numbers, executor.map(load, numbers), strict=True))


def senate_rolls(source, congress, session, previous, archived, executor):
    url = f'{SENATE}/roll_call_lists/vote_menu_{congress}_{session}.xml'
    raw = source.get(url, hours=1, allow_missing=not archived and not previous)
    if raw is None:
        return {}
    root = ET.fromstring(raw)
    if (int(value(root, 'congress')), int(value(root, 'session'))) != (congress, session):
        raise ValueError(f'Senate {congress}/{session}: invalid roll-call index')
    numbers = sorted({int(value(row, 'vote_number')) for row in root.findall('votes/vote')})
    if set(previous) - set(numbers) or archived and not numbers:
        raise ValueError(f'Senate {congress}/{session}: official index lost roll calls')

    def load(number):
        url = f'{SENATE}/roll_call_votes/vote{congress}{session}/vote_{congress}_{session}_{number:05d}.xml'
        raw = source.get(url, hours=168 if archived else 24)
        if SENATE_PENDING_PAGE in raw:
            return PENDING
        try:
            return senate_record(raw, congress, session, number)
        except (ValueError, ET.ParseError) as error:
            raise ValueError(f'{url}: {error}') from error

    return dict(zip(numbers, executor.map(load, numbers), strict=True))


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    pending = path.with_suffix('.tmp')
    pending.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    pending.replace(path)


def refresh(source, output, congress, today, executor, previous):
    first_year = session_year(congress, 1)
    number_index = previous.get('rollNumbers', {})
    coverage = {}
    pending = {}
    grouped = defaultdict(list)
    def collect_session(collect, session, label, archived):
        with ThreadPoolExecutor(max_workers=6) as chamber_workers:
            return collect(source, congress, session, number_index.get(label, []), archived, chamber_workers)

    with ThreadPoolExecutor(max_workers=4) as chamber_sessions:
        jobs = {}
        for session in (1, 2):
            year = session_year(congress, session)
            if today < date(year, 1, 3):
                continue
            for chamber, collect in (('House', house_rolls), ('Senate', senate_rolls)):
                label = f'{chamber}:{session}'
                jobs[label] = chamber_sessions.submit(collect_session, collect, session, label, year < today.year)
        for label, job in jobs.items():
            rolls = job.result()
            coverage[label] = sorted(rolls)
            waiting = [number for number, entry in rolls.items() if entry is PENDING]
            formerly_pending = previous.get('pendingRolls', {}).get(label, [])
            if missing := set(waiting) & (set(number_index.get(label, [])) - set(formerly_pending)):
                raise ValueError(f'{congress} {label}: previously available rolls became unavailable: {sorted(missing)}')
            if waiting:
                pending[label] = sorted(waiting)
            for entry in rolls.values():
                if entry and entry is not PENDING:
                    key, vote = entry
                    grouped[key].append(vote)
            print(f'{congress} {label}: {len(rolls)} rolls indexed, {len(waiting)} awaiting source details', flush=True)

    if not grouped and today > date(first_year, 1, 10):
        raise ValueError(f'No bill-linked roll calls found for Congress {congress}')
    previous_bills = {item['id']: item for item in previous.get('bills', [])}

    def enrich(key):
        bill_congress, kind, number = key
        votes = sorted(grouped[key], key=lambda row: (row['date'], row['chamber'], row['roll']), reverse=True)
        bill_id = f'{bill_congress}-{kind}-{number}'
        display = BILL_TYPES[kind][0]
        govinfo = f'{GOVINFO}/bulkdata/BILLSTATUS/{bill_congress}/{kind}/BILLSTATUS-{bill_congress}{kind}{number}.xml'
        metadata = bill_details(source.get(govinfo, hours=24, allow_missing=True), key)
        if metadata is None and previous_bills.get(bill_id, {}).get('hasMetadata'):
            raise ValueError(f'GovInfo lost previously published data for {bill_id}')
        old_rolls = set(previous_bills.get(bill_id, {}).get('rollIds', []))
        roll_ids = sorted(f"{vote['chamber']}:{vote['session']}:{vote['roll']}" for vote in votes)
        if old_rolls - set(roll_ids):
            raise ValueError(f'Previously published rolls missing for {bill_id}')
        entry = {
            'id': bill_id, 'label': f'{display} {number}', 'congress': bill_congress,
            'title': metadata['title'] if metadata else f'{display} {number}',
            'latestVote': votes[0]['date'], 'rollIds': roll_ids, 'hasMetadata': metadata is not None,
            'chambers': sorted({vote['chamber'] for vote in votes}),
            'congressUrl': congress_url(key),
            'metadataUrl': govinfo,
        }
        detail = dict(entry, metadata=metadata, votes=votes)
        revision = hashlib.sha256(json.dumps(detail, ensure_ascii=False).encode()).hexdigest()[:16]
        entry['path'] = f'{congress}/bills/{bill_id}-{revision}.json'
        return entry, detail

    if missing := previous_bills.keys() - {f'{c}-{k}-{n}' for c, k, n in grouped}:
        raise ValueError(f'Previously published measures missing from Congress {congress}: {sorted(missing)}')
    bills = []
    for entry, detail in executor.map(enrich, sorted(grouped)):
        write_json(output / entry['path'], detail)
        bills.append(entry)
    return {
        'congress': congress, 'rollNumbers': coverage, 'pendingRolls': pending,
        'bills': sorted(bills, key=lambda bill: bill['latestVote'], reverse=True),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--cache', type=Path, default=Path('tmp/congress-votes-cache'))
    parser.add_argument('--congress', type=int, help='Rebuild just this Congress')
    args = parser.parse_args()
    index_path = args.output / 'index.json'
    existing = json.loads(index_path.read_text()) if index_path.exists() else {'schema': 1, 'congresses': []}
    if existing['schema'] != 1:
        raise ValueError('Unexpected existing snapshot schema')
    congresses = {item['congress']: item for item in existing['congresses']}
    today = datetime.now(ZoneInfo('America/New_York')).date()
    legislative_year = today.year - int(today.month == 1 and today.day < 3)
    active = (legislative_year - 1789) // 2 + 1
    requested = [args.congress] if args.congress is not None else [
        number for number in range(FIRST_CONGRESS, active + 1)
        if number not in congresses or number >= active - 1
    ]
    if not requested or not all(FIRST_CONGRESS <= number <= active for number in requested):
        parser.error(f'Choose an available Congress between {FIRST_CONGRESS} and {active}')
    source = OfficialSources(args.cache)
    with ThreadPoolExecutor(max_workers=8) as executor:
        for number in requested:
            congresses[number] = refresh(source, args.output, number, today, executor, congresses.get(number, {}))
    write_json(index_path, {
        'schema': 1, 'checkedAt': datetime.now(timezone.utc).isoformat(),
        'congresses': [congresses[number] for number in sorted(congresses, reverse=True)],
    })


if __name__ == '__main__':
    try:
        main()
    except (ValueError, RuntimeError, OSError, ET.ParseError) as error:
        sys.exit(f'Congressional votes refresh failed: {error}')
