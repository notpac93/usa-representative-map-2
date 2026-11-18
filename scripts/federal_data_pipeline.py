#!/usr/bin/env python3
"""On-demand federal data checks and guarded, recoverable publication (stdlib only)."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
import gzip
import hashlib
import json
import os
from pathlib import Path
import sys
import time
import tempfile
from urllib.error import HTTPError, URLError
import uuid

try:
    from . import refresh_federal_officials as collector
except ImportError:
    import refresh_federal_officials as collector

ROOT = Path(__file__).resolve().parents[1]
UTC = timezone.utc
AUDIT_FIELDS = {'publishedAt', 'verifiedAt', 'retrievedAt', 'endedObservedAt', 'serviceConfirmedAt', 'evidenceIds', 'dataVersion'}
CONFIG_PATHS = ('scripts/data/federal_sources.json', 'assets/data/federal_sources.json',
                'scripts/data/federal_transition_plans.json', 'scripts/data/federal_reviewed_offices.json',
                'assets/data/senators.json', 'assets/data/houseMembers.json')


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def encoded(value):
    return (json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(',', ':')) + '\n').encode('utf-8')


def file_hash(path):
    return digest(path.read_bytes()) if path.exists() else None


def clean(value):
    if isinstance(value, dict):
        return {k: clean(v) for k, v in sorted(value.items()) if k not in AUDIT_FIELDS}
    if isinstance(value, list):
        items = [clean(v) for v in value]
        return sorted(items, key=lambda v: v['id']) if items and all(isinstance(v, dict) and 'id' in v for v in items) else items
    return value


def business_data(snapshot):
    return {k: clean(snapshot.get(k, [])) for k in ('people', 'offices', 'terms')}


def version(snapshot):
    return digest(encoded(business_data(snapshot)))


def differences(before, after):
    before = before or {}
    changes = []
    for collection in ('people', 'offices', 'terms'):
        old = {r['id']: clean(r) for r in before.get(collection, [])}
        new = {r['id']: clean(r) for r in after[collection]}
        for key in sorted(old.keys() | new.keys()):
            a, b = old.get(key), new.get(key)
            if a == b:
                continue
            fields = []
            if a is not None and b is not None:
                fields = [field for field in sorted(a.keys() | b.keys()) if a.get(field) != b.get(field)]
            changes.append({'collection': collection, 'id': key, 'action': 'added' if a is None else 'removed' if b is None else 'changed',
                            'fields': fields, 'before': a, 'after': b})
    return changes


def current_by_office(snapshot):
    people = {p['id']: p for p in snapshot.get('people', [])}
    return {t['officeId']: {'personId': t['personId'], 'name': people[t['personId']]['name'], 'contact': t.get('contact', {})}
            for t in snapshot.get('terms', []) if t['status'] == 'current'}


def review_reasons(before, after, changes):
    if before is None:
        return ['Initial publication requires review of the complete federal roster.']
    old, new = current_by_office(before), current_by_office(after)
    reasons = []
    for office in sorted(old):
        if office not in new:
            reasons.append(f'{office}: previously serving official is no longer present; verify vacancy or term expiration.')
        elif old[office]['personId'] != new[office]['personId']:
            reasons.append(f'{office}: serving official changed from {old[office]["name"]} to {new[office]["name"]}.')
        else:
            for field, value in old[office]['contact'].items():
                if value and not new[office]['contact'].get(field):
                    reasons.append(f'{office}: previously available {field} is missing.')
    for change in changes:
        if change['action'] == 'removed':
            reasons.append(f'{change["collection"]}/{change["id"]}: historical record removed.')
    if len(changes) > 50:
        reasons.append(f'Large update affects {len(changes)} records; inspect the report before publication.')
    return reasons


def configurations(root):
    values = {path: file_hash(root / path) for path in CONFIG_PATHS}
    # A saved candidate must be rechecked when either the collection or publication rules change.
    for path in ('scripts/refresh_federal_officials.py', 'scripts/federal_data_pipeline.py', 'scripts/publish_federal_snapshot.sh'):
        values[path] = file_hash(root / path)
    return values


def retry_fetch(url, source):
    for attempt in range(3):
        try:
            return collector.fetch(url, source)
        except HTTPError as error:
            if error.code not in (429, 500, 502, 503, 504) or attempt == 2:
                raise
        except (URLError, TimeoutError, ConnectionError):
            if attempt == 2:
                raise
        time.sleep(2 ** attempt)


def load_registry(root):
    registry = json.loads((root / CONFIG_PATHS[0]).read_text())
    if registry != json.loads((root / CONFIG_PATHS[1]).read_text()):
        raise ValueError('The government source registry and app registry differ.')
    return registry


def write_reports(run, report):
    collector.atomic_json(run / 'report.json', report)
    lines = [f'# Federal data check: {report["status"]}', '', f'Checked: {report["checkedAt"]}',
             f'Run: {report["runId"]}', f'Meaningful record changes: {len(report.get("changes", []))}', '']
    if report.get('error'):
        lines += ['Error: ' + report['error'], 'The published snapshot was not replaced.', '']
    if report.get('dataVersion'):
        lines += ['Data version: `' + report['dataVersion'] + '`', '']
    lines += ['## Government downloads', '']
    for source in report.get('downloads', []):
        lines.append(f'- {source["sourceId"]}: {source["status"]} — {source["url"]}' + (' (source content changed)' if source.get('contentChanged') else ''))
    lines += ['', '## Review required', ''] + ['- ' + reason for reason in report.get('reviewReasons', [])]
    if not report.get('reviewReasons'):
        lines.append('None.')
    lines += ['', '## Data differences', '']
    for change in report.get('changes', []):
        lines.append(f'- {change["collection"]}/{change["id"]}: {change["action"]}' + (' (' + ', '.join(change['fields']) + ')' if change['fields'] else ''))
        if change['action'] == 'changed':
            for field in change['fields']:
                lines.append(f'  - {field}: {json.dumps(change["before"].get(field), ensure_ascii=False)} → {json.dumps(change["after"].get(field), ensure_ascii=False)}')
        else:
            lines.append('  - ' + json.dumps(change['after'] or change['before'], ensure_ascii=False))
    if not report.get('changes'):
        lines.append('No meaningful official data changed. Source-page or verification-time changes alone are not data changes.')
    (run / 'report.md').write_text('\n'.join(lines) + '\n')


def check(snapshot_path, runs_dir, root=ROOT, loader=retry_fetch):
    started = datetime.now(UTC)
    run_id = started.strftime('%Y%m%dT%H%M%S') + '-' + uuid.uuid4().hex[:8]
    run = runs_dir / run_id
    (run / 'sources').mkdir(parents=True)
    report = {'schemaVersion': 1, 'runId': run_id, 'checkedAt': collector.iso(started), 'status': 'failed', 'downloads': [], 'changes': []}
    baseline_hash = file_hash(snapshot_path)
    try:
        input_hashes = configurations(root)
        registry = load_registry(root)
        previous = json.loads(snapshot_path.read_text()) if snapshot_path.exists() else None
        if previous:
            collector.validate(previous, registry)
            collector.atomic_json(run / 'baseline.json', previous)
        observed_hashes = {}
        for proof in sorted((previous or {}).get('evidence', []), key=lambda p: p['retrievedAt']):
            observed_hashes[proof['url']] = proof['sha256']
        plans = json.loads((root / CONFIG_PATHS[2]).read_text())
        def archived_fetch(url, source):
            record = {'sourceId': source['id'], 'url': url, 'status': 'failed'}
            report['downloads'].append(record)
            raw = loader(url, source)
            checksum = digest(raw)
            (run / 'sources' / (checksum + '.source.gz')).write_bytes(gzip.compress(raw, mtime=0))
            record.update(status='passed', sha256=checksum, bytes=len(raw), retrievedAt=collector.iso(datetime.now(UTC)), previousSha256=observed_hashes.get(url), contentChanged=observed_hashes.get(url) != checksum)
            return raw
        candidate = collector.refresh(previous, registry, plans, started, archived_fetch)
        if input_hashes != configurations(root) or baseline_hash != file_hash(snapshot_path):
            raise ValueError('Inputs or published data changed during the check; retry against a stable version.')
        candidate['publishedAt'] = collector.iso(datetime.now(UTC))
        downloads = {d['url']: d for d in report['downloads']}
        for proof in candidate['evidence']:
            observation = downloads.get(proof['url'])
            if observation and proof['sha256'] == observation['sha256']:
                proof['retrievedAt'] = observation['retrievedAt']
        candidate['sources'] = registry['sources']
        candidate['dataVersion'] = version(candidate)
        collector.validate(candidate, registry)
        changes = differences(previous, candidate)
        reasons = review_reasons(previous, candidate, changes)
        report.update(status='review_required' if reasons else 'passed', checkedAt=candidate['publishedAt'],
                      dataVersion=candidate['dataVersion'], changes=changes, reviewReasons=reasons,
                      currentOffices=len(current_by_office(candidate)), totalOffices=len(candidate['offices']))
        collector.atomic_json(run / 'candidate.json', candidate)
        collector.atomic_json(run / 'manifest.json', {'schemaVersion': 1, 'runId': run_id, 'checkedAt': candidate['publishedAt'],
            'baselineSha256': baseline_hash, 'candidateSha256': file_hash(run / 'candidate.json'),
            'dataVersion': candidate['dataVersion'], 'configurations': input_hashes,
            'downloads': report['downloads']})
    except Exception as error:
        report.update(status='failed', error=f'{type(error).__name__}: {error}')
    write_reports(run, report)
    return run, report


@contextmanager
def publication_lock(snapshot_path):
    snapshot_path.parent.mkdir(parents=True, exist_ok=True)
    lock = snapshot_path.with_suffix(snapshot_path.suffix + '.publish-lock')
    try:
        descriptor = os.open(lock, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        raise ValueError('Another publication is in progress (or an interrupted publication left a lock); check before retrying.')
    try:
        os.write(descriptor, str(os.getpid()).encode())
        yield
    finally:
        os.close(descriptor)
        lock.unlink()


def publish(run, snapshot_path, releases_dir, approval=None, root=ROOT, now=None):
    now = now or datetime.now(UTC)
    manifest = json.loads((run / 'manifest.json').read_text())
    checked = collector.instant(manifest['checkedAt'])
    if checked > now or now - checked > timedelta(hours=24):
        raise ValueError('Candidate check is future-dated or more than 24 hours old; run a new government check.')
    if configurations(root) != manifest['configurations']:
        raise ValueError('Collection rules or configuration changed since this check; run it again.')
    if file_hash(run / 'candidate.json') != manifest['candidateSha256']:
        raise ValueError('Staged candidate changed after validation.')
    candidate = json.loads((run / 'candidate.json').read_text())
    registry = load_registry(root)
    collector.validate(candidate, registry)
    if version(candidate) != manifest['dataVersion'] or candidate.get('dataVersion') != manifest['dataVersion']:
        raise ValueError('Candidate data version mismatch.')
    for download in manifest['downloads']:
        if download['status'] != 'passed':
            raise ValueError('Government download failed.')
        raw = gzip.decompress((run / 'sources' / (download['sha256'] + '.source.gz')).read_bytes())
        if digest(raw) != download['sha256']:
            raise ValueError('Saved government response failed integrity verification.')
    with publication_lock(snapshot_path):
        if file_hash(snapshot_path) != manifest['baselineSha256']:
            raise ValueError('Published data changed since this check; recheck against the latest version.')
        previous = json.loads(snapshot_path.read_text()) if snapshot_path.exists() else None
        reasons = review_reasons(previous, candidate, differences(previous, candidate))
        if reasons and approval != manifest['dataVersion']:
            raise ValueError('Review required. Read report.md, then approve this exact data version with --approve ' + manifest['dataVersion'])
        release = releases_dir / manifest['runId']
        if release.exists():
            raise ValueError('Release already exists; refusing to overwrite history.')
        release.mkdir(parents=True)
        # Store rollback data, evidence, and report BEFORE the app's canonical file is replaced.
        collector.atomic_json(release / 'snapshot.json', candidate)
        if previous:
            (release / 'previous.json').write_bytes(snapshot_path.read_bytes())
        collector.atomic_json(release / 'manifest.json', manifest)
        collector.atomic_json(release / 'publication.json', {'publishedAt': collector.iso(now), 'dataVersion': manifest['dataVersion'],
            'approvedDataVersion': approval if reasons else None, 'reviewReasons': reasons})
        for name in ('report.json', 'report.md'):
            (release / name).write_bytes((run / name).read_bytes())
        evidence_store = releases_dir.parent / 'evidence'
        evidence_store.mkdir(parents=True, exist_ok=True)
        for download in manifest['downloads']:
            name = download['sha256'] + '.source.gz'
            target = evidence_store / name
            if not target.exists():
                target.write_bytes((run / 'sources' / name).read_bytes())
        # This is the publication commit point; everything above may fail without changing the app data.
        collector.atomic_json(snapshot_path, candidate)
    return release


def atomic_bytes(path, raw):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile('wb', dir=path.parent, delete=False) as handle:
            temporary = handle.name
            handle.write(raw)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if temporary and os.path.exists(temporary): os.unlink(temporary)


def rollback(release, snapshot_path, releases_dir, root=ROOT):
    manifest = json.loads((release / 'manifest.json').read_text())
    previous_path = release / 'previous.json'
    if not previous_path.exists() or file_hash(previous_path) != manifest['baselineSha256']:
        raise ValueError('Recovery copy is missing or its integrity check failed.')
    previous = json.loads(previous_path.read_text())
    collector.validate(previous, load_registry(root))
    with publication_lock(snapshot_path):
        if file_hash(snapshot_path) != manifest['candidateSha256']:
            raise ValueError('This release is not the currently published version; refusing to overwrite later work.')
        audit = releases_dir / ('rollback-' + datetime.now(UTC).strftime('%Y%m%dT%H%M%S') + '-' + uuid.uuid4().hex[:8])
        audit.mkdir(parents=True)
        (audit / 'replaced.json').write_bytes(snapshot_path.read_bytes())
        collector.atomic_json(audit / 'recovery.json', {'restoredFrom': str(release), 'restoredSha256': manifest['baselineSha256'],
                             'replacedSha256': manifest['candidateSha256'], 'recoveredAt': collector.iso(datetime.now(UTC))})
        atomic_bytes(snapshot_path, previous_path.read_bytes())
    return audit


def verify_published(snapshot_path, releases_dir, root=ROOT, expected_previous=None):
    snapshot = json.loads(snapshot_path.read_text())
    collector.validate(snapshot, load_registry(root))
    current_hash = file_hash(snapshot_path)
    for manifest_path in sorted(releases_dir.glob('*/manifest.json'), reverse=True):
        manifest = json.loads(manifest_path.read_text())
        if manifest['candidateSha256'] != current_hash:
            continue
        if expected_previous is not None and file_hash(expected_previous) != manifest['baselineSha256']:
            raise ValueError('Remote published data differs from the checked baseline; restore the latest data and recheck.')
        if file_hash(manifest_path.parent / 'snapshot.json') != current_hash or version(snapshot) != manifest['dataVersion']:
            raise ValueError('Published release integrity check failed.')
        if configurations(root) != manifest['configurations']:
            raise ValueError('Publisher configuration changed; run a fresh check and publication.')
        for download in manifest['downloads']:
            archive = releases_dir.parent / 'evidence' / (download['sha256'] + '.source.gz')
            if digest(gzip.decompress(archive.read_bytes())) != download['sha256']:
                raise ValueError('Published government evidence failed integrity verification.')
        return manifest_path.parent
    raise ValueError('No validated release matches the current snapshot. Run the guarded publisher first.')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--verify-published', action='store_true', help='Verify the current snapshot matches its saved release and government evidence.')
    mode.add_argument('--check', action='store_true', help='Download, validate and report only (default).')
    mode.add_argument('--publish', action='store_true', help='Check and publish if safeguards pass.')
    mode.add_argument('--rollback-release', type=Path, help='Restore the previous snapshot for the currently published release.')
    mode.add_argument('--publish-run', type=Path, help='Publish an already checked, unchanged candidate.')
    parser.add_argument('--expected-previous', type=Path, help='When verifying, require this prior snapshot to match the publication baseline.')
    parser.add_argument('--approve', help='Exact data version from a reviewed change report.')
    parser.add_argument('--snapshot', '--output', dest='snapshot', type=Path, default=ROOT / 'assets/data/federal_officials.json')
    parser.add_argument('--runs-dir', type=Path, default=ROOT / 'tmp/federal-checks')
    parser.add_argument('--releases-dir', type=Path, default=ROOT / 'data/federal/releases')
    args = parser.parse_args(argv)
    if args.verify_published:
        try:
            release = verify_published(args.snapshot, args.releases_dir, expected_previous=args.expected_previous)
        except Exception as error:
            print(f'Published verification failed: {error}', file=sys.stderr)
            return 1
        print(f'Published data, source evidence, and recovery release verified: {release}')
        return 0
    if args.rollback_release:
        try:
            audit = rollback(args.rollback_release, args.snapshot, args.releases_dir)
        except Exception as error:
            print(f'Recovery blocked; latest data preserved. {error}', file=sys.stderr)
            return 2
        print(f'Restored the previous verified snapshot with its original verification date. Recovery audit: {audit}')
        return 0
    if args.publish_run:
        run = args.publish_run
    else:
        run, report = check(args.snapshot, args.runs_dir)
        print(f'Check: {report["status"]}; {len(report["changes"])} meaningful record changes. Report: {run / "report.md"}')
        if report['status'] == 'failed':
            print(report['error'], file=sys.stderr)
            return 1
        if not args.publish:
            return 2 if report['status'] == 'review_required' else 0
    try:
        release = publish(run, args.snapshot, args.releases_dir, args.approve)
    except Exception as error:
        print(f'Publication blocked; latest data preserved. {error}', file=sys.stderr)
        return 2
    print(f'Published verified snapshot. Recovery copy and audit record: {release}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
