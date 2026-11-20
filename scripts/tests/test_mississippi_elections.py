import importlib.util
from datetime import datetime, timezone
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('mississippi_adapter', ROOT / 'scripts/election_adapters/mississippi.py')
ms = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ms)
NOW = datetime(2026, 11, 19, tzinfo=timezone.utc)
CALENDAR = 'Last Revised: 9/8/2026 13th Delivery of Returns: transmit certified recap sheets DECEMBER 3rd Declaration of General/Special Election Results by Secretary of State'


def native_summary(county='DeSoto'):
    return f'Official Recapitulation\nCounty of {county}\n3rd day of November 2026\nUnited States-Senate\nCounty Total\nScott Colom Democrat 10,000\nCindy Hyde-Smith Republican 9,000\nTy Pinkins Independent 100\n'


class MississippiTests(unittest.TestCase):
    def fetch(self, url):
        if url == ms.COUNTY_DOCUMENTS_URL:
            return ''.join(f'<a href="/elections/electionresults/2026General/{c} County.pdf">{c} County</a>' for c in ms.COUNTIES).encode()
        if url == ms.CALENDAR_URL: return b'%PDF Calendar'
        if url == ms.RECOGNITION_URL: return b'<h2>New Senators-Elect</h2><h3>Scott Colom (MS)</h3>'
        if url == ms.WICKER_URL: return b'Congratulations to Senator-elect Scott Colom.'
        if url.endswith('.pdf'): return b'%PDF Scanned recap'
        return b'2026 General Election Results'

    def extract(self, raw):
        return CALENDAR if b'Calendar' in raw else ''

    def test_recognized_incoming_is_not_statewide_certified(self):
        result = ms.collect_mississippi(self.fetch, NOW, county_names=['DeSoto'], extract_pdf=self.extract)
        c = result['contests'][0]
        self.assertEqual(c['governmentRecognizedIncoming']['name'], 'Scott Colom')
        self.assertFalse(c['certified'])
        self.assertIsNone(c['scheduledStart'])
        self.assertEqual(result['certificationCalendar']['stateDeclarationScheduled'], '2026-12-03')
        self.assertFalse(result['coverage']['countyAggregationComplete'])

    def test_scanned_pdf_does_not_invent_votes(self):
        result = ms.collect_mississippi(self.fetch, NOW, county_names=['DeSoto'], extract_pdf=self.extract)
        self.assertEqual(result['coverage']['validatedCountyTotals'], 0)
        self.assertEqual(result['contests'][0]['candidates'], [])
        self.assertEqual(result['coverage']['unreviewedCounties'][0]['reason'], 'scanned_pdf_requires_ocr_and_review')

    def test_missing_recognition_does_not_assert_incoming(self):
        def loader(url): return b'<h3>Someone else (MS)</h3>' if url == ms.RECOGNITION_URL else self.fetch(url)
        result = ms.collect_mississippi(loader, NOW, county_names=[], extract_pdf=self.extract)
        self.assertEqual(result['contests'], [])

    def test_only_explicit_single_total_columns_are_parsed(self):
        self.assertEqual(ms.parse_county_totals(native_summary(), 'DeSoto')['Scott Colom'], 10000)
        with self.assertRaisesRegex(ValueError, 'Precinct columns'):
            ms.parse_county_totals(native_summary().replace('10,000', '100 200 10,000'), 'DeSoto')
        with self.assertRaisesRegex(ValueError, 'Repeated'):
            ms.parse_county_totals(native_summary() + 'Scott Colom Democrat 1\n', 'DeSoto')
        with self.assertRaisesRegex(ValueError, 'County identity'):
            ms.parse_county_totals(native_summary(), 'Jackson')

    def test_wrong_day_and_unreconciled_writeins_require_review(self):
        with self.assertRaisesRegex(ValueError, 'Election date'):
            ms.parse_county_totals(native_summary().replace('3rd day', '23rd day'), 'DeSoto')
        with self.assertRaisesRegex(ValueError, 'Write-in totals'):
            ms.parse_county_totals(native_summary() + 'Write-in 20\n', 'DeSoto')

    def test_partial_county_totals_never_become_statewide_winner(self):
        result = ms.collect_mississippi(self.fetch, NOW, county_names=['DeSoto'], extract_pdf=lambda raw: CALENDAR if b'Calendar' in raw else native_summary())
        self.assertEqual(result['coverage']['validatedCountyTotals'], 1)
        self.assertFalse(result['coverage']['countyAggregationComplete'])
        self.assertIsNone(result['contests'][0]['leader'])

    def test_all_counties_can_aggregate_without_claiming_state_certification(self):
        def extract(raw):
            if b'Calendar' in raw: return CALENDAR
            return native_summary(raw.decode().removeprefix('%PDF '))
        def loader(url):
            if '/2026General/' in url:
                from urllib.parse import unquote
                return ('%PDF ' + unquote(url.rsplit('/', 1)[1]).removesuffix(' County.pdf')).encode()
            return self.fetch(url)
        result = ms.collect_mississippi(loader, NOW, extract_pdf=extract)
        self.assertEqual(len(ms.COUNTIES), 82)
        self.assertTrue(result['coverage']['countyAggregationComplete'])
        self.assertFalse(result['contests'][0]['certified'])
        self.assertEqual(result['contests'][0]['leader']['votes'], 820000)

    def test_blocked_index_and_missing_county_are_reported(self):
        def loader(url):
            if url == ms.COUNTY_INDEX_URL or url.endswith('DeSoto%20County.pdf'): raise OSError('HTTP 403')
            return self.fetch(url)
        result = ms.collect_mississippi(loader, NOW, county_names=['DeSoto'], extract_pdf=self.extract)
        self.assertEqual(result['coverage']['retrievedCounties'], 0)
        self.assertTrue(any(d['status'] == 'unavailable' for d in result['sourceDocuments']))
        self.assertFalse(result['contests'][0]['certified'])

    def test_invalid_counties_and_naive_time_are_rejected(self):
        with self.assertRaises(ValueError): ms.collect_mississippi(self.fetch, NOW, county_names=['Not A County'])
        with self.assertRaises(ValueError): ms.collect_mississippi(self.fetch, datetime(2026, 11, 19), county_names=[])

    def test_county_urls_come_from_real_index_and_preserve_official_spelling(self):
        raw = b'<a href="/elections/electionresults/2026General/Adams.pdf">Adams</a><a href="/elections/electionresults/2026General/Walthal County.pdf">Walthal County</a>'
        links = ms.parse_county_links(raw)
        self.assertTrue(links['Adams'].endswith('/Adams.pdf'))
        self.assertTrue(links['Walthall'].endswith('/Walthal%20County.pdf'))
        self.assertEqual(ms.parse_county_links(b'<a href="https://attacker.example/DeSoto.pdf">DeSoto County</a>'), {})
        with self.assertRaises(ValueError): ms.parse_county_links(raw + raw)

    def test_calendar_layout_or_edition_change_requires_review(self):
        with self.assertRaises(ValueError): ms.parse_calendar('old calendar December 3')
        with self.assertRaises(ValueError): ms.parse_calendar(CALENDAR.replace('DECEMBER', 'OCTOBER'))

if __name__ == '__main__': unittest.main()
