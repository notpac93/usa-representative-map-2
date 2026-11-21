#!/usr/bin/env python3
"""Build the embedded congressional roster from official bulk snapshots.

No government requests run in the app. See docs/CONGRESSIONAL_DATA_SOURCES.md.
Uses only the Python standard library; failed validation never publishes assets.
"""
import argparse
from collections import Counter
from datetime import datetime, timezone
import gzip
import hashlib
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import tempfile
import unicodedata
import urllib.request
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    'house.xml': 'https://clerk.house.gov/xml/lists/MemberData.xml',
    'senate.xml': 'https://www.senate.gov/general/contact_information/senators_cfm.xml',
    'house-directory.html': 'https://www.house.gov/representatives',
}
STATES = dict(pair.split(':') for pair in (
    'AL:Alabama|AK:Alaska|AZ:Arizona|AR:Arkansas|CA:California|CO:Colorado|'
    'CT:Connecticut|DE:Delaware|FL:Florida|GA:Georgia|HI:Hawaii|ID:Idaho|'
    'IL:Illinois|IN:Indiana|IA:Iowa|KS:Kansas|KY:Kentucky|LA:Louisiana|'
    'ME:Maine|MD:Maryland|MA:Massachusetts|MI:Michigan|MN:Minnesota|'
    'MS:Mississippi|MO:Missouri|MT:Montana|NE:Nebraska|NV:Nevada|'
    'NH:New Hampshire|NJ:New Jersey|NM:New Mexico|NY:New York|'
    'NC:North Carolina|ND:North Dakota|OH:Ohio|OK:Oklahoma|OR:Oregon|'
    'PA:Pennsylvania|RI:Rhode Island|SC:South Carolina|SD:South Dakota|'
    'TN:Tennessee|TX:Texas|UT:Utah|VT:Vermont|VA:Virginia|WA:Washington|'
    'WV:West Virginia|WI:Wisconsin|WY:Wyoming|DC:District of Columbia|'
    'AS:American Samoa|GU:Guam|MP:Northern Mariana Islands|PR:Puerto Rico|'
    'VI:Virgin Islands'
).split('|'))
TERRITORIES = {'DC', 'AS', 'GU', 'MP', 'PR', 'VI'}
# 2020 apportionment, serving Congresses 118-122. This is a coverage check,
# not a geographic district resolver. Rollovers require an explicit update.
HOUSE_COUNTS = dict(zip(
    'AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY'.split(),
    [7,1,9,4,52,8,5,1,28,14,2,2,17,9,4,4,6,6,2,8,9,13,8,4,8,2,3,4,2,12,3,26,14,1,15,5,6,17,2,7,1,9,38,4,1,11,10,2,8,1],
))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def text(node, path):
    return (node.findtext(path) or '').strip()


def normalized(value):
    return re.sub('[^a-z0-9]', '', unicodedata.normalize('NFKD', value).lower())


def directory_identity(value):
    # Both sources use "surname, given name"; the directory sometimes adds
    # a middle initial. Keep the full surname and first given name.
    parts = value.split(',', 1)
    require(len(parts) == 2 and parts[1].strip(), f'Unexpected name format: {value}')
    return normalized(parts[0]), normalized(parts[1].split()[0])


def official_url(value, domain):
    if not value:
        return None
    parsed = urllib.parse.urlparse(value)
    require(parsed.scheme in ('https', 'http') and not parsed.username and
            not parsed.password and parsed.port in (None, 80, 443) and
            (parsed.hostname == domain or (parsed.hostname or '').endswith('.' + domain)),
            f'Unexpected official URL: {value}')
    # Retain the exact URL published by the source; do not invent HTTPS support.
    return value


