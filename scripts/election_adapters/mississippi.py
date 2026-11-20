"""Mississippi 2026 source intake; recognition is never election certification.

No unattended OCR votes are published. County totals are usable only when a
native-text government summary explicitly supplies one numeric total per row.
The caller supplies fetch(url)->bytes, enforcing hosts and archiving responses.
"""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import html
from pathlib import Path
import re
import subprocess
import tempfile
from urllib.parse import quote, urljoin, urlparse

RESULTS_URL = 'https://www.sos.ms.gov/elections-voting/election-results'
COUNTY_INDEX_URL = 'https://www.sos.ms.gov/elections/electionresults_aspx/elections_results_2026_general.aspx'
COUNTY_DOCUMENTS_URL = 'https://www.sos.ms.gov/elections/electionresults_aspx/elections_results_2026_county.aspx'
CALENDAR_URL = 'https://www.sos.ms.gov/content/documents/elections/2026%20Elections%20Calendar.pdf'
RECOGNITION_URL = 'https://employment.senate.gov/2026-senators-elect-resume-collection/'
WICKER_URL = 'https://www.wicker.senate.gov/2026/11/12/wicker-congratulates-senator-elect-colom-and-honors-senator-hyde-smith/'
COUNTIES = tuple('Adams|Alcorn|Amite|Attala|Benton|Bolivar|Calhoun|Carroll|Chickasaw|Choctaw|Claiborne|Clarke|Clay|Coahoma|Copiah|Covington|DeSoto|Forrest|Franklin|George|Greene|Grenada|Hancock|Harrison|Hinds|Holmes|Humphreys|Issaquena|Itawamba|Jackson|Jasper|Jefferson|Jefferson Davis|Jones|Kemper|Lafayette|Lamar|Lauderdale|Lawrence|Leake|Lee|Leflore|Lincoln|Lowndes|Madison|Marion|Marshall|Monroe|Montgomery|Neshoba|Newton|Noxubee|Oktibbeha|Panola|Pearl River|Perry|Pike|Pontotoc|Prentiss|Quitman|Rankin|Scott|Sharkey|Simpson|Smith|Stone|Sunflower|Tallahatchie|Tate|Tippah|Tishomingo|Tunica|Union|Walthall|Warren|Washington|Wayne|Webster|Wilkinson|Winston|Yalobusha|Yazoo'.split('|'))
NAMES = ('Scott Colom', 'Cindy Hyde-Smith', 'Ty Pinkins')


def text(raw):
    return ' '.join(html.unescape(re.sub(r'<[^>]+>', ' ', raw.decode('utf-8'))).split())


def pdf_text(raw):
    if not raw.startswith(b'%PDF'):
        raise ValueError('Government document is not a PDF')
    with tempfile.TemporaryDirectory(prefix='ms-election-pdf-') as folder:
        source = Path(folder) / 'document.pdf'
        source.write_bytes(raw)
        result = subprocess.run(['pdftotext', '-layout', str(source), '-'], capture_output=True, timeout=60, check=True)
        return result.stdout.decode('utf-8')


def parse_calendar(value):
    """Verify the government calendar's actual text; dates are not guessed from cadence."""
    if 'Last Revised: 9/8/2026' not in value:
        raise ValueError('Unexpected Mississippi calendar edition; review the official dates')
    compact = ' '.join(value.split())
    if not re.search(r'13th\s+Delivery of Returns:.*?certified recap sheets', compact):
        raise ValueError('County recap deadline is absent')
    if not re.search(r'DECEMBER.*?3rd\s+Declaration of General/Special Election Results by Secretary of State', compact):
        raise ValueError('Statewide declaration deadline is absent')
    return {'countyReturnsDue': '2026-11-13', 'stateDeclarationScheduled': '2026-12-03',
            'sourceUrl': CALENDAR_URL, 'statute': 'Miss. Code Ann. §23-15-605'}


