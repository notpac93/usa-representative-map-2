"""Refresh state indicators using only HTTPS census.gov, bea.gov and bls.gov.

No keys required. Run from any directory; output replacement is atomic and only
occurs after all 50 states + DC pass validation. Uses annual ACS 1-year tables,
annual BEA GDP, and monthly seasonally adjusted BLS LAUS unemployment rates.
"""
import concurrent.futures
import csv
import io
import json
import math
import re
import urllib.parse
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'assets/data/government_indicators.json'
AGENCIES = ('census.gov', 'bea.gov', 'bls.gov')


def verify_url(url):
    p = urllib.parse.urlsplit(url)
    if p.scheme != 'https' or not any(p.hostname == d or (p.hostname or '').endswith('.' + d) for d in AGENCIES):
        raise ValueError('Source must be an approved government HTTPS URL')


class GovRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        verify_url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch(url, payload=None):
    verify_url(url)
    req = urllib.request.Request(url, data=None if payload is None else json.dumps(payload).encode(),
        headers={'User-Agent': 'CivicIndicators/1.0', 'Content-Type': 'application/json'})
    with urllib.request.build_opener(GovRedirects()).open(req, timeout=60) as response:
        verify_url(response.url)
        return response.read()


def number(raw):
    try:
        value = float(str(raw).strip().replace(',', ''))
        return value if 0 <= value < 1e15 else None  # Reject Census sentinel values.
    except (ValueError, TypeError):
        return None


def acs_rows(content):
    return {r['GEO_ID'][-2:]: r for r in csv.DictReader(io.StringIO(content.decode('utf-8-sig')), delimiter='|')
            if re.fullmatch(r'0400000US\d{2}', r.get('GEO_ID', ''))}


def add_acs_history(states, by_fips, year, tables):
    for table, name in [('B19013', 'income'), ('B25064', 'rent'), ('B25077', 'homeValue'), ('B25003', 'homeownership')]:
        for geo, row in acs_rows(tables[table]).items():
            if geo not in by_fips:
                continue
            metric = states[by_fips[geo]][name]
            if name == 'homeownership':
                total, owners = number(row['B25003_E001']), number(row['B25003_E002'])
                value = None if not total or owners is None else owners / total * 100
            else:
                value = number(row[f'{table}_E001'])
            if value is not None:
                metric.setdefault('history', {})[str(year)] = value
                if name != 'homeownership':
                    metric.setdefault('historyMarginsOfError', {})[str(year)] = number(row[f'{table}_M001'])


def validate(output):
    for code in output['requiredStates']:
        state = output['states'].get(code, {})
        for name in ['income', 'rent', 'homeValue', 'homeownership', 'gdp', 'realGdpGrowth', 'unemployment']:
            metric = state.get(name)
            if not metric or metric['value'] is None:
                raise ValueError(f'Missing {name} for {code}; retaining previous output')
            if metric['unit'] == 'percent' and not 0 <= metric['value'] <= 100:
                raise ValueError(f'Invalid percentage for {code}')
            if name in ['income', 'rent', 'homeValue', 'homeownership', 'gdp', 'unemployment']:
                history = metric.get('history', {})
                if len(history) < 2 or not math.isclose(history.get(metric['period'], -1), metric['value'], rel_tol=1e-12):
                    raise ValueError(f'Invalid or incomplete {name} history for {code}')
                if any(number(v) is None for v in history.values()):
                    raise ValueError(f'Invalid historical value for {code}')
            for url in output['sources'][metric['source']]['urls']:
                verify_url(url)