class HouseDirectory(HTMLParser):
    """Parse only state-captioned tables; ignore duplicate alphabetical tables."""
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.rows = {}
        self.state = None
        self.caption = None
        self.cells = []
        self.cell = None
        self.links = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'table':
            self.state = None
        elif tag == 'caption' and attrs.get('id', '').startswith('state-'):
            self.caption = ''
        elif tag == 'tr':
            self.cells = []
            self.links = []
        elif tag == 'td':
            self.cell = ''
        elif tag == 'a' and self.cell is not None and len(self.cells) == 1:
            self.links.append(attrs.get('href', ''))

    def handle_data(self, data):
        if self.caption is not None:
            self.caption += data
        if self.cell is not None:
            self.cell += data

    def handle_endtag(self, tag):
        if tag == 'caption' and self.caption is not None:
            label = normalized(self.caption)
            aliases = {'usvirginislands': 'VI', 'commonwealthofthenorthernmarianaislands': 'MP'}
            self.state = aliases.get(label) or next((k for k, v in STATES.items() if normalized(v) == label), None)
            require(self.state is not None, f'Unrecognized directory state: {self.caption}')
            self.caption = None
        elif tag == 'td' and self.cell is not None:
            self.cells.append(' '.join(self.cell.split()))
            self.cell = None
        elif tag == 'tr' and self.state and self.cells:
            district = self.cells[0]
            match = re.search(r'\d+', district)
            number = int(match.group()) if match else 0
            key = f'{self.state}{number:02}'
            require(key not in self.rows, f'Duplicate House directory seat: {key}')
            require(len(self.cells) >= 5, f'Malformed House directory row: {key}')
            self.rows[key] = {'name': self.cells[1], 'website': self.links[0] if self.links else None}
        elif tag == 'table':
            self.state = None


def parse_house(body, directory_body, congress):
    root = ET.fromstring(body)
    require(root.tag == 'MemberData', 'Unexpected House XML schema')
    require(text(root, 'title-info/congress-num') == str(congress), 'Unexpected House Congress; review rollover before publishing')
    require(118 <= congress <= 122, 'Review seat apportionment for this Congress')
    directory = HouseDirectory()
    directory.feed(directory_body.decode('utf-8'))
    records, vacancies, seen, ids = [], [], set(), set()
    for member in root.findall('members/member'):
        source_key = text(member, 'statedistrict')
        # Clerk uses AQ00 for American Samoa; its state element uses postal AS.
        key = 'AS00' if source_key == 'AQ00' else source_key
        info = member.find('member-info')
        require(info is not None and re.fullmatch(r'[A-Z]{2}\d{2}', key), 'Malformed House seat')
        state, district = key[:2], int(key[2:])
        require(state in STATES and key not in seen, f'Unknown/duplicate House seat: {key}')
        seen.add(key)
        state_element = info.find('state')
        require(state_element is not None and state_element.get('postal-code') == state, f'State mismatch: {key}')
        name, bioguide = text(info, 'official-name'), text(info, 'bioguideID')
        if not name or not bioguide:
            require(not name and not bioguide and 'vacancy' in text(info, 'footnote').lower(), f'Unexplained missing House member: {key}')
            vacancies.append({'officeId': f'house:{key}', 'stateId': state, 'districtNumber': district, 'reason': text(info, 'footnote')})
            continue
        require(re.fullmatch(r'[A-Z]\d{6}', bioguide) and bioguide not in ids, f'Invalid/duplicate House Bioguide ID: {bioguide}')
        ids.add(bioguide)
        entry = directory.rows.get(key)
        require(entry is not None, f'House directory missing {key}')
        # Require agreement on identity as well as seat before borrowing a URL.
        require(directory_identity(entry['name']) == directory_identity(text(info, 'namelist')), f'House sources disagree on occupant: {key}: {entry["name"]} / {text(info, "namelist")}')
        website = official_url(entry['website'], 'house.gov')
        require(website is not None, f'Missing official website for {key}')
        records.append({
            'officeId': f'house:{key}', 'stateId': state, 'name': name,
            'bioguideId': bioguide, 'party': text(info, 'party'),
            'district': text(info, 'district'), 'districtNumber': district,
            'isAtLarge': district == 0, 'isDelegate': state in TERRITORIES,
            'phone': text(info, 'phone'),
            'office': ' '.join(filter(None, [text(info, 'office-room'), text(info, 'office-building')])),
            'website': website, 'contactUrl': None, 'email': None, 'fax': None,
            'sourceUrl': SOURCES['house.xml'], 'websiteSourceUrl': SOURCES['house-directory.html'],
            'swornDate': info.find('sworn-date').get('date') if info.find('sworn-date') is not None else None,
        })
    expected = {f'{state}{number:02}' for state, count in HOUSE_COUNTS.items() for number in ([0] if count == 1 else range(1, count + 1))}
    expected |= {f'{state}00' for state in TERRITORIES}
    require(seen == expected, f'Incomplete House seat coverage: missing {sorted(expected-seen)}, extra {sorted(seen-expected)}')
    require(set(directory.rows) == expected, 'Incomplete House directory coverage')
    return records, vacancies, root.get('publish-date')


