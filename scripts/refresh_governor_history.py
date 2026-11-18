"""Merge completed California gubernatorial service into a durable .gov archive.
Never removes existing people or service periods. Never infers a term end from a
change in the current-officeholder feed. Run again when the library updates.
"""
import concurrent.futures
import html
import json
import re
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path
import urllib.request

def fetch(url):
    def check(value):
        p = urllib.parse.urlsplit(value)
        if p.scheme != 'https' or not (p.hostname == 'library.ca.gov' or (p.hostname or '').endswith('.library.ca.gov')):
            raise ValueError('History must come from the California State Library HTTPS domain')
    class Redirects(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            check(newurl)
            return super().redirect_request(req, fp, code, msg, headers, newurl)
    check(url)
    with urllib.request.build_opener(Redirects()).open(url, timeout=40) as response:
        check(response.url)
        return response.read()


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'assets/data/governor_history.json'
SOURCE = 'https://governors.library.ca.gov/list.html'

def text(s):
    return ' '.join(html.unescape(re.sub('<[^>]+>', ' ', s)).split())

def records(page):
    found = []
    for href, markup in re.findall(r'<a\b[^>]*href=["\']([^"\']+)["\'][^>]*>(.*?)</a>', page, re.S | re.I):
        match = re.fullmatch(r'(\d+)\.\s+(.+?)\s+\(([^)]+)\)', text(markup))
        if match and 'present' not in match[3].lower():
            found.append((int(match[1]), match[2], match[3], urllib.parse.urljoin(SOURCE, href)))
    if len(found) < 35:
        raise ValueError('Incomplete library index; retaining existing archive')
    return found

def enrich(record):
    ordinal, name, period, url = record
    page = fetch(url).decode('utf-8', errors='replace')
    # The individual profile's service heading takes precedence over index
    # summaries, which can disagree (e.g. Goodwin Knight).
    heading = re.search(r'<h1\b[^>]*>.*?</h1>\s*<h3\b[^>]*>(.*?)</h3>', page, re.S | re.I)
    if heading and re.search(r'\d{4}', text(heading[1])):
        period = text(heading[1])
    years = re.findall(r'\d{4}', period)
    if not years or 'present' in period.lower():
        raise ValueError('Unresolved completed service period')
    return ordinal, name, period, url, int(years[0]), int(years[-1])

def refresh():
    now = datetime.now(timezone.utc).isoformat()
    archive = json.loads(OUTPUT.read_text()) if OUTPUT.exists() else {'schemaVersion': 1, 'states': {}}
    current = archive['states'].setdefault('CA', {'people': []})
    people = {p['id']: p for p in current['people']}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        enriched = list(pool.map(enrich, records(fetch(SOURCE).decode())))
    for ordinal, name, period, url, start, end in enriched:
        person_id = 'ca-' + re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
        person = people.setdefault(person_id, {'id': person_id, 'name': name, 'services': []})
        service = {'id': f'ca-governor-{ordinal}', 'ordinal': ordinal, 'period': period,
            'startYear': start, 'endYear': end, 'sourceUrl': url, 'verifiedAt': now}
        old = next((s for s in person['services'] if s['id'] == service['id']), None)
        if old is None:
            person['services'].append(service)
        elif any(old.get(k) != service[k] for k in ['period', 'startYear', 'endYear', 'sourceUrl']):
            old.setdefault('revisions', []).append({k: v for k, v in old.items() if k != 'revisions'})
            old.update(service)
        else:
            old['verifiedAt'] = now
    current.update({'people': sorted(people.values(), key=lambda p: max(s['endYear'] for s in p['services']), reverse=True),
        'sourceUrl': SOURCE, 'sourceName': 'California State Library · Governors’ Gallery',
        'verifiedAt': now, 'coverage': 'Completed service periods from the State Library archive. Years and wording follow the linked profiles; exact transition dates are not inferred.'})
    temp = OUTPUT.with_suffix('.tmp')
    temp.write_text(json.dumps(archive, indent=2) + '\n')
    temp.replace(OUTPUT)
    print(f'Saved {len(people)} former governors and {sum(len(p["services"]) for p in people.values())} service periods. Existing records retained.')

if __name__ == '__main__': refresh()
