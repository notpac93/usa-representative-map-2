"""Pinned, explicitly reviewed government result packages for any US state.

This is an import boundary, not a result discovery service. `fetch(url)` must
validate the state's approved hosts/delegations and archive each exact response.
Machine bindings are independently evaluated. Signed scanned PDF facts remain
explicit human-review assertions and are labelled as such, never OCR guesses.
"""
import csv
from datetime import date, datetime, timezone, timedelta
import hashlib
from io import StringIO
import json
from pathlib import Path
import re
import subprocess
import tempfile
from urllib.parse import urlparse
from zoneinfo import ZoneInfo

STATES = set('AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY'.split())
KINDS = {'house', 'senate', 'governor', 'stateExecutive', 'stateHouse', 'stateSenate', 'stateJudge'}


def instant(value):
    if not isinstance(value, str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})', value):
        raise ValueError('Reviewed instants require an explicit UTC offset')
    return datetime.fromisoformat(value.replace('Z', '+00:00')).astimezone(timezone.utc)


def civil(value):
    if not isinstance(value, str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}', value):
        raise ValueError('Reviewed civil dates require YYYY-MM-DD')
    return date.fromisoformat(value)


def pointer(value, path):
    if not isinstance(path, str) or not path.startswith('/'):
        raise ValueError('Explicit absolute JSON pointers are required')
    for key in path[1:].split('/'):
        key = key.replace('~1', '/').replace('~0', '~')
        if isinstance(value, list):
            if not re.fullmatch(r'0|[1-9]\d*', key): raise ValueError('Invalid JSON array pointer')
            value = value[int(key)]
        elif isinstance(value, dict): value = value[key]
        else: raise ValueError('JSON pointer does not resolve')
    return value


def integer(value):
    if isinstance(value, bool) or not re.fullmatch(r'0|[1-9]\d*', str(value)):
        raise ValueError('Vote totals and seat counts must be nonnegative integers')
    return int(value)


def review(record, now, *, human=False):
    if not isinstance(record, dict) or not isinstance(record.get('reviewer'), str) or not record['reviewer'].strip():
        raise ValueError('An identified reviewer is required')
    if instant(record.get('reviewedAt')) > now:
        raise ValueError('Future review timestamp is not trusted')
    if human and (record.get('reviewerType') != 'human' or record.get('method') != 'visually_reviewed_government_document'):
        raise ValueError('Scanned or visually transcribed facts require explicit human visual review')
    return record


def pdf_pages(raw):
    with tempfile.TemporaryDirectory(prefix='reviewed-election-pdf-') as folder:
        source = Path(folder) / 'source.pdf'
        source.write_bytes(raw)
        result = subprocess.run(['pdfinfo', str(source)], check=True, capture_output=True, timeout=30)
    match = re.search(r'^Pages:\s+(\d+)$', result.stdout.decode('utf-8'), re.M)
    if not match: raise ValueError('Could not independently check reviewed PDF page references')
    return int(match[1])


def visual_binding(binding, raw, now, *, signed=False):
    review(binding.get('review'), now, human=True)
    if not raw.startswith(b'%PDF-'): raise ValueError('Reviewed PDF is not a PDF response')
    pages = binding.get('pages')
    if not isinstance(pages, list) or not pages or any(isinstance(p, bool) or not isinstance(p, int) or p < 1 for p in pages) or len(set(pages)) != len(pages):
        raise ValueError('Explicit distinct positive PDF page references are required')
    if max(pages) > pdf_pages(raw): raise ValueError('Reviewed PDF page reference is outside the document')
    if not str(binding.get('statement', '')).strip(): raise ValueError('Visual review needs a factual review statement')
    if signed and binding.get('signedDocumentReviewed') is not True:
        raise ValueError('Certification must identify an explicitly reviewed signed government document')