def parse_senate(body):
    root = ET.fromstring(body)
    require(root.tag == 'contact_information', 'Unexpected Senate XML schema')
    records, ids, seats = [], set(), set()
    for member in root.findall('member'):
        state, bioguide = text(member, 'state'), text(member, 'bioguide_id')
        seat = f'{state}:{text(member, "class")}'
        require(state in HOUSE_COUNTS and seat not in seats, f'Unknown/duplicate Senate seat: {seat}')
        require(re.fullmatch(r'Class (I|II|III)', text(member, 'class')), f'Invalid Senate class: {seat}')
        require(re.fullmatch(r'[A-Z]\d{6}', bioguide) and bioguide not in ids, f'Invalid/duplicate Senate Bioguide ID: {bioguide}')
        require(text(member, 'first_name') and text(member, 'last_name'), 'Missing Senate name')
        ids.add(bioguide)
        seats.add(seat)
        website = official_url(text(member, 'website'), 'senate.gov')
        contact = official_url(text(member, 'email'), 'senate.gov')
        records.append({
            'officeId': f'senate:{seat}', 'stateId': state,
            'name': f'{text(member, "first_name")} {text(member, "last_name")}',
            'bioguideId': bioguide, 'party': text(member, 'party'),
            'senateClass': text(member, 'class'), 'phone': text(member, 'phone'),
            'officeAddress': text(member, 'address'), 'website': website,
            'contactUrl': contact, 'email': None, 'fax': None,
            'sourceUrl': SOURCES['senate.xml'],
        })
    # This source does not document vacancy records. Missing seats require review,
    # never silently carry over a departed senator or assume a vacancy.
    require(Counter(r['stateId'] for r in records) == Counter({s: 2 for s in HOUSE_COUNTS}), 'Incomplete Senate coverage; review official vacancy evidence before publishing')
    return records


def group(records, member_key):
    return [{'stateId': state, 'state': STATES[state], member_key: [r for r in records if r['stateId'] == state]}
            for state in sorted({r['stateId'] for r in records})]


def photos_by_id(asset_root):
    """Retain cosmetic assets only by stable person ID, never by seat or name."""
    result = {}
    for file, key in [('houseMembers.json', 'representatives'), ('senators.json', 'senators')]:
        path = asset_root / file
        if path.exists():
            for g in json.loads(path.read_text()):
                for r in g[key]:
                    if r.get('bioguideId'):
                        result[r['bioguideId']] = {k: r[k] for k in ['photoLocalPath', 'photoUrl'] if r.get(k)}
    return result


