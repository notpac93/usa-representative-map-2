"""Delaware 2026 government results intake, with certification kept separate.

The election-night-reporting JSON supplies an explicit per-row results type;
the static page's initial 'Unofficial Results' heading is a JS placeholder.
An OFFICIAL RESULTS label is retained, but never treated as a certificate of
election. The caller supplies fetch(url)->bytes and archives original bytes.
"""
from datetime import datetime, timezone
import hashlib
import html
import json
import re

RESULTS_URL = 'https://elections.delaware.gov/results/enr/GE2026.html'
RESULTS_JSON_URL = 'https://elections.delaware.gov/results/enr/Election_StatewideResults_ID_GE2026.json'
CROSSCHECK_URL = 'https://data.delaware.gov/resource/4hbv-7brf.json?$limit=1000&$where=electionname=%272026%20General%20Election%27'
CONSTITUTION_URL = 'https://delcode.delaware.gov/constitution/constitution.html'
SECURITY_FAQ_URL = 'https://elections.delaware.gov/public/faq/election-security-and-audits.html'
LEGISLATIVE_TERM_REVIEW_URL = 'https://legis.delaware.gov/docs/default-source/publications/faqdocuments/lengthofageneralassemblyandalegislator%27stermofoffice.pdf'
ELECTION_DATE = '2026-11-03'


def _integer(value):
    # Floats, negative totals, boolean values, and partial parses are forbidden.
    if isinstance(value, bool) or not isinstance(value, (str, int)):
        raise ValueError('Vote counts must be nonnegative integers')
    if not re.fullmatch(r'\d+|\d{1,3}(?:,\d{3})+', str(value)):
        raise ValueError('Invalid integer vote count')
    return int(str(value).replace(',', ''))


def _rows(raw):
    result = json.loads(raw)
    if not isinstance(result, list) or not result or len(result) >= 1000:
        raise ValueError('Empty, malformed, or potentially truncated Delaware results')
    if not all(isinstance(row, dict) for row in result):
        raise ValueError('Invalid Delaware result row')
    return result


def _office(title):
    if title == 'U.S. Senator':
        return 'us:senate:DE:II', 'senate', None
    if title == 'Representative In Congress':
        return 'us:house:DE:AL', 'house', 'AL'
    executives = {'Attorney General': 'attorney-general', 'State Treasurer': 'treasurer',
                  'Auditor of Accounts': 'auditor'}
    if title in executives:
        return 'state:DE:' + executives[title], 'stateExecutive', None
    match = re.fullmatch(r'State (Senator|Representative) District (\d+)', title)
    if match:
        district = int(match[2])
        kind = 'stateSenate' if match[1] == 'Senator' else 'stateHouse'
        if district < 1 or district > (21 if kind == 'stateSenate' else 41):
            raise ValueError('Invalid Delaware legislative district')
        chamber = 'senate' if kind == 'stateSenate' else 'house'
        return f'state:DE:{chamber}:{district}', kind, str(district)
    return None


def parse_results(raw, crosscheck_raw):
    """Reconcile two government publications before returning supported contests.

    Missing/changed schemas, duplicate candidates, inconsistent election/status
    metadata, incomplete precinct reporting, and mismatched totals fail closed.
    Unsupported county contests remain counted in coverage rather than silently
    becoming state offices. No official winner is asserted by this parser.
    """
    primary = _rows(raw)
    crosscheck = _rows(crosscheck_raw)
    comparison = {}
    for row in crosscheck:
        if row.get('electionname') != '2026 General Election' or row.get('electiondate') != ELECTION_DATE + 'T00:00:00.000':
            raise ValueError('Cross-check contains another election')
        key = (row['office'], row['candidatename'], row['partyname'])
        if key in comparison:
            raise ValueError('Duplicate candidate in Delaware cross-check')
        votes = tuple(_integer(row[field]) for field in ('machinevotessum', 'absenteevotessum', 'earlyvotessum', 'totalvotessum'))
        if sum(votes[:3]) != votes[3]:
            raise ValueError('Cross-check vote components do not reconcile')
        comparison[key] = votes
    grouped, seen, statuses, report_times = {}, set(), set(), set()
    for row in primary:
        if row.get('Election Id') != 'GE2026' or row.get('Election Name') != '2026 General Election' or row.get('Election Date') != ELECTION_DATE:
            raise ValueError('Primary results contain another election')
        status = row.get('Results Type')
        if status not in ('OFFICIAL RESULTS', 'UNOFFICIAL RESULTS'):
            raise ValueError('Unrecognized government results status')
        statuses.add(status)
        total = _integer(row['Total Precincts'])
        if total == 0 or _integer(row['Precincts Reported']) != total:
            raise ValueError('Not all election districts are reporting')
        stamp = datetime.fromisoformat(row['ReportTime'])
        if stamp.tzinfo is None or stamp.date().isoformat() < ELECTION_DATE:
            raise ValueError('Invalid government report timestamp')
        report_times.add(row['ReportTime'])
        key = (row['Contest Title'], row['Candidate Name'], row['Party Name'])
        if key in seen:
            raise ValueError('Duplicate candidate in primary results')
        seen.add(key)
        votes = tuple(_integer(row[field]) for field in ('Machine Votes', 'Absentee Votes', 'Early Voting Votes', 'Total Votes'))
        if sum(votes[:3]) != votes[3] or comparison.get(key) != votes:
            raise ValueError('Government publications disagree on vote totals')
        office = _office(key[0])
        if office:
            grouped.setdefault(key[0], {'office': office, 'candidates': []})['candidates'].append(
                {'name': key[1], 'party': key[2], 'votes': votes[3]})
    if seen != set(comparison):
        raise ValueError('Government publications disagree on candidate coverage')
    if len(statuses) != 1 or len(report_times) != 1:
        raise ValueError('Inconsistent government publication status or edition')
    # This is the reviewed 2026 contest inventory, not a claim that every
    # legislative seat is on this ballot. Senate elections are staggered.
    expected = {'U.S. Senator', 'Representative In Congress', 'Attorney General',
                'State Treasurer', 'Auditor of Accounts'}
    expected.update(f'State Representative District {n}' for n in range(1, 42))
    expected.update(f'State Senator District {n}' for n in (1, 5, 7, 8, 9, 12, 13, 14, 15, 19, 20))
    if set(grouped) != expected:
        raise ValueError('Supported contest inventory differs from reviewed 2026 Delaware ballot')
    contests = []
    for title, group in sorted(grouped.items()):
        office_id, kind, district = group['office']
        candidates = sorted(group['candidates'], key=lambda c: (-c['votes'], c['name']))
        if candidates[0]['votes'] <= 0:
            raise ValueError('Supported contest has no valid votes')
        leader = candidates[0] if len(candidates) == 1 or candidates[0]['votes'] > candidates[1]['votes'] else None
        contests.append({'id': '2026-' + office_id, 'officeId': office_id, 'officeKind': kind,
                         'officeTitle': title, 'state': 'DE', 'district': district,
                         'electionDate': ELECTION_DATE, 'candidates': candidates, 'leader': leader,
                         'resultsType': next(iter(statuses)), 'reportTime': next(iter(report_times)),
                         'incomingStatus': 'official_results_pending_certification' if 'OFFICIAL RESULTS' in statuses else 'unofficial_results',
                         'certificationStatus': 'official_results_certification_unverified' if 'OFFICIAL RESULTS' in statuses else 'unofficial',
                         'certificationLevel': 'not_verified', 'certified': False,
                         'scheduledStart': None,
                         'sourceUrls': [RESULTS_JSON_URL, CROSSCHECK_URL]})
    return contests, {'candidateRows': len(primary), 'allContests': len({r['Contest Title'] for r in primary}),
                      'supportedContests': len(contests), 'crossPublicationTotalsMatch': True,
                      'writeInReportReviewed': False}