def canonical_candidates(rows):
    if not isinstance(rows, list) or not rows:
        raise ValueError('A complete nonempty candidate set is required')
    result = []
    for row in rows:
        if not isinstance(row.get('name'), str) or not row['name'].strip() or not isinstance(row.get('winner'), bool):
            raise ValueError('Each candidate requires an explicit name and boolean winner flag')
        result.append({'name': row['name'].strip(), 'votes': integer(row['votes']), 'winner': row['winner']})
    if len({r['name'].casefold() for r in result}) != len(result): raise ValueError('Duplicate candidate identities')
    winners = [r for r in result if r['winner']]
    if len(winners) != 1: raise ValueError('Tie, unresolved outcome, or multiple winners requires a dedicated adapter')
    winner = winners[0]
    if winner['name'].casefold().replace('-', '').replace(' ', '') in ('writein', 'writeins', 'yes', 'no', 'scattering'):
        raise ValueError('Unidentified write-ins and retention ballot choices are not elected identities')
    if winner['votes'] <= 0 or any(r is not winner and r['votes'] >= winner['votes'] for r in result):
        raise ValueError('Winner flags conflict with a tie or the bound final-round vote totals')
    return result, {'name': winner['name'], 'votes': winner['votes']}


def structured_result(raw, document, binding, contest, state, election_date):
    if document['format'] == 'json':
        source = json.loads(raw)
        if pointer(source, binding['statePointer']) != state or pointer(source, binding['electionDatePointer']) != election_date:
            raise ValueError('Government feed state or election date differs from reviewed contest')
        item = pointer(source, binding['contestPointer'])
        fields = binding['fields']
        if pointer(item, fields['title']) != contest['officeTitle'] or integer(pointer(item, fields['seats'])) != 1 or pointer(item, fields['outcome']) not in ('final', 'certified'):
            raise ValueError('Contest title, single-seat scope, or final outcome is not explicitly bound')
        if pointer(item, fields['electionType']) != contest['electionType']:
            raise ValueError('Government election type differs from reviewed contest')
        if contest.get('district') is not None and str(pointer(item, fields['district'])) != str(contest['district']):
            raise ValueError('Government district differs from the reviewed seat')
        candidate_rows = pointer(item, fields['candidates'])
        names = binding['candidateFields']
        return canonical_candidates([{'name': pointer(row, names['name']), 'votes': pointer(row, names['votes']), 'winner': pointer(row, names['winner'])} for row in candidate_rows])
    if document['format'] == 'csv':
        reader = csv.DictReader(StringIO(raw.decode('utf-8-sig')))
        if reader.fieldnames is None or len(reader.fieldnames) != len(set(reader.fieldnames)): raise ValueError('CSV headers missing or duplicated')
        columns = binding['columns']
        rows = [row for row in reader if row[columns['contest']] == contest['officeTitle'] and row[columns['state']] == state and row[columns['electionDate']] == election_date and (contest.get('district') is None or str(row[columns['district']]) == str(contest['district']))]
        if not rows: raise ValueError('Reviewed CSV contest is absent')
        for row in rows:
            if row[columns['state']] != state or row[columns['electionDate']] != election_date or integer(row[columns['seats']]) != 1 or row[columns['outcome']] not in ('final', 'certified'):
                raise ValueError('CSV state, date, seat scope, or final outcome is not explicitly bound')
            if row[columns['electionType']] != contest['electionType']:
                raise ValueError('Government CSV election type differs from reviewed contest')
            if contest.get('district') is not None and str(row[columns['district']]) != str(contest['district']):
                raise ValueError('Government CSV district differs from reviewed seat')
        yes, no = binding['winnerTrueValue'], binding['winnerFalseValue']
        if not isinstance(yes, str) or not isinstance(no, str) or yes == no: raise ValueError('Distinct CSV winner values are required')
        candidates = []
        for row in rows:
            flag = row[columns['winner']]
            if flag not in (yes, no): raise ValueError('CSV winner flag has an unreviewed value')
            candidates.append({'name': row[columns['name']], 'votes': row[columns['votes']], 'winner': flag == yes})
        return canonical_candidates(candidates)
    raise ValueError('Structured result binding requires JSON or CSV')


