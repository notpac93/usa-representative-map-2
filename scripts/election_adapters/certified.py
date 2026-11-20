"""Reviewed certified state adapters. No predictions, unsupported PDF OCR, or inferred term starts."""
from datetime import datetime, timezone, date, timedelta
import hashlib
import html
from io import BytesIO
import re
import xml.etree.ElementTree as ET
from zipfile import ZipFile
from zoneinfo import ZoneInfo

WY_BASE = 'https://sos.wyo.gov/Elections/Docs/2026/Results/General/'
WY_RESULTS_PAGE = 'https://sos.wyo.gov/Elections/Docs/2026/2026GeneralResults.aspx'
WY_RESULTS_ZIP = WY_BASE + '2026_Wyoming_General_Results.zip'
WY_CERTIFICATE = WY_BASE + '2026_General_State_Canvassing_Board_Minutes.pdf'
WY_RESULTS_SHA256 = 'c378306bd8df97437a3d11fac7792e23a8297a7e3eded8129a9cd61e3e654ff1'
WY_CERTIFICATE_SHA256 = 'e6463cc4bb79069ed30242bdd9b825323307be28346f996568eaff514a0e5798'
WY_CERTIFIED_ON = '2026-11-10'
WY_CONSTITUTION = 'https://sos.wyo.gov/Forms/Publications/WYConstitution.pdf'
WY_CONSTITUTION_SHA256 = 'eb46b6dfdf466623cf8a3d85d29473379382c4179890e79f080e5394b275396f'
WY_CALENDAR = 'https://sos.wyo.gov/Elections/Docs/2025/2025_Election_Calendar.pdf'
WY_CALENDAR_SHA256 = '99c125e74ada027b138d3344a0a940b9b0e7b2fc57953f1d206844fe9a60c4fa'
WY_CERTIFICATION_REVIEW = {
    'method': 'visually_reviewed_signed_government_document',
    'pages': [1, 5, 6],
    'reviewedOn': '2026-11-19',
    'statement': 'Signed State Canvassing Board certificate on page 6 dates certification November 10, 2026; pages 1 and 5 identify the November 3 statewide abstract and its adoption.',
    'datePrecision': 'day',
}
NS = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}


def _sha(raw):
    return hashlib.sha256(raw).hexdigest()


def _column(reference):
    number = 0
    for letter in re.match(r'[A-Z]+', reference)[0]:
        number = number * 26 + ord(letter) - 64
    return number


def _safe_zip(raw):
    archive = ZipFile(BytesIO(raw))
    if len(archive.infolist()) > 2000 or sum(f.file_size for f in archive.infolist()) > 50_000_000:
        raise ValueError('Election workbook archive exceeds safe extraction limits')
    return archive


def _worksheet(workbook, path, shared):
    rows = {}
    for row in ET.fromstring(workbook.read(path)).findall('s:sheetData/s:row', NS):
        cells = {}
        for cell in row:
            reference = cell.get('r')
            value = cell.findtext('s:v', namespaces=NS)
            if value is None:
                value = ''.join(cell.find('s:is', NS).itertext()) if cell.find('s:is', NS) is not None else None
            elif cell.get('t') == 's':
                value = shared[int(value)]
            if value is not None:
                cells[_column(reference)] = value
        rows[int(row.get('r'))] = cells
    return rows


def _office(title):
    if title == 'United States Senator':
        return 'senate', None
    if title == 'United States Representative':
        return 'house', 0
    if title == 'Governor':
        return 'governor', None
    match = re.fullmatch(r'(Senate|House) District (\d+)', title)
    if match:
        return ('stateSenate' if match[1] == 'Senate' else 'stateHouse'), int(match[2])
    if title in ('Secretary of State', 'State Auditor', 'State Treasurer', 'Superintendent of Public Instruction'):
        return 'stateExecutive', None
    raise ValueError('Unrecognized Wyoming office: ' + title)


def _vote(value):
    if value in (None, '-'):
        return 0  # Official workbook uses dashes for counties outside the district.
    if not re.fullmatch(r'\d+', str(value)):
        raise ValueError('Noninteger Wyoming vote total')
    return int(value)