def parse_start_rules(raw):
    """Retain civil-date rules without inventing swearing-in timestamps."""
    value = ' '.join(html.unescape(re.sub(r'<[^>]+>', ' ', raw.decode('utf-8'))).split())
    legislative = 'The terms of Senators and Representatives begin on the day next after their election.'
    executive = 'The terms of office of all State and County officers made elective by this Constitution begin on the first Tuesday in January next after their election, unless otherwise provided in this Constitution.'
    if legislative not in value or executive not in value:
        raise ValueError('Delaware constitutional term-start rules changed or are missing')
    return {'legislative': {'rule': legislative, 'citation': 'Delaware Constitution Article II §3(e)',
                           'sourceUrl': CONSTITUTION_URL, 'scheduledStartDate': None,
                           'verificationStatus': 'canvass_interpretation_and_qualification_require_review',
                           'reviewSourceUrl': LEGISLATIVE_TERM_REVIEW_URL,
                           'qualificationRequired': True},
            'executive': {'rule': executive, 'citation': 'Delaware Constitution Article III §24',
                          'sourceUrl': CONSTITUTION_URL, 'scheduledStartDate': '2027-01-05',
                          'datePrecision': 'day', 'verificationStatus': 'statutory_civil_date_verified',
                          'actualAssumptionVerified': False, 'qualificationRequired': True}}


def collect_delaware(fetch, now):
    """Download and reconcile government results for human review, never release."""
    if not isinstance(now, datetime) or now.tzinfo is None:
        raise ValueError('Delaware intake needs an aware verification time')
    checked_at = now.astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')
    report = {'adapter': 'delaware-2026', 'state': 'DE', 'electionDate': ELECTION_DATE,
              'checkedAt': checked_at, 'certificationStatus': 'official_results_certification_unverified',
              'contests': [], 'sourceDocuments': [], 'coverage': {}, 'warnings': [], 'errors': []}

    def download(url, role):
        document = {'url': url, 'kind': role, 'role': role, 'retrievedAt': checked_at}
        report['sourceDocuments'].append(document)
        try:
            raw = fetch(url)
            if not isinstance(raw, bytes):
                raise ValueError('Government fetch must return original bytes')
            document.update({'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw), 'downloaded': True})
            return raw
        except Exception as error:
            document['error'] = str(error)
            raise

    try:
        primary = download(RESULTS_JSON_URL, 'official_results_json')
        comparison = download(CROSSCHECK_URL, 'official_results_crosscheck_json')
        report['contests'], report['coverage'] = parse_results(primary, comparison)
        if any(c['resultsType'] != 'OFFICIAL RESULTS' for c in report['contests']):
            report['certificationStatus'] = 'unofficial'
    except Exception as error:
        report['errors'].append('Delaware results were withheld: ' + str(error))
    try:
        rules = parse_start_rules(download(CONSTITUTION_URL, 'official_term_start_law'))
        report['startDateRules'] = rules
        for contest in report['contests']:
            if contest['officeKind'] in ('stateSenate', 'stateHouse'):
                contest['startDateEvidence'] = rules['legislative'].copy()
            elif contest['officeKind'] == 'stateExecutive':
                contest['startDateEvidence'] = rules['executive'].copy()
    except Exception as error:
        report['warnings'].append('Term-start rules were withheld: ' + str(error))
    report['warnings'].extend([
        'OFFICIAL RESULTS is a government publication status. No independently verified contest certification or winner is asserted.',
        'The separate official write-in report has not been reconciled; reported leaders are review evidence, not incoming terms.',
        'Legislative start dates require canvass interpretation and qualification review. Civil dates never become automatic transition timestamps.'
    ])
    return report