def scoped_office(contest, state, election_date):
    if contest.get('state') != state or contest.get('electionDate') != election_date:
        raise ValueError('Cross-state or cross-election contest in reviewed package')
    if contest.get('officeKind') not in KINDS or not str(contest.get('officeTitle', '')).strip():
        raise ValueError('Unreviewed office kind or missing office title')
    if contest.get('electionType') not in ('general', 'special', 'runoff'):
        raise ValueError('An explicit government election type is required; special terms cannot default to general')
    if type(contest.get('seats')) is not int or contest.get('seats') != 1 or contest.get('outcome') != 'final' or contest.get('runoffPending') is not False or contest.get('tiePending') is not False:
        raise ValueError('Multiple seats, ties, runoffs, or unresolved outcomes require dedicated handling')
    oid = contest.get('officeId')
    if oid:
        kind = contest['officeKind']
        if kind == 'house': valid = re.fullmatch(r'us:house:' + state + r'\d{2}', oid) is not None
        elif kind == 'senate': valid = re.fullmatch(r'us:senate:' + state + r':(?:I|II|III)', oid) is not None
        else: valid = oid.startswith(('state:' + state + ':', 'us:state:' + state + ':', 'us:' + state + ':'))
        if not valid: raise ValueError('Office ID does not belong to the reviewed state and office kind')
        if kind == 'house' and contest.get('district') != int(oid[-2:]): raise ValueError('House office ID and district differ')


def certification(proof, documents, state, election_date, contest_ids, now):
    if proof.get('state') != state or proof.get('electionDate') != election_date or proof.get('level') != 'state' or proof.get('kind') != 'certification':
        raise ValueError('Government recognition, county totals, and election calls are not statewide certification')
    if set(proof.get('contestIds', [])) != set(contest_ids) or len(proof['contestIds']) != len(contest_ids):
        raise ValueError('Certification does not bind exactly the reviewed contests')
    certified = civil(proof['certifiedOn'])
    election = civil(election_date)
    if certified < election: raise ValueError('Certification precedes the election')
    zone = ZoneInfo(proof['timeZone'])
    if now.astimezone(zone).date() <= certified or (now - timedelta(hours=10)).date() <= certified:
        raise ValueError('Day-precision certification cannot be asserted before that civil day has completed')
    document, raw = documents[proof['documentId']]
    if document['role'] != 'certification': raise ValueError('Certification requires a separate explicitly scoped document')
    if document['format'] == 'pdf':
        visual_binding(proof, raw, now, signed=True)
        method = 'human_reviewed_signed_government_pdf'
    elif document['format'] == 'json':
        source = json.loads(raw)
        fields = proof['bindings']
        for key, expected in [('state', state), ('electionDate', election_date), ('certifiedOn', proof['certifiedOn']), ('status', 'certified')]:
            if pointer(source, fields[key]) != expected: raise ValueError('Certification JSON facts differ from reviewed binding')
        if pointer(source, fields['resultDocuments']) != proof.get('resultDocuments'):
            raise ValueError('Certification JSON does not bind the exact result-document hashes')
        if pointer(source, fields['contestIds']) != proof['contestIds']:
            raise ValueError('Certification JSON contest scope differs')
        method = 'machine_verified_json_binding'
    else: raise ValueError('Certification requires reviewed signed PDF or explicit JSON certification facts')
    results = proof.get('resultDocuments')
    if not isinstance(results, dict) or not results: raise ValueError('Certification must bind the exact reviewed result-document hashes')
    for doc_id, checksum in results.items():
        doc, _ = documents[doc_id]
        if doc['role'] != 'results' or doc['sha256'] != checksum: raise ValueError('Certification does not bind this result-document revision')
    return method