def read_snapshot(folder):
    manifest = json.loads((folder / 'manifest.json').read_text())
    bodies = {}
    for name, url in SOURCES.items():
        body = gzip.decompress((folder / (name + '.gz')).read_bytes())
        source = manifest['sources'][name]
        require(source['url'] == url and source['sha256'] == hashlib.sha256(body).hexdigest(), f'Snapshot provenance/hash mismatch: {name}')
        bodies[name] = body
    return bodies, manifest


def build(bodies, manifest, congress, photos=None):
    house, vacancies, published = parse_house(bodies['house.xml'], bodies['house-directory.html'], congress)
    senate = parse_senate(bodies['senate.xml'])
    for record in house + senate:
        record.update((photos or {}).get(record['bioguideId'], {}))
    # Stable for a given acquisition and input; rebuilding does not reset freshness.
    version = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()[:16]
    return {'schemaVersion': 1, 'version': version, 'congress': congress,
            'retrievedAt': manifest['retrievedAt'], 'housePublishedAt': published,
            'sources': manifest['sources'], 'house': group(house, 'representatives'),
            'senate': group(senate, 'senators'), 'vacancies': vacancies,
            'delivery': {'configured': False, 'reason': 'No delivery provider or chamber approval configured.'}}


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=path.name + '.', suffix='.tmp')
    try:
        with os.fdopen(fd, 'w') as out:
            json.dump(value, out, indent=2, ensure_ascii=False)
            out.write('\n')
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def download(folder):
    folder.mkdir(parents=True, exist_ok=True)
    manifest = {'retrievedAt': datetime.now(timezone.utc).isoformat(), 'sources': {}}
    for name, url in SOURCES.items():
        request = urllib.request.Request(url, headers={'User-Agent': 'USARepresentativeMap-DataImport/1.0'})
        with urllib.request.urlopen(request, timeout=45) as response:
            require(response.status == 200, f'Failed source: {name}')
            require(urllib.parse.urlparse(response.url).hostname == urllib.parse.urlparse(url).hostname, 'Unexpected source redirect')
            body = response.read(10_000_001)
            require(len(body) <= 10_000_000, 'Unexpected source size')
        (folder / (name + '.gz')).write_bytes(gzip.compress(body, mtime=0))
        manifest['sources'][name] = {'url': url, 'sha256': hashlib.sha256(body).hexdigest(), 'bytes': len(body)}
    atomic_json(folder / 'manifest.json', manifest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, default=ROOT / 'data/sources/congress')
    parser.add_argument('--download', action='store_true', help='Fetch official sources before building; omitted = fully offline')
    parser.add_argument('--congress', type=int, required=True, help='Expected serving Congress; fail on unreviewed rollover')
    parser.add_argument('--publish', action='store_true', help='Atomically replace the app snapshot after all checks pass')
    parser.add_argument('--output', type=Path, default=ROOT / 'data/generated/congressional_roster.json')
    args = parser.parse_args()
    if args.download:
        # A failed acquisition/parse must not replace the last approved raw inputs.
        with tempfile.TemporaryDirectory() as tmp:
            staged = Path(tmp)
            download(staged)
            bodies, manifest = read_snapshot(staged)
            snapshot = build(bodies, manifest, args.congress, photos_by_id(ROOT / 'assets/data'))
            args.source_dir.mkdir(parents=True, exist_ok=True)
            for file in staged.iterdir():
                (args.source_dir / file.name).write_bytes(file.read_bytes())
    else:
        bodies, manifest = read_snapshot(args.source_dir)
        snapshot = build(bodies, manifest, args.congress, photos_by_id(ROOT / 'assets/data'))
    atomic_json(args.output, snapshot)
    if args.publish:
        atomic_json(ROOT / 'assets/data/congressional_roster.json', snapshot)
    print(json.dumps({'version': snapshot['version'], 'houseMembers': sum(len(g['representatives']) for g in snapshot['house']), 'senators': sum(len(g['senators']) for g in snapshot['senate']), 'vacancies': snapshot['vacancies'], 'published': args.publish}, indent=2))


if __name__ == '__main__':
    main()