def refresh():
    now = datetime.now(timezone.utc)
    fips = dict(re.findall(r"'([A-Z]{2})': '(\d{2})'", (ROOT / 'lib/utils/fips_mapping.dart').read_text()))
    by_fips = {v: k for k, v in fips.items()}
    output = {'schemaVersion': 1, 'refreshedAt': now.isoformat(), 'requiredStates': sorted(fips),
              'sources': {}, 'states': {s: {} for s in fips}}
    # Discover the latest released annual ACS summary tables, not an assumed year.
    year = None
    for candidate in range(now.year - 1, now.year - 4, -1):
        url = f'https://www2.census.gov/programs-surveys/acs/summary_file/{candidate}/table-based-SF/data/1YRData/'
        try:
            if f'acsdt1y{candidate}-b19013.dat' in fetch(url).decode():
                year = candidate
                break
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise
    if year is None:
        raise ValueError('No recent ACS release found')
    tables = ['B19013', 'B25064', 'B25077', 'B25003']
    urls = {table: f'https://www2.census.gov/programs-surveys/acs/summary_file/{year}/table-based-SF/data/1YRData/acsdt1y{year}-{table.lower()}.dat' for table in tables}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        contents = dict(zip(tables, pool.map(fetch, urls.values())))
    parsed = {t: acs_rows(b) for t, b in contents.items()}
    output['sources']['acs'] = {'agency': 'U.S. Census Bureau', 'dataset': f'{year} ACS 1-year estimates',
        'urls': list(urls.values()), 'retrievedAt': now.isoformat(),
        'notes': f'Income, rent, and home value in {year} dollars. Income and housing medians are survey estimates with 90% margins of error. Homeownership is owner-occupied / occupied housing units; a derived rate, not a separately published estimate.'}
    for table, metric in [('B19013', 'income'), ('B25064', 'rent'), ('B25077', 'homeValue')]:
        for geo, row in parsed[table].items():
            if geo in by_fips:
                output['states'][by_fips[geo]][metric] = {'value': number(row[f'{table}_E001']),
                    'marginOfError': number(row[f'{table}_M001']), 'period': str(year), 'unit': 'USD', 'source': 'acs', 'table': table}
    for geo, row in parsed['B25003'].items():
        if geo in by_fips:
            total, owners = number(row['B25003_E001']), number(row['B25003_E002'])
            output['states'][by_fips[geo]]['homeownership'] = {'value': None if not total or owners is None else 100 * owners / total,
                'period': str(year), 'unit': 'percent', 'source': 'acs', 'table': 'B25003', 'numerator': owners, 'denominator': total}

    add_acs_history(output['states'], by_fips, year, contents)
    historical_years = [y for y in range(max(2021, year - 4), year) if y != 2020]
    historical_urls = [(y, t, f'https://www2.census.gov/programs-surveys/acs/summary_file/{y}/table-based-SF/data/1YRData/acsdt1y{y}-{t.lower()}.dat') for y in historical_years for t in tables]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        historical_files = list(pool.map(fetch, [u for _, _, u in historical_urls]))
    for y in historical_years:
        add_acs_history(output['states'], by_fips, y, {t: content for (yy, t, _), content in zip(historical_urls, historical_files) if yy == y})
    output['sources']['acs']['urls'] += [u for _, _, u in historical_urls]
    output['sources']['acs']['dataset'] = f'{historical_years[0] if historical_years else year}–{year} ACS 1-year estimates'
    output['sources']['acs']['notes'] += ' History uses each reporting year’s dollars, not inflation-adjusted change. Differences have not been tested for statistical significance. Standard 2020 ACS 1-year estimates are excluded.'

    url = 'https://apps.bea.gov/regional/zip/SAGDP.zip'
    archive = zipfile.ZipFile(io.BytesIO(fetch(url)))
    file = next(n for n in archive.namelist() if re.fullmatch(r'SAGDP1__ALL_AREAS_\d{4}_\d{4}.csv', n))
    rows = csv.DictReader(io.StringIO(archive.read(file).decode('utf-8-sig')), skipinitialspace=True)
    output['sources']['bea'] = {'agency': 'Bureau of Economic Analysis', 'dataset': 'SAGDP1 annual GDP summary',
        'urls': [url], 'file': file, 'retrievedAt': now.isoformat(),
        'notes': 'GDP is current-dollar annual GDP. Real growth is calculated from annual real GDP in chained 2017 dollars. Previously published estimates may be revised.'}
    for row in rows:
        geo = row['GeoFIPS'].strip()
        if not geo.endswith('000') or geo[:2] not in by_fips or row['LineCode'].strip() not in ('1', '3'):
            continue
        history = {y: number(v) for y, v in row.items() if y and y.isdigit() and number(v) is not None}
        years = sorted(history)
        if len(years) < 2:
            continue
        latest, previous = years[-1], years[-2]
        if row['LineCode'].strip() == '3':
            metric = {'value': history[latest] * 1e6, 'period': latest, 'unit': 'USD', 'source': 'bea',
                'history': {y: history[y] * 1e6 for y in years[-10:]}}
            output['states'][by_fips[geo[:2]]]['gdp'] = metric
        else:
            output['states'][by_fips[geo[:2]]]['realGdpGrowth'] = {'value': (history[latest] / history[previous] - 1) * 100,
                'period': f'{previous}–{latest}', 'unit': 'percentChange', 'source': 'bea'}

    url = 'https://api.bls.gov/publicAPI/v2/timeseries/data/'
    output['sources']['bls'] = {'agency': 'Bureau of Labor Statistics', 'dataset': 'LAUS state unemployment rates',
        'urls': [url], 'retrievedAt': now.isoformat(), 'notes': 'Monthly seasonally adjusted unemployment rate. Latest observations may be preliminary and subject to revision.'}
    ids = {f'LASST{geo}0000000000003': code for code, geo in fips.items()}
    series_ids = list(ids)
    for start in range(0, len(series_ids), 20):
        result = json.loads(fetch(url, {'seriesid': series_ids[start:start + 20], 'startyear': str(now.year - 1), 'endyear': str(now.year)}))
        if result.get('status') != 'REQUEST_SUCCEEDED':
            raise ValueError('BLS refresh failed; retaining previous output')
        for series in result['Results']['series']:
            valid = [r for r in series['data'] if re.fullmatch(r'M(0[1-9]|1[0-2])', r['period']) and number(r['value']) is not None]
            if not valid:
                continue
            valid.sort(key=lambda r: (r['year'], r['period']))
            last = valid[-1]
            output['states'][ids[series['seriesID']]]['unemployment'] = {'value': number(last['value']),
                'period': f"{last['year']}-{last['period'][1:]}", 'unit': 'percent', 'source': 'bls', 'seriesId': series['seriesID'],
                'footnotes': [f['text'] for f in last['footnotes'] if f.get('text')],
                'history': {f"{r['year']}-{r['period'][1:]}": number(r['value']) for r in valid}}
    validate(output)
    temp = OUTPUT.with_suffix('.tmp')
    temp.write_text(json.dumps(output, indent=2, allow_nan=False) + '\n')
    temp.replace(OUTPUT)
    print(f'Refreshed seven indicators for {len(output["states"])} states/DC. ACS {year}; government HTTPS sources only.')


if __name__ == '__main__':
    refresh()