def start_rule(rule, documents, contest, state, election_date, now):
    if not rule: return {'startDateStatus': 'requires_office_specific_verification'}
    if rule.get('state') != state: raise ValueError('Start rule belongs to a different state')
    if rule.get('officeTitle') != contest['officeTitle'] or rule.get('officeKind') != contest['officeKind'] or rule.get('district') != contest.get('district'):
        raise ValueError('Start rule is not explicitly reviewed for this office and district')
    doc, raw = documents[rule['documentId']]
    if doc['role'] != 'startRule': raise ValueError('Start dates require an explicitly scoped government rule')
    precision = rule['datePrecision']
    if precision not in ('day', 'instant'): raise ValueError('Unknown start-date precision')
    if doc['format'] == 'pdf':
        visual_binding(rule, raw, now)
        method = 'human_reviewed_government_pdf'
    elif doc['format'] == 'json':
        source = json.loads(raw)
        if pointer(source, rule['bindings']['state']) != state or pointer(source, rule['bindings']['officeTitle']) != contest['officeTitle'] or pointer(source, rule['bindings']['officeKind']) != contest['officeKind']:
            raise ValueError('Start-rule jurisdiction or office is not bound')
        if contest.get('district') is not None and str(pointer(source, rule['bindings']['district'])) != str(contest['district']):
            raise ValueError('Start-rule district is not bound')
        key = 'scheduledStartDate' if precision == 'day' else 'scheduledStart'
        if pointer(source, rule['bindings'][key]) != rule[key]: raise ValueError('Start date differs from explicit government rule binding')
        if precision == 'instant' and pointer(source, rule['bindings']['timeZone']) != rule['timeZone']:
            raise ValueError('Start time zone differs from the explicit government rule binding')
        method = 'machine_verified_json_binding'
    else: raise ValueError('Start rule requires pinned PDF review or explicit JSON facts')
    if precision == 'day':
        if rule.get('scheduledStart') is not None: raise ValueError('Day-only start rules cannot manufacture a UTC instant')
        value = civil(rule['scheduledStartDate'])
        result = {'scheduledStartDate': rule['scheduledStartDate'], 'startDatePrecision': 'day', 'startDateStatus': 'verified_civil_date'}
        if not isinstance(rule.get('timeZone'), str) or not rule['timeZone']:
            raise ValueError('A civil start date requires an explicitly reviewed local time zone')
        ZoneInfo(rule['timeZone']); result['startTimeZone'] = rule['timeZone']
    else:
        if rule.get('timeExplicit') is not True or rule.get('timeZoneExplicit') is not True:
            raise ValueError('An exact instant requires explicitly reviewed clock time and time zone')
        zone = ZoneInfo(rule['timeZone'])
        stamp = instant(rule['scheduledStart'])
        given = datetime.fromisoformat(rule['scheduledStart'].replace('Z', '+00:00'))
        if given.utcoffset() != stamp.astimezone(zone).utcoffset(): raise ValueError('Explicit start offset differs from the reviewed time zone')
        value = stamp.astimezone(zone).date()
        result = {'scheduledStart': stamp.isoformat().replace('+00:00', 'Z'), 'startDatePrecision': 'instant', 'startDateStatus': 'verified_instant', 'startTimeZone': rule['timeZone']}
    election = civil(election_date)
    if value < election or value.year > election.year + 2: raise ValueError('Start date is outside the reviewed election cycle')
    result['startRule'] = {'url': doc['url'], 'sha256': doc['sha256'], 'method': method, 'datePrecision': precision, 'review': rule.get('review'), 'pages': rule.get('pages'),
                           'excerpt': rule.get('statement') or (contest['officeTitle'] + ': ' + str(rule.get('scheduledStartDate') or rule.get('scheduledStart')))}
    return result


