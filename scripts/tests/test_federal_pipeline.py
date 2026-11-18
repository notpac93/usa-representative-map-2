import copy
from datetime import datetime, timedelta, timezone
import gzip
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import federal_data_pipeline as pipeline


class FederalPipelineTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.snapshot = self.root / 'assets/data/federal_officials.json'
        self.snapshot.parent.mkdir(parents=True)
        for relative in pipeline.CONFIG_PATHS:
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / relative).read_bytes())
        self.original = json.loads((ROOT / 'assets/data/federal_officials.json').read_text())
        self.original.pop('dataVersion', None)
        pipeline.collector.atomic_json(self.snapshot, self.original)
        self.runs = self.root / 'runs'
        self.releases = self.root / 'data/federal/releases'
        self.registry = json.loads((ROOT / 'scripts/data/federal_sources.json').read_text())
        self.candidate = copy.deepcopy(self.original)
        self.candidate['publishedAt'] = pipeline.collector.iso(datetime.now(timezone.utc))
        self.source_bytes = b'Fixture government response for publisher integrity tests'

    def staged(self, candidate=None):
        candidate = copy.deepcopy(candidate or self.candidate)
        def collect(previous, registry, plans, now, loader):
            source = registry['sources'][0]
            loader(source['url'], source)
            return candidate
        with patch.object(pipeline, 'load_registry', return_value=self.registry), \
             patch.object(pipeline.collector, 'refresh', side_effect=collect):
            return pipeline.check(self.snapshot, self.runs, root=self.root, loader=lambda *args: self.source_bytes)

    def publish(self, run, approval=None):
        with patch.object(pipeline, 'load_registry', return_value=self.registry):
            return pipeline.publish(run, self.snapshot, self.releases, approval, root=self.root)

    def test_check_never_overwrites_latest(self):
        before = self.snapshot.read_bytes()
        run, report = self.staged()
        self.assertEqual(report['status'], 'passed')
        self.assertEqual(report['changes'], [])
        self.assertEqual(self.snapshot.read_bytes(), before)
        self.assertTrue((run / 'candidate.json').exists())
        self.assertTrue((run / 'report.md').exists())

    def test_unchanged_data_has_stable_version_despite_metadata_and_order(self):
        b = copy.deepcopy(self.original)
        b['publishedAt'] = '2030-01-01T00:00:00Z'
        b['people'].reverse()
        b['terms'][0]['verifiedAt'] = b['publishedAt']
        b['terms'][0]['evidenceIds'] = ['different-source-page-hash']
        b['evidence'][0]['sha256'] = 'a' * 64
        self.assertEqual(pipeline.version(self.original), pipeline.version(b))
        self.assertEqual(pipeline.differences(self.original, b), [])

    def test_contact_change_is_reported_with_old_and_new_values(self):
        target = next(t for t in self.candidate['terms'] if t.get('contact', {}).get('phone'))
        before = target['contact']['phone']
        target['contact']['phone'] = '202-555-0199'
        run, report = self.staged()
        self.assertEqual(report['status'], 'passed')
        self.assertEqual(len(report['changes']), 1)
        text = (run / 'report.md').read_text()
        self.assertIn(before, text)
        self.assertIn('202-555-0199', text)

    def test_missing_official_requires_review_and_exact_version_approval(self):
        self.candidate['terms'][0]['status'] = 'ended'
        run, report = self.staged()
        self.assertEqual(report['status'], 'review_required')
        before = self.snapshot.read_bytes()
        with self.assertRaisesRegex(ValueError, 'Review required'): self.publish(run)
        with self.assertRaisesRegex(ValueError, 'Review required'): self.publish(run, 'wrong-version')
        self.assertEqual(self.snapshot.read_bytes(), before)
        self.publish(run, report['dataVersion'])
        self.assertNotEqual(self.snapshot.read_bytes(), before)

    def test_lost_contact_requires_review(self):
        t = next(t for t in self.candidate['terms'] if t.get('contact', {}).get('phone'))
        del t['contact']['phone']
        _, report = self.staged()
        self.assertEqual(report['status'], 'review_required')
        self.assertTrue(any('phone is missing' in r for r in report['reviewReasons']))

    def test_network_failure_produces_report_and_preserves_latest(self):
        before = self.snapshot.read_bytes()
        def fail(*args): raise OSError('Government host unavailable')
        with patch.object(pipeline, 'load_registry', return_value=self.registry):
            run, report = pipeline.check(self.snapshot, self.runs, root=self.root, loader=fail)
        self.assertEqual(report['status'], 'failed')
        self.assertIn('Government host unavailable', report['error'])
        self.assertEqual(self.snapshot.read_bytes(), before)
        self.assertFalse((run / 'manifest.json').exists())

    def test_tampered_candidate_and_source_evidence_are_blocked(self):
        run, _ = self.staged()
        before = self.snapshot.read_bytes()
        (run / 'candidate.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'changed after validation'): self.publish(run)
        run, _ = self.staged()
        archive = next((run / 'sources').glob('*.gz'))
        archive.write_bytes(gzip.compress(b'altered government response'))
        with self.assertRaisesRegex(ValueError, 'integrity'): self.publish(run)
        self.assertEqual(self.snapshot.read_bytes(), before)

    def test_concurrent_publication_prevents_stale_candidate_overwrite(self):
        run, _ = self.staged()
        self.snapshot.write_bytes(self.snapshot.read_bytes() + b'\n')
        with self.assertRaisesRegex(ValueError, 'Published data changed'): self.publish(run)

    def test_configuration_change_during_download_fails_closed(self):
        original = self.snapshot.read_bytes()
        def collect(previous, registry, plans, now, loader):
            (self.root / pipeline.CONFIG_PATHS[2]).write_text('changed during collection')
            return self.candidate
        with patch.object(pipeline, 'load_registry', return_value=self.registry), patch.object(pipeline.collector, 'refresh', side_effect=collect):
            _, report = pipeline.check(self.snapshot, self.runs, root=self.root)
        self.assertEqual(report['status'], 'failed')
        self.assertIn('changed during the check', report['error'])
        self.assertEqual(self.snapshot.read_bytes(), original)

    def test_configuration_change_invalidates_candidate(self):
        run, _ = self.staged()
        (self.root / 'scripts/data').mkdir(parents=True, exist_ok=True)
        (self.root / 'scripts/data/federal_sources.json').write_text('changed rules')
        with self.assertRaisesRegex(ValueError, 'configuration changed'): self.publish(run)

    def test_expired_and_future_candidates_are_blocked(self):
        run, _ = self.staged()
        checked = pipeline.collector.instant(json.loads((run / 'manifest.json').read_text())['checkedAt'])
        for now in (checked + timedelta(hours=25), checked - timedelta(hours=1)):
            with patch.object(pipeline, 'load_registry', return_value=self.registry):
                with self.assertRaisesRegex(ValueError, '24 hours old'):
                    pipeline.publish(run, self.snapshot, self.releases, root=self.root, now=now)

    def test_recovery_copy_precedes_publication_and_rollback_restores_exact_bytes(self):
        original = self.snapshot.read_bytes()
        run, _ = self.staged()
        release = self.publish(run)
        self.assertEqual((release / 'previous.json').read_bytes(), original)
        with patch.object(pipeline, 'load_registry', return_value=self.registry):
            pipeline.verify_published(self.snapshot, self.releases, root=self.root)
            audit = pipeline.rollback(release, self.snapshot, self.releases, root=self.root)
        self.assertEqual(self.snapshot.read_bytes(), original)
        self.assertTrue((audit / 'recovery.json').exists())

    def test_remote_baseline_must_match_before_upload(self):
        run, _ = self.staged()
        self.publish(run)
        remote_copy = self.root / 'remote-current.json'
        remote_copy.write_text('newer remote data')
        with patch.object(pipeline, 'load_registry', return_value=self.registry):
            with self.assertRaisesRegex(ValueError, 'Remote published data differs'):
                pipeline.verify_published(self.snapshot, self.releases, root=self.root, expected_previous=remote_copy)

    def test_release_archive_failure_never_replaces_latest(self):
        original = self.snapshot.read_bytes()
        run, _ = self.staged()
        self.releases.parent.mkdir(parents=True, exist_ok=True)
        self.releases.write_text('not a directory')
        with self.assertRaises(OSError): self.publish(run)
        self.assertEqual(self.snapshot.read_bytes(), original)

    def test_lock_prevents_competing_publishers(self):
        run, _ = self.staged()
        lock = self.snapshot.with_suffix('.json.publish-lock')
        lock.write_text('other publisher')
        with self.assertRaisesRegex(ValueError, 'Another publication'): self.publish(run)

    def test_rollback_refuses_to_overwrite_a_later_publication(self):
        run, _ = self.staged()
        release = self.publish(run)
        self.snapshot.write_bytes(self.snapshot.read_bytes() + b'\n')
        with patch.object(pipeline, 'load_registry', return_value=self.registry):
            with self.assertRaisesRegex(ValueError, 'not the currently published'):
                pipeline.rollback(release, self.snapshot, self.releases, root=self.root)

    def test_duplicate_government_seats_are_rejected_before_merging(self):
        house=b'<MemberData><title-info><congress-num>119</congress-num></title-info><members>'+2*b'<member><statedistrict>CA01</statedistrict><member-info><bioguideID>A000001</bioguideID><official-name>Fixture</official-name></member-info></member>'+b'</members></MemberData>'
        with self.assertRaisesRegex(ValueError, 'Duplicate House'): pipeline.collector.parse_house(house)
        senate=b'<contact_information>'+2*b'<member><state>CA</state><class>Class I</class><bioguide_id>A000001</bioguide_id><first_name>Fixture</first_name><last_name>Test</last_name></member>'+b'</contact_information>'
        with self.assertRaisesRegex(ValueError, 'Duplicate Senate'): pipeline.collector.parse_senate(senate)

    def test_atomic_writer_leaves_original_when_serialization_fails(self):
        original = self.snapshot.read_bytes()
        files_before = sorted(self.snapshot.parent.iterdir())
        with self.assertRaises(TypeError): pipeline.collector.atomic_json(self.snapshot, {'unsupported': object()})
        self.assertEqual(self.snapshot.read_bytes(), original)
        self.assertEqual(sorted(self.snapshot.parent.iterdir()), files_before)

    def test_transient_http_failures_retry_but_permanent_errors_do_not(self):
        from urllib.error import HTTPError
        source = self.registry['sources'][0]
        temporary = HTTPError(source['url'], 503, 'temporarily unavailable', {}, None)
        permanent = HTTPError(source['url'], 404, 'missing', {}, None)
        self.addCleanup(temporary.close)
        self.addCleanup(permanent.close)
        with patch.object(pipeline.collector, 'fetch', side_effect=[temporary, self.source_bytes]) as fetch, patch.object(pipeline.time, 'sleep'):
            self.assertEqual(pipeline.retry_fetch(source['url'], source), self.source_bytes)
            self.assertEqual(fetch.call_count, 2)
        with patch.object(pipeline.collector, 'fetch', side_effect=permanent) as fetch:
            with self.assertRaises(HTTPError): pipeline.retry_fetch(source['url'], source)
            self.assertEqual(fetch.call_count, 1)


class FederalGitPublicationTest(unittest.TestCase):
    def test_bootstrap_and_second_publication_preserve_main_and_history(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'repo'
            remote = Path(temp) / 'remote.git'
            root.mkdir()
            def git(*args, cwd=root):
                return subprocess.run(['git', *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()
            git('init', '--bare', str(remote))
            git('init', '-b', 'main')
            git('config', 'user.email', 'fixture@example.invalid')
            git('config', 'user.name', 'Publication fixture')
            for relative in (*pipeline.CONFIG_PATHS, 'scripts/refresh_federal_officials.py', 'scripts/federal_data_pipeline.py', 'scripts/publish_federal_snapshot.sh'):
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / relative).read_bytes())
            snapshot = root / 'assets/data/federal_officials.json'
            snapshot.write_bytes((ROOT / 'assets/data/federal_officials.json').read_bytes())
            git('add', '.')
            git('commit', '-m', 'Main source fixture')
            git('remote', 'add', 'origin', str(remote))
            git('push', '-u', 'origin', 'main')
            main_head = git('rev-parse', 'HEAD')
            releases = root / 'data/federal/releases'
            for index in range(2):
                original = snapshot.read_bytes()
                data = json.loads(original)
                data['publishedAt'] = pipeline.collector.iso(datetime.now(timezone.utc))
                data['dataVersion'] = pipeline.version(data)
                pipeline.collector.atomic_json(snapshot, data)
                release = releases / f'fixture-{index}'
                release.mkdir(parents=True)
                (release / 'snapshot.json').write_bytes(snapshot.read_bytes())
                (release / 'previous.json').write_bytes(original)
                pipeline.collector.atomic_json(release / 'manifest.json', {'candidateSha256': pipeline.file_hash(snapshot), 'baselineSha256': pipeline.digest(original), 'dataVersion': data['dataVersion'], 'downloads': [], 'configurations': pipeline.configurations(root)})
                subprocess.run(['bash', str(root / 'scripts/publish_federal_snapshot.sh')], cwd=root, check=True, capture_output=True, text=True)
                self.assertEqual(git('rev-parse', 'HEAD'), main_head)
                self.assertEqual(git('branch', '--show-current'), 'main')
                published = git('--git-dir=' + str(remote), 'show', 'codex/federal-snapshots:assets/data/federal_officials.json')
                self.assertEqual(json.loads(published)['publishedAt'], data['publishedAt'])
            self.assertEqual(git('--git-dir=' + str(remote), 'rev-list', '--count', 'codex/federal-snapshots'), '2')
            self.assertTrue(git('--git-dir=' + str(remote), 'show', 'codex/federal-snapshots:data/federal/releases/fixture-0/manifest.json'))
            # Publishing an already-uploaded candidate must not overwrite a newer remote baseline.
            remote_head = git('--git-dir=' + str(remote), 'rev-parse', 'codex/federal-snapshots')
            result = subprocess.run(['bash', str(root / 'scripts/publish_federal_snapshot.sh')], cwd=root, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Remote published data differs', result.stderr)
            self.assertEqual(git('--git-dir=' + str(remote), 'rev-parse', 'codex/federal-snapshots'), remote_head)


if __name__ == '__main__': unittest.main()