def parse_county_totals(value, county):
    """Accept explicit county summaries only; reject precinct columns and OCR ambiguity."""
    compact = ' '.join(value.split())
    if not re.search(r'County of\s+' + re.escape(county) + r'\b', compact, re.I):
        raise ValueError('County identity is not verified in PDF text')
    if not re.search(r'\b3rd day of November\s+2026|\bNovember\s+3,?\s+2026', compact, re.I):
        raise ValueError('Election date is not verified in PDF text')
    if 'Official Recapitulation' not in value:
        raise ValueError('County certification heading is absent')
    if re.search(r'write[ -]*in', value, re.I):
        raise ValueError('Write-in totals require explicit candidate reconciliation before aggregation')
    if not re.search(r'United States[ -]+Senate', value, re.I):
        raise ValueError('Senate contest is absent')
    if not re.search(r'County Total|Total Votes|\bTOTAL\b', value, re.I):
        raise ValueError('Explicit county total column is absent')
    totals = {}
    for name in NAMES:
        lines = [line for line in value.splitlines() if re.search(re.escape(name), line, re.I)]
        if len(lines) != 1:
            raise ValueError('Repeated or missing candidate rows require table review')
        numbers = re.findall(r'(?<!\w)\d[\d,]*(?!\w)', lines[0])
        if len(numbers) != 1:
            raise ValueError('Precinct columns cannot be mistaken for a county total')
        totals[name] = int(numbers[0].replace(',', ''))
    if sum(totals.values()) <= 0:
        raise ValueError('County summary has no valid votes')
    return totals


def parse_county_links(raw):
    links = {}
    for href, label in re.findall(r'<a\b[^>]*href=[\"\']([^\"\']+)[\"\'][^>]*>(.*?)</a>', raw.decode('utf-8'), re.S | re.I):
        county = re.sub(r'\s+County$', '', text(label.encode()), flags=re.I).strip()
        # The official source misspells this label and filename; preserve its URL.
        if county == 'Walthal': county = 'Walthall'
        if county not in COUNTIES: continue
        url = urljoin(COUNTY_DOCUMENTS_URL, html.unescape(href))
        parsed = urlparse(url)
        if parsed.scheme != 'https' or parsed.hostname != 'www.sos.ms.gov' or not parsed.path.startswith('/elections/electionresults/2026General/') or not parsed.path.lower().endswith('.pdf') or parsed.query or parsed.fragment:
            continue
        url = quote(url, safe=':/%')
        if county in links: raise ValueError('Duplicate county entry in official SOS index: ' + county)
        links[county] = url
    return links


