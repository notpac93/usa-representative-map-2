#!/usr/bin/env node
/**
 * verifyCitiesCompleteness.cjs
 *
 * Compare the generated cities overlay against the underlying TIGER/Line or Gazetteer source
 * to highlight coverage gaps. Outputs a summary to stdout and (optionally) a JSON report file.
 *
 * Example usages:
 *   node scripts/verifyCitiesCompleteness.cjs \
 *     --overlay data/overlays/cities.generated.ts \
 *     --source data/raw/places/2025_Gaz_place_national.txt \
 *     --minpop 50000
 *
 *   node scripts/verifyCitiesCompleteness.cjs \
 *     --overlay data/overlays/cities.generated.ts \
 *     --source data/raw/tl_2023_us_place/tl_2023_us_place.shp \
 *     --minpop 50000 --report tmp/city-gap-report.json
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

const STATE_INFO = [
  ['01', 'AL', 'Alabama'],
  ['02', 'AK', 'Alaska'],
  ['04', 'AZ', 'Arizona'],
  ['05', 'AR', 'Arkansas'],
  ['06', 'CA', 'California'],
  ['08', 'CO', 'Colorado'],
  ['09', 'CT', 'Connecticut'],
  ['10', 'DE', 'Delaware'],
  ['11', 'DC', 'District of Columbia'],
  ['12', 'FL', 'Florida'],
  ['13', 'GA', 'Georgia'],
  ['15', 'HI', 'Hawaii'],
  ['16', 'ID', 'Idaho'],
  ['17', 'IL', 'Illinois'],
  ['18', 'IN', 'Indiana'],
  ['19', 'IA', 'Iowa'],
  ['20', 'KS', 'Kansas'],
  ['21', 'KY', 'Kentucky'],
  ['22', 'LA', 'Louisiana'],
  ['23', 'ME', 'Maine'],
  ['24', 'MD', 'Maryland'],
  ['25', 'MA', 'Massachusetts'],
  ['26', 'MI', 'Michigan'],
  ['27', 'MN', 'Minnesota'],
  ['28', 'MS', 'Mississippi'],
  ['29', 'MO', 'Missouri'],
  ['30', 'MT', 'Montana'],
  ['31', 'NE', 'Nebraska'],
  ['32', 'NV', 'Nevada'],
  ['33', 'NH', 'New Hampshire'],
  ['34', 'NJ', 'New Jersey'],
  ['35', 'NM', 'New Mexico'],
  ['36', 'NY', 'New York'],
  ['37', 'NC', 'North Carolina'],
  ['38', 'ND', 'North Dakota'],
  ['39', 'OH', 'Ohio'],
  ['40', 'OK', 'Oklahoma'],
  ['41', 'OR', 'Oregon'],
  ['42', 'PA', 'Pennsylvania'],
  ['44', 'RI', 'Rhode Island'],
  ['45', 'SC', 'South Carolina'],
  ['46', 'SD', 'South Dakota'],
  ['47', 'TN', 'Tennessee'],
  ['48', 'TX', 'Texas'],
  ['49', 'UT', 'Utah'],
  ['50', 'VT', 'Vermont'],
  ['51', 'VA', 'Virginia'],
  ['53', 'WA', 'Washington'],
  ['54', 'WV', 'West Virginia'],
  ['55', 'WI', 'Wisconsin'],
  ['56', 'WY', 'Wyoming'],
  ['60', 'AS', 'American Samoa'],
  ['66', 'GU', 'Guam'],
  ['69', 'MP', 'Northern Mariana Islands'],
  ['72', 'PR', 'Puerto Rico'],
  ['78', 'VI', 'U.S. Virgin Islands']
];

const FIPS_TO_ABBR = STATE_INFO.reduce((acc, [fips, abbr]) => {
  acc[fips] = abbr;
  return acc;
}, {});

const STATE_ABBR_TO_NAME = new Map(STATE_INFO.map(([fips, abbr, name]) => [abbr, name]));

function runCityCoverage(options = {}) {
  const overlayPath = options.overlay || 'data/overlays/cities.generated.ts';
  const sourcePath = options.source || options.input || options.tiger || guessDefaultSource();
  const minPop = typeof options.minPop === 'number'
    ? options.minPop
    : Number(options.minpop || options.minPopulation || 0);
  const funcstatFilter = options.funcstatFilter || parseFuncStat(options.funcstat || options.status);
  const popMap = options.popMap || loadPopulationMap(options.popcsv);

  ensureFileExists(overlayPath, 'Overlay file not found');
  if (!sourcePath) {
    throw new Error('Missing --source (shapefile, GeoJSON, or Gazetteer .txt)');
  }
  ensureFileExists(sourcePath, 'Source dataset not found');

  if (minPop > 0 && !popMap && !options.silent) {
    console.warn('[verifyCities] No population CSV detected; minpop filter will be skipped.');
  }

  const overlay = loadOverlayLayer(overlayPath);
  const sourceRecords = loadSourceRecords(sourcePath, { funcstatFilter, popMap });
  const filteredSource = minPop > 0 && popMap
    ? sourceRecords.filter(rec => (rec.population || 0) >= minPop)
    : sourceRecords;

  const summary = compareDatasets(overlay, filteredSource);
  summary.sourcePath = path.relative(process.cwd(), sourcePath);
  summary.overlayPath = path.relative(process.cwd(), overlayPath);
  summary.minPopulation = minPop;
  summary.funcstatFilter = funcstatFilter && funcstatFilter.size ? Array.from(funcstatFilter).join(',') : 'all';
  summary.populationRows = popMap ? popMap.size : 0;
  return summary;
}

if (require.main === module) {
  const args = parseArgs(process.argv.slice(2));
  try {
    const summary = runCityCoverage(args);
    printSummary(summary);
    if (args.report) {
      fs.mkdirSync(path.dirname(args.report), { recursive: true });
      fs.writeFileSync(args.report, JSON.stringify(summary, null, 2));
      console.log(`\nDetailed JSON report written to ${args.report}`);
    }
  } catch (err) {
    console.error(err?.message || err);
    process.exit(1);
  }
}

function parseArgs(list) {
  const parsed = {};
  for (let i = 0; i < list.length; i++) {
    const token = list[i];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const next = list[i + 1];
    if (next && !next.startsWith('--')) {
      parsed[key] = next;
      i++;
    } else {
      parsed[key] = true;
    }
  }
  return parsed;
}

function parseFuncStat(value) {
  if (!value) return null;
  const entries = value.split(',').map(v => v.trim().toUpperCase()).filter(Boolean);
  if (!entries.length) return null;
  return new Set(entries);
}

function guessDefaultSource() {
  const candidate = path.join('data', 'raw', 'places', '2025_Gaz_place_national.txt');
  if (fs.existsSync(candidate)) return candidate;
  return null;
}

function ensureFileExists(file, message) {
  if (!fs.existsSync(file)) {
    throw new Error(`${message}: ${file}`);
  }
}

function loadOverlayLayer(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  const marker = 'export const citiesLayer';
  const idx = raw.indexOf(marker);
  if (idx === -1) {
    throw new Error('Unable to locate citiesLayer export in overlay file.');
  }
  const braceIdx = raw.indexOf('{', idx);
  if (braceIdx === -1) {
    throw new Error('Malformed overlay file; missing opening brace.');
  }
  const endMarkerIdx = raw.indexOf('\nexport default', braceIdx);
  if (endMarkerIdx === -1) {
    throw new Error('Malformed overlay file; missing "export default" boundary.');
  }
  let jsonSlice = raw.slice(braceIdx, endMarkerIdx).trim();
  if (jsonSlice.endsWith(';')) jsonSlice = jsonSlice.slice(0, -1);
  try {
    return JSON.parse(jsonSlice);
  } catch (err) {
    throw new Error(`Failed to parse overlay JSON: ${err.message}`);
  }
}

function loadSourceRecords(sourceFile, options) {
  const ext = path.extname(sourceFile).toLowerCase();
  if (ext === '.txt' || ext === '.csv') {
    return parseGazetteer(sourceFile, options);
  }
  if (ext === '.json' || ext === '.geojson') {
    return parseGeoJson(fs.readFileSync(sourceFile, 'utf8'), options);
  }
  if (ext === '.shp') {
    const geojson = convertShapefileToGeoJson(sourceFile);
    return parseGeoJson(geojson, options);
  }
  throw new Error(`Unsupported source format (expected .txt, .csv, .shp, or .geojson): ${sourceFile}`);
}

function parseGazetteer(filePath, options = {}) {
  const rawLines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/).filter(Boolean);
  if (!rawLines.length) {
    throw new Error('Gazetteer file is empty');
  }
  const headers = rawLines[0].split('|');
  const idx = headerName => headers.findIndex(h => h.trim().toUpperCase() === headerName.toUpperCase());
  const getIdx = (candidates, required = false) => {
    for (const name of candidates) {
      const position = idx(name);
      if (position !== -1) return position;
    }
    if (required) {
      throw new Error(`Required column missing from Gazetteer: ${candidates.join('/')}`);
    }
    return -1;
  };

  const uspsIdx = getIdx(['USPS'], true);
  const geoidIdx = getIdx(['GEOID', 'GEOIDFQ'], true);
  const nameIdx = getIdx(['NAME', 'NAMELSAD'], true);
  const funcIdx = getIdx(['FUNCSTAT']);

  const records = [];
  for (let i = 1; i < rawLines.length; i++) {
    const cols = rawLines[i].split('|');
    if (!cols.length || !cols[geoidIdx]) continue;
    if (options.funcstatFilter && funcIdx !== -1) {
      const stat = (cols[funcIdx] || '').trim().toUpperCase();
      if (!options.funcstatFilter.has(stat)) continue;
    }
    records.push({
      id: cols[geoidIdx].trim(),
      name: cols[nameIdx]?.trim() || 'Place',
      stateAbbr: cols[uspsIdx]?.trim().toUpperCase() || null,
      stateName: STATE_ABBR_TO_NAME.get(cols[uspsIdx]?.trim().toUpperCase() || '') || null,
      population: options.popMap ? options.popMap.get(cols[geoidIdx].trim()) || null : null
    });
  }
  return records;
}

function parseGeoJson(input, options = {}) {
  const data = typeof input === 'string' ? JSON.parse(input) : input;
  if (!data || !Array.isArray(data.features)) {
    throw new Error('GeoJSON is missing a features array.');
  }
  return data.features.map(feature => {
    const props = feature.properties || {};
    const geoid = props.GEOID || props.GEOID10 || buildGeoid(props.STATEFP, props.PLACEFP);
    const stateFips = pad(props.STATEFP, 2) || (geoid ? geoid.slice(0, 2) : null);
    const stateAbbr = (props.USPS || props.STATE || (stateFips ? FIPS_TO_ABBR[stateFips] : null)) || null;
    const stateName = props.STNAME || props.STATE_NAME || (stateAbbr ? STATE_ABBR_TO_NAME.get(stateAbbr) : null) || null;
    const funcStat = (props.FUNCSTAT || props.FUNCSTATI || '').toString().trim().toUpperCase();
    if (options.funcstatFilter && funcStat) {
      if (!options.funcstatFilter.has(funcStat)) {
        return null;
      }
    }
    return {
      id: geoid || props.PLACEFP || props.ANSICODE || props.GNISID || null,
      name: props.NAMELSAD || props.NAME || props.FULLNAME || 'Place',
      stateAbbr,
      stateName,
      population: options.popMap ? options.popMap.get(geoid || '') || null : null
    };
  }).filter(Boolean);
}

function convertShapefileToGeoJson(shpPath) {
  const tmpOut = path.join(os.tmpdir(), `verify_cities_${Date.now()}_${Math.random().toString(16).slice(2)}.geojson`);
  const cmd = `npx mapshaper -quiet -i "${shpPath}" -o format=geojson precision=0.0001 ${tmpOut}`;
  try {
    execSync(cmd, { stdio: 'inherit' });
    const geojson = fs.readFileSync(tmpOut, 'utf8');
    fs.unlinkSync(tmpOut);
    return geojson;
  } catch (err) {
    console.error('Failed to convert shapefile via mapshaper:', err.message);
    if (fs.existsSync(tmpOut)) fs.unlinkSync(tmpOut);
    throw err;
  }
}

function compareDatasets(overlayLayer, sourceRecords) {
  const overlayFeatures = Array.isArray(overlayLayer?.features) ? overlayLayer.features : [];
  const overlayIds = new Map();
  const overlayMissingIds = [];
  overlayFeatures.forEach(feature => {
    const normId = normalizeId(feature.id);
    if (!normId) {
      overlayMissingIds.push(feature);
      return;
    }
    overlayIds.set(normId, feature);
  });

  const buckets = new Map();
  const missing = [];
  const seenSourceIds = new Set();
  const sourceIds = new Set();
  let covered = 0;
  let duplicates = 0;

  sourceRecords.forEach(rec => {
    const normId = normalizeId(rec.id);
    if (!normId) return;
    if (seenSourceIds.has(normId)) {
      duplicates++;
      return;
    }
    seenSourceIds.add(normId);
    sourceIds.add(normId);
    const stateKey = (rec.stateAbbr || 'Unknown').toUpperCase();
    const bucket = getBucket(buckets, stateKey, rec.stateName);
    bucket.source++;
    if (overlayIds.has(normId)) {
      covered++;
      bucket.covered++;
    } else {
      bucket.missing.push(rec);
      missing.push(rec);
    }
  });

  const overlayExtras = [];
  for (const [id, feature] of overlayIds.entries()) {
    if (!sourceIds.has(id)) {
      overlayExtras.push({ id, name: feature.name });
    }
  }

  const perState = Array.from(buckets.values()).map(bucket => ({
    state: bucket.state,
    stateName: bucket.stateName,
    source: bucket.source,
    covered: bucket.covered,
    coverage: bucket.source ? bucket.covered / bucket.source : 0,
    missingExamples: bucket.missing.slice(0, 5).map(r => r.name)
  })).sort((a, b) => a.coverage - b.coverage);

  const topMissing = missing
    .slice()
    .sort((a, b) => (b.population || 0) - (a.population || 0))
    .slice(0, 20);

  return {
    overlayFeatureCount: overlayFeatures.length,
    overlayFeaturesWithIds: overlayIds.size,
    overlayFeaturesMissingIds: overlayMissingIds.length,
    sourceFeatureCount: seenSourceIds.size,
    coverageRatio: seenSourceIds.size ? covered / seenSourceIds.size : 0,
    coveredCount: covered,
    duplicateSourceIdsSkipped: duplicates,
    missingCount: missing.length,
    overlayOrphans: overlayExtras,
    perState,
    topMissing,
    overlayMissingIds: overlayMissingIds.map(f => f.name).slice(0, 20)
  };
}

function getBucket(map, stateAbbr, fallbackName) {
  if (!map.has(stateAbbr)) {
    const stateName = fallbackName || STATE_ABBR_TO_NAME.get(stateAbbr) || stateAbbr;
    map.set(stateAbbr, { state: stateAbbr, stateName, source: 0, covered: 0, missing: [] });
  }
  return map.get(stateAbbr);
}

function normalizeId(value) {
  if (value === null || value === undefined) return null;
  const str = String(value).trim();
  if (!str) return null;
  return /^\d+$/.test(str) ? str.padStart(7, '0') : str;
}

function buildGeoid(stateFp, placeFp) {
  if (!stateFp || !placeFp) return null;
  return pad(stateFp, 2) + pad(placeFp, 5);
}

function pad(value, length) {
  if (value === null || value === undefined) return null;
  const str = String(value).trim();
  if (!str) return null;
  return str.padStart(length, '0');
}

function loadPopulationMap(customPath) {
  const directory = path.join('data', 'raw', 'census-csv');
  const popMap = new Map();
  if (customPath && fs.existsSync(customPath)) {
    ingestPopulationFile(customPath, popMap);
    return popMap;
  }
  if (fs.existsSync(directory)) {
    const files = fs.readdirSync(directory).filter(name => name.toLowerCase().endsWith('.csv'));
    files.forEach(file => ingestPopulationFile(path.join(directory, file), popMap));
  }
  return popMap.size ? popMap : null;
}

function ingestPopulationFile(filePath, popMap) {
  try {
    const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/).filter(Boolean);
    if (!lines.length) return;
    const header = lines[0].split(',');
    const geoidIdx = header.findIndex(h => /GEOID/i.test(h));
    const stateIdx = header.findIndex(h => /^STATE/i.test(h));
    const placeIdx = header.findIndex(h => /^PLACE/i.test(h));
    const nameIdx = header.findIndex(h => /^NAME/i.test(h));
    const stNameIdx = header.findIndex(h => /^STNAME/i.test(h));
    const popIdx = header.findIndex(h => /POPESTIMATE|POP/i.test(h));
    if (popIdx === -1) return;
    for (let i = 1; i < lines.length; i++) {
      const cols = lines[i].split(',');
      const key = geoidIdx !== -1
        ? cols[geoidIdx]
        : stateIdx !== -1 && placeIdx !== -1
          ? pad(cols[stateIdx], 2) + pad(cols[placeIdx], 5)
          : stNameIdx !== -1 && nameIdx !== -1
            ? `${cols[stNameIdx]}-${cols[nameIdx]}`
            : null;
      const value = Number(cols[popIdx]);
      if (key && !Number.isNaN(value)) {
        popMap.set(key.trim(), value);
      }
    }
  } catch (err) {
    console.warn('Failed to ingest population CSV', filePath, err.message);
  }
}

function printSummary(summary) {
  const pct = (summary.coverageRatio * 100).toFixed(2);
  console.log('=== City Coverage Summary ===');
  console.log(`Overlay entries: ${summary.overlayFeatureCount} (IDs present: ${summary.overlayFeaturesWithIds}, missing IDs: ${summary.overlayFeaturesMissingIds})`);
  console.log(`Source entries (after filters): ${summary.sourceFeatureCount}`);
  console.log(`Matched entries: ${summary.coveredCount}`);
  console.log(`Coverage: ${pct}%`);
  if (summary.duplicateSourceIdsSkipped) {
    console.log(`Skipped ${summary.duplicateSourceIdsSkipped} duplicate GEOIDs in the source dataset.`);
  }
  if (summary.overlayOrphans.length) {
    console.log(`Overlay entries without a matching source record: ${summary.overlayOrphans.length}`);
  }
  console.log('\nLowest coverage states:');
  summary.perState.slice(0, 10).forEach(state => {
    const statePct = state.coverage * 100;
    console.log(`  ${state.state} (${state.source} places): ${statePct.toFixed(1)}% covered`);
    if (state.missingExamples.length) {
      console.log('    Missing examples:', state.missingExamples.join(', '));
    }
  });

  if (summary.topMissing.length) {
    console.log('\nLargest missing places by population:');
    summary.topMissing.forEach((item, idx) => {
      const pop = item.population ? item.population.toLocaleString('en-US') : 'n/a';
      console.log(`  ${idx + 1}. ${item.name} (${item.stateAbbr || item.stateName || '??'}) - population ${pop}`);
    });
  }
}

module.exports = {
  runCityCoverage,
  printSummary,
  parseFuncStat,
};

