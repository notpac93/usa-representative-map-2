"""Import reviewed .gov tenure facts without deleting saved history.

The national manifest is a reviewed snapshot, not a live officeholder feed.
Keep record/person IDs when correcting a fact. Removed manifest rows remain in
the durable archive; corrections retain their previous values as revisions.
"""
import argparse
import copy
from datetime import datetime
import json
from pathlib import Path
import re
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
REVIEWED = ROOT / 'scripts/data/governor_history_reviewed.json'
OUTPUT = ROOT / 'assets/data/governor_history.json'
STATES = set('AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY'.split())


def government_url(value):
    parsed = urlsplit(value)
    if (parsed.scheme != 'https' or not (parsed.hostname or '').endswith('.gov')
            or parsed.username or parsed.password or parsed.port not in (None, 443)):
        raise ValueError(f'Expected an official government HTTPS URL: {value}')
    return value


def validate(manifest):
    if manifest.get('schemaVersion') != 1:
        raise ValueError('Unsupported reviewed history schema')
    reviewed = datetime.fromisoformat(manifest['reviewedAt'])
    if reviewed.tzinfo is None:
        raise ValueError('Review date must include its timezone')
    if set(manifest['states']) != STATES - {'CA'}:
        raise ValueError('National review must cover the other 49 states')
    for state, data in manifest['states'].items():
        government_url(data['sourceUrl'])
        if not data['records'] or not data['coverage'] or not data['sourceName']:
            raise ValueError(f'Missing history or provenance for {state}')
        ids = set()
        people = {}
        for record in data['records']:
            government_url(record['sourceUrl'])
            start, end = record['startYear'], record['endYear']
            if (type(start) is not int or type(end) is not int
                    or not 1776 <= start <= end <= reviewed.year):
                raise ValueError(f'Invalid completed tenure: {record}')
            if not record['id'].startswith(state.lower() + '-governor-') or record['id'] in ids:
                raise ValueError('Duplicate or mismatched service ID')
            if not record['personId'].startswith(state.lower() + '-'):
                raise ValueError('Mismatched person ID')
            if not record['name'].strip() or not record['period'].strip():
                raise ValueError('Missing name or service period')
            if re.search(r'present|current|ongoing', record['period'], re.I):
                raise ValueError('An unfinished service period cannot be archived as completed')
            if people.setdefault(record['personId'], record['name']) != record['name']:
                raise ValueError('Conflicting names for one person ID')
            ids.add(record['id'])


def merge(archive, manifest):
    validate(manifest)  # Validate the entire import before changing any records.
    result = copy.deepcopy(archive)
    for state, data in manifest['states'].items():
        current = result['states'].setdefault(state, {'people': []})
        people = {p['id']: p for p in current['people']}
        service_owners = {s['id']: p['id'] for p in people.values() for s in p['services']}
        for record in data['records']:
            person_id = record['personId']
            if record['id'] in service_owners and service_owners[record['id']] != person_id:
                raise ValueError('A saved service period cannot silently change people')
            person = people.setdefault(person_id, {'id': person_id, 'name': record['name'], 'services': []})
            if person['name'] != record['name']:
                person.setdefault('previousNames', []).append(person['name'])
                person['name'] = record['name']
            service = {k: v for k, v in record.items() if k not in ('name', 'personId')}
            service['verifiedAt'] = manifest['reviewedAt']
            old = next((s for s in person['services'] if s['id'] == service['id']), None)
            if old is None:
                person['services'].append(service)
            elif any(old.get(k) != v for k, v in service.items() if k != 'verifiedAt'):
                old.setdefault('revisions', []).append({k: v for k, v in old.items() if k != 'revisions'})
                old.update(service)
            # Reimporting a snapshot does not advance a record's review date.
        for person in people.values():
            person['services'].sort(key=lambda s: (s['startYear'], s['endYear']))
        current.update({k: data[k] for k in ('sourceName', 'sourceUrl', 'coverage', 'coverageStatus')})
        current['verifiedAt'] = manifest['reviewedAt']
        current['people'] = sorted(people.values(), key=lambda p: (max(s['endYear'] for s in p['services']), p['name']), reverse=True)
    return result


def refresh():
    manifest = json.loads(REVIEWED.read_text())
    archive = json.loads(OUTPUT.read_text())
    updated = merge(archive, manifest)
    temporary = OUTPUT.with_suffix('.tmp')
    temporary.write_text(json.dumps(updated, indent=2, ensure_ascii=False) + '\n')
    temporary.replace(OUTPUT)
    print(f'Saved history for {len(updated["states"])} states; existing people, terms, and revisions retained.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Validate reviewed facts without writing')
    args = parser.parse_args()
    if args.check:
        validate(json.loads(REVIEWED.read_text()))
        print('Validated reviewed records for 49 states.')
    else:
        refresh()