def collect_mississippi(fetch, now, *, county_names=None, extract_pdf=pdf_text, max_workers=4):
    """Return a state report with county coverage and government-recognized incoming.

    `county_names` is injectable for focused checks. Only the entire reviewed
    82-county inventory can yield countyAggregationComplete=True. Downloading a
    PDF is not equivalent to validating its totals or statewide certification.
    """
    if not isinstance(now, datetime) or now.tzinfo is None:
        raise ValueError('Mississippi intake needs an aware verification time')
    now = now.astimezone(timezone.utc)
    counties = tuple(COUNTIES if county_names is None else county_names)
    if len(set(counties)) != len(counties) or any(c not in COUNTIES for c in counties):
        raise ValueError('County request must use distinct reviewed Mississippi counties')
    checked_at = now.isoformat().replace('+00:00', 'Z')
    report = {'adapter': 'mississippi-2026', 'state': 'MS', 'electionDate': '2026-11-03',
              'checkedAt': checked_at, 'certificationStatus': 'statewide_declaration_not_verified',
              'contests': [], 'sourceDocuments': [], 'warnings': [], 'errors': []}

    def download(url, kind):
        doc = {'url': url, 'kind': kind, 'retrievedAt': checked_at}
        try:
            raw = fetch(url)
            doc.update(sha256=hashlib.sha256(raw).hexdigest(), bytes=len(raw), status='downloaded')
            return raw, doc
        except Exception as error:
            doc.update(status='unavailable', error=f'{type(error).__name__}: {error}')
            return None, doc

    for url in (RESULTS_URL, COUNTY_INDEX_URL):
        _, doc = download(url, 'official_results_directory')
        report['sourceDocuments'].append(doc)
    index_raw, doc = download(COUNTY_DOCUMENTS_URL, 'official_county_document_index')
    report['sourceDocuments'].append(doc)
    county_links = {}
    if index_raw is not None:
        try: county_links = parse_county_links(index_raw)
        except ValueError as error: report['errors'].append(str(error))
    calendar, doc = download(CALENDAR_URL, 'official_election_calendar')
    report['sourceDocuments'].append(doc)
    if calendar is not None:
        try:
            report['certificationCalendar'] = parse_calendar(extract_pdf(calendar))
        except Exception as error:
            report['errors'].append('Calendar needs review: ' + str(error))
    recognized = False
    raw, doc = download(RECOGNITION_URL, 'government_incoming_recognition')
    report['sourceDocuments'].append(doc)
    if raw is not None:
        headings = [text(h.encode()).strip() for h in re.findall(r'<h3\b[^>]*>(.*?)</h3>', raw.decode('utf-8'), re.S | re.I)]
        recognized = 'Scott Colom (MS)' in headings and 'New Senators-Elect' in text(raw)
    raw, doc = download(WICKER_URL, 'government_incoming_corroboration')
    report['sourceDocuments'].append(doc)
    corroborated = raw is not None and 'Congratulations to Senator-elect Scott Colom.' in text(raw)
    if recognized:
        report['contests'].append({'id': '2026-MS-US-SENATE-II', 'officeId': 'us:senate:MS:II',
            'officeKind': 'senate', 'state': 'MS', 'district': None,
            'governmentRecognizedIncoming': {'name': 'Scott Colom', 'recognizedAt': checked_at,
                'sourceUrls': [RECOGNITION_URL] + ([WICKER_URL] if corroborated else [])},
            'incomingStatus': 'government_recognized_pending_certification',
            'certificationLevel': 'government_recognition_only', 'certified': False,
            'scheduledStart': None, 'leader': None, 'candidates': []})
    else:
        report['warnings'].append('Senate Employment Office recognition of Scott Colom was not verified; no incoming identity asserted.')

    def county_result(county):
        url = county_links.get(county)
        if url is None:
            return {'url': COUNTY_DOCUMENTS_URL, 'kind': 'county_source_not_listed', 'county': county, 'status': 'unavailable'}, None, 'county_pdf_not_listed_in_official_index'
        raw, document = download(url, 'county_recap_pdf')
        document['county'] = county
        if raw is None:
            return document, None, 'unavailable'
        if not raw.startswith(b'%PDF'):
            document['status'] = 'invalid_document'
            return document, None, 'not_pdf'
        try:
            value = extract_pdf(raw)
            if not value.strip():
                return document, None, 'scanned_pdf_requires_ocr_and_review'
            totals = parse_county_totals(value, county)
            document['totalsValidated'] = True
            return document, totals, None
        except Exception as error:
            return document, None, 'manual_table_review_required: ' + str(error)

    if counties:
        with ThreadPoolExecutor(max_workers=max(1, min(4, max_workers))) as pool:
            county_results = list(pool.map(county_result, counties))
    else:
        county_results = []
    totals, pending = {}, []
    retrieved = []
    for document, votes, reason in county_results:
        report['sourceDocuments'].append(document)
        if document['status'] == 'downloaded': retrieved.append(document['county'])
        if votes is not None: totals[document['county']] = votes
        else: pending.append({'county': document['county'], 'reason': reason})
    complete = set(counties) == set(COUNTIES) and len(totals) == len(COUNTIES)
    report['coverage'] = {'expectedCounties': len(COUNTIES), 'requestedCounties': len(counties), 'discoveredCounties': len(county_links),
        'retrievedCounties': len(retrieved), 'validatedCountyTotals': len(totals),
        'countyAggregationComplete': complete, 'unreviewedCounties': pending,
        'notRequestedCounties': [c for c in COUNTIES if c not in counties],
        'countyUrlInventory': 'Links discovered from the official SOS 2026 county recapitulation directory; no county document URLs are guessed.'}
    if complete:
        state_votes = {name: sum(v[name] for v in totals.values()) for name in NAMES}
        if not report['contests']:
            report['contests'].append({'id': '2026-MS-US-SENATE-II', 'officeId': 'us:senate:MS:II', 'officeKind': 'senate',
                'state': 'MS', 'district': None, 'certified': False, 'certificationLevel': 'county_aggregation', 'scheduledStart': None})
        contest = report['contests'][0]
        contest['candidates'] = [{'name': name, 'votes': votes} for name, votes in state_votes.items()]
        ordered = sorted(state_votes.items(), key=lambda x: x[1], reverse=True)
        if ordered[0][1] != ordered[1][1]: contest['leader'] = {'name': ordered[0][0], 'votes': ordered[0][1]}
        contest['countyAggregationComplete'] = True
    report['warnings'].append('County-certified returns, a government senator-elect list, and the scheduled declaration date do not establish statewide certification. No statewide certified winner is asserted.')
    return report