def collect_reviewed(fetch, now, package):
    """Import a pinned package; missing or unconfigured states remain coverage gaps."""
    if not isinstance(now, datetime) or now.tzinfo is None: raise ValueError('Check time requires an explicit UTC offset')
    now = now.astimezone(timezone.utc)
    state = package.get('state')
    if package.get('schemaVersion') != 1 or state not in STATES: raise ValueError('Reviewed package must identify one of the fifty states')
    election_date = package['electionDate']
    if civil(election_date) >= now.date(): raise ValueError('Future or incomplete election day cannot have certified imported results')
    review(package.get('review'), now)
    checked = now.isoformat().replace('+00:00', 'Z')
    documents = {}
    document_records = []
    for spec in package['documents']:
        if spec['id'] in documents or spec.get('role') not in ('results', 'certification', 'startRule') or spec.get('format') not in ('json', 'csv', 'pdf'):
            raise ValueError('Duplicate or unsupported reviewed document')
        url = urlparse(spec['url'])
        if url.scheme != 'https' or not url.hostname or url.username or url.password or url.fragment:
            raise ValueError('Reviewed documents require approved HTTPS URLs')
        if not re.fullmatch('[0-9a-f]{64}', spec['sha256']): raise ValueError('Every government document needs a pinned SHA-256')
        raw = fetch(spec['url'])
        if hashlib.sha256(raw).hexdigest() != spec['sha256']: raise ValueError('Government document changed; new review required')
        documents[spec['id']] = (dict(spec), raw)
        document_records.append({'id': spec['id'], 'url': spec['url'], 'sha256': spec['sha256'], 'role': spec['role'], 'format': spec['format'], 'retrievedAt': checked, 'bytes': len(raw)})
    contests = package.get('contests', [])
    if not contests or len({c['id'] for c in contests}) != len(contests): raise ValueError('Reviewed package needs distinct contest IDs')
    proof = package['certification']
    cert_method = certification(proof, documents, state, election_date, [c['id'] for c in contests], now)
    result = []
    for contest in contests:
        scoped_office(contest, state, election_date)
        binding = contest['resultBinding']
        document, raw = documents[binding['documentId']]
        if document['role'] != 'results' or proof['resultDocuments'].get(document['id']) != document['sha256']:
            raise ValueError('Contest results are not bound to this certification revision')
        if document['format'] == 'pdf':
            visual_binding(binding, raw, now)
            if binding.get('completeCandidateSetReviewed') is not True or binding.get('finalOutcomeReviewed') is not True or binding.get('state') != state or binding.get('electionDate') != election_date or binding.get('officeTitle') != contest['officeTitle'] or binding.get('electionType') != contest['electionType'] or binding.get('district') != contest.get('district'):
                raise ValueError('Visual results need explicit state, date, office, district, full-candidate and final-outcome review')
            candidates, winner = canonical_candidates(binding['reviewedCandidates'])
            method = 'human_reviewed_government_pdf'
        else:
            candidates, winner = structured_result(raw, document, binding, contest, state, election_date)
            method = 'machine_verified_' + document['format'] + '_binding'
        if contest.get('winner') != winner: raise ValueError('Normalized winner differs from the bound government result')
        normalized = {key: contest[key] for key in ('id', 'state', 'electionDate', 'officeKind', 'officeTitle')}
        normalized.update(district=contest.get('district'), electionType=contest['electionType'],
                          candidates=[{k: v for k, v in c.items() if k != 'winner'} for c in candidates], winner=winner, leader=dict(winner),
                          certificationStatus='certified', certificationLevel='state', certifiedOn=proof['certifiedOn'], certificationDatePrecision='day',
                          resultVerificationMethod=method, certificationVerificationMethod=cert_method,
                          resultDocumentUrl=document['url'], resultDocumentSha256=document['sha256'],
                          certificationDocumentUrl=documents[proof['documentId']][0]['url'],
                          certificationDocumentSha256=documents[proof['documentId']][0]['sha256'])
        if contest.get('officeId'): normalized['officeId'] = contest['officeId']
        normalized.update(start_rule(contest.get('startRule'), documents, contest, state, election_date, now))
        result.append(normalized)
    return {'state': state, 'stateId': state, 'electionDate': election_date, 'checkedAt': checked,
            'certificationStatus': 'certified', 'certifiedOn': proof['certifiedOn'],
            'review': dict(package['review']), 'certificationReview': {**proof, 'datePrecision': 'day', 'method': cert_method},
            'contests': result, 'sourceDocuments': document_records,
            'coverage': {'scope': package.get('coverageScope', 'explicitly_reviewed_contests_only'), 'contestCount': len(result),
                         'completeStateCoverage': False, 'unconfiguredContestsRemainGaps': True,
                         'startDatesVerified': all(c['startDateStatus'] != 'requires_office_specific_verification' for c in result)}}