def _contests(rows, expected_heading):
    if not any(expected_heading in str(value) and 'November 3, 2026' in str(value) for value in rows.get(1, {}).values()):
        raise ValueError('Wyoming workbook election or official-summary heading changed')
    headings = sorted(rows.get(3, {}).items())
    if not headings:
        raise ValueError('Wyoming contest headings missing')
    total_rows = [number for number, cells in rows.items() if cells.get(1) == 'Total']
    if len(total_rows) != 1:
        raise ValueError('Wyoming workbook must have one county-total row')
    total_row = total_rows[0]
    county_rows = [r for r in rows if 5 <= r < total_row and rows[r].get(1)]
    if len(county_rows) != 23:
        raise ValueError('Wyoming summary does not include all 23 counties')
    result = []
    for index, (start, title) in enumerate(headings):
        end = headings[index + 1][0] if index + 1 < len(headings) else max(rows.get(4, {})) + 1
        candidates = []
        write_ins = 0
        for column in range(start, end):
            label = ' '.join(str(rows.get(4, {}).get(column, '')).split())
            if not label:
                continue
            total = _vote(rows[total_row].get(column))
            if sum(_vote(rows[number].get(column)) for number in county_rows) != total:
                raise ValueError('Wyoming county vote sum differs from statewide total: ' + title)
            if label == 'Write-Ins':
                write_ins = total
                continue
            if label in ('Overvotes', 'Undervotes'):
                continue
            candidate = re.fullmatch(r'(.+) \(([A-Z]+)\)', label)
            if not candidate:
                raise ValueError('Unrecognized Wyoming candidate heading: ' + label)
            candidates.append({'name': candidate[1], 'party': candidate[2], 'votes': total})
        if not candidates:
            raise ValueError('Wyoming contest contains no named candidates')
        ranked = sorted(candidates, key=lambda c: c['votes'], reverse=True)
        if ranked[0]['votes'] <= write_ins or (len(ranked) > 1 and ranked[0]['votes'] == ranked[1]['votes']):
            raise ValueError('Wyoming contest requires tie/write-in identity review: ' + title)
        kind, district = _office(title)
        contest_id = 'WY:2026:' + re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')
        result.append({'id': contest_id, 'state': 'WY', 'electionDate': '2026-11-03',
                       'officeKind': kind, 'officeTitle': title, 'district': district,
                       'electionType': 'special' if title == 'Senate District 6' else 'general',
                       'candidates': candidates, 'leader': dict(ranked[0]), 'winner': dict(ranked[0]),
                       'writeInVotes': write_ins, 'certificationLevel': 'state', 'certificationStatus': 'certified',
                       'certifiedOn': WY_CERTIFIED_ON, 'certificationDatePrecision': 'day',
                       'startDateStatus': 'requires_office_specific_verification'})
    return result


def parse_wyoming_results(raw):
    outer = _safe_zip(raw)
    names = [name for name in outer.namelist() if name == '2026 General Results Summaries - OFFICIAL.xlsx']
    if len(names) != 1:
        raise ValueError('Expected official Wyoming summary workbook missing')
    workbook = _safe_zip(outer.read(names[0]))
    shared = [''.join(item.itertext()) for item in ET.fromstring(workbook.read('xl/sharedStrings.xml'))]
    result = []
    for path, heading in [('xl/worksheets/sheet2.xml', 'Statewide Candidates Official Summary'),
                          ('xl/worksheets/sheet3.xml', 'Statewide Senate Official Summary'),
                          ('xl/worksheets/sheet4.xml', 'Statewide House Official Summary')]:
        result.extend(_contests(_worksheet(workbook, path, shared), heading))
    if len(result) != 86 or {c['district'] for c in result if c['officeKind'] == 'stateHouse'} != set(range(1, 63)):
        raise ValueError('Wyoming contest coverage changed; review expected offices')
    if sum(c['officeKind'] == 'stateSenate' for c in result) != 17:
        raise ValueError('Wyoming senate coverage changed')
    if len({c['id'] for c in result}) != len(result):
        raise ValueError('Duplicate Wyoming contest identifiers')
    return result


def collect_wyoming(fetch, now):
    """Fetch callback must preserve each exact response and enforce the approved government host.

    A scanned certificate is deliberately reviewed and hash-pinned, not guessed by OCR.
    Any certificate/result revision requires a new review before this adapter can certify it.
    """
    if now.tzinfo is None:
        raise ValueError('Election check time must include a UTC offset')
    if now.astimezone(ZoneInfo('America/Denver')).date().isoformat() <= WY_CERTIFIED_ON:
        raise ValueError('Cannot assert certification before the reviewed certification day has completed')
    page = fetch(WY_RESULTS_PAGE)
    text = ' '.join(html.unescape(re.sub(r'<[^>]+>', ' ', page.decode('utf-8'))).split())
    if '2026 Official General Election Results' not in text or WY_RESULTS_ZIP.split('/')[-1] not in page.decode():
        raise ValueError('Wyoming official results directory changed')
    certificate = fetch(WY_CERTIFICATE)
    if _sha(certificate) != WY_CERTIFICATE_SHA256:
        raise ValueError('Wyoming signed certification changed; explicit review required')
    results = fetch(WY_RESULTS_ZIP)
    if _sha(results) != WY_RESULTS_SHA256:
        raise ValueError('Wyoming certified results changed; explicit review required')
    contests = parse_wyoming_results(results)
    constitution = fetch(WY_CONSTITUTION)
    calendar = fetch(WY_CALENDAR)
    if _sha(constitution) != WY_CONSTITUTION_SHA256 or _sha(calendar) != WY_CALENDAR_SHA256:
        raise ValueError('Wyoming start-date authority changed; review current constitutional/calendar rules')
    # Constitution Art. 3 §5 and Art. 6 §17 specify a day, not a clock time.
    # The government calendar independently lists Jan 4, 2027; never manufacture UTC midnight.
    jan_first = date(2027, 1, 1)
    start_date = jan_first + timedelta(days=(-jan_first.weekday()) % 7)
    for contest in contests:
        if contest['officeKind'] in ('house', 'senate') or contest['electionType'] == 'special':
            continue
        legislative = contest['officeKind'] in ('stateHouse', 'stateSenate')
        contest.update(scheduledStartDate=start_date.isoformat(), startTimeZone='America/Denver',
                       startDatePrecision='day', startDateStatus='verified_civil_date',
                       startRule={'url': WY_CONSTITUTION, 'sha256': WY_CONSTITUTION_SHA256,
                                  'section': 'Article 3, Section 5' if legislative else 'Article 6, Section 17',
                                  'excerpt': 'their term of office shall begin on the first Monday of January thereafter.' if legislative else 'first Monday in January next following',
                                  'calendarUrl': WY_CALENDAR, 'calendarSha256': WY_CALENDAR_SHA256,
                                  'calendarPage': 17, 'calendarDate': '2027-01-04',
                                  'note': 'Civil date only; actual assumption of duties and oath are distinct facts.'})
    checked_at = now.astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')
    return {'state': 'WY', 'stateId': 'WY', 'electionDate': '2026-11-03', 'checkedAt': checked_at,
            'certificationStatus': 'certified', 'certifiedOn': WY_CERTIFIED_ON,
            'certificationReview': dict(WY_CERTIFICATION_REVIEW), 'contests': contests,
            'sourceDocuments': [{'url': url, 'sha256': _sha(raw), 'retrievedAt': checked_at,
                                 'role': role, 'bytes': len(raw)}
                                for url, raw, role in [(WY_RESULTS_PAGE, page, 'official_results_directory'),
                                                       (WY_CERTIFICATE, certificate, 'signed_state_certification'),
                                                       (WY_RESULTS_ZIP, results, 'certified_results_workbooks'),
                                                       (WY_CONSTITUTION, constitution, 'state_term_start_rule'),
                                                       (WY_CALENDAR, calendar, 'state_term_start_calendar')]],
            'coverage': {'scope': 'federal_statewide_and_state_legislative_candidate_contests',
                         'contestCount': len(contests), 'federalContests': 2, 'stateExecutiveContests': 5,
                         'stateSenateContests': 17, 'stateHouseContests': 62,
                         'localOfficesIncluded': False, 'judicialRetentionIncluded': False,
                         'startDatesVerified': False, 'verifiedStateCivilStartDates': 83,
                         'federalStartDatesRequireNationalRule': 2,
                         'specialElectionStartDateNeedsReview': ['Senate District 6']}}
