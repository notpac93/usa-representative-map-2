#!/usr/bin/env node
/**
 * checkCityPopulations.cjs
 *
 * Quick verification tool that cross-references the generated cities overlay
 * against the Census sub-estimate CSVs to ensure each state's largest places
 * are present with the expected population values.
 *
 * Usage examples:
 *   node scripts/checkCityPopulations.cjs
 *   node scripts/checkCityPopulations.cjs --states CA,FL,TX --top 10
 */

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const options = {};
for (let i = 0; i < args.length; i += 1) {
  if (args[i].startsWith('--')) {
    const key = args[i].slice(2);
    const value = args[i + 1] && !args[i + 1].startsWith('--') ? args[i + 1] : true;
    options[key] = value;
    if (value !== true) i += 1;
  }
}

const STATE_FIPS = [
  ['01', 'AL'], ['02', 'AK'], ['04', 'AZ'], ['05', 'AR'], ['06', 'CA'], ['08', 'CO'], ['09', 'CT'],
  ['10', 'DE'], ['11', 'DC'], ['12', 'FL'], ['13', 'GA'], ['15', 'HI'], ['16', 'ID'], ['17', 'IL'],
  ['18', 'IN'], ['19', 'IA'], ['20', 'KS'], ['21', 'KY'], ['22', 'LA'], ['23', 'ME'], ['24', 'MD'],
  ['25', 'MA'], ['26', 'MI'], ['27', 'MN'], ['28', 'MS'], ['29', 'MO'], ['30', 'MT'], ['31', 'NE'],
  ['32', 'NV'], ['33', 'NH'], ['34', 'NJ'], ['35', 'NM'], ['36', 'NY'], ['37', 'NC'], ['38', 'ND'],
  ['39', 'OH'], ['40', 'OK'], ['41', 'OR'], ['42', 'PA'], ['44', 'RI'], ['45', 'SC'], ['46', 'SD'],
  ['47', 'TN'], ['48', 'TX'], ['49', 'UT'], ['50', 'VT'], ['51', 'VA'], ['53', 'WA'], ['54', 'WV'],
  ['55', 'WI'], ['56', 'WY'],
];
const fipsToAbbr = new Map(STATE_FIPS);

function loadCitiesLayer(layerPath = 'data/overlays/cities.generated.ts') {
  const raw = fs.readFileSync(layerPath, 'utf8');
  const match = raw.match(/export const citiesLayer: CityLayer = ([\s\S]*?);\nexport default/);
  if (!match) throw new Error(`Unable to parse CityLayer payload in ${layerPath}`);
  const layerJson = JSON.parse(match[1]);
  return layerJson.features;
}

function loadPopulationRecords(dir = 'data/raw/census-csv') {
  const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.csv')) : [];
  if (!files.length) {
    throw new Error(`No population CSV files found in ${dir}`);
  }
  const records = [];
  for (const file of files) {
    const rows = fs.readFileSync(path.join(dir, file), 'utf8').trim().split(/\r?\n/);
    if (!rows.length) continue;
    const header = rows[0].split(',');
    const idx = (regex) => header.findIndex((h) => regex.test(h));
    const sumlevIdx = idx(/^SUMLEV$/i);
    const stateIdx = idx(/^STATE$/i);
    const placeIdx = idx(/^PLACE$/i);
    const nameIdx = idx(/^NAME$/i);
    const popIdx = idx(/POPESTIMATE2024/i);
    if ([sumlevIdx, stateIdx, placeIdx, nameIdx, popIdx].some((i) => i === -1)) continue;
    for (let i = 1; i < rows.length; i += 1) {
      const parts = rows[i].split(',');
      if (parts.length <= popIdx) continue;
      const sumlev = (parts[sumlevIdx] || '').trim();
      if (sumlev !== '162') continue; // incorporated places only
      const state = (parts[stateIdx] || '').trim().padStart(2, '0');
      const place = (parts[placeIdx] || '').trim().padStart(5, '0');
      const name = (parts[nameIdx] || '').trim();
      const pop = Number(parts[popIdx]);
      if (!state || !place || !name || Number.isNaN(pop)) continue;
      records.push({ id: state + place, state, stateAbbr: fipsToAbbr.get(state) || state, name, population: pop });
    }
  }
  return records;
}

function groupTopPlaces(records, top = 5, onlyStates = null) {
  const grouped = new Map();
  for (const rec of records) {
    if (onlyStates && !onlyStates.has(rec.stateAbbr)) continue;
    if (!grouped.has(rec.stateAbbr)) grouped.set(rec.stateAbbr, []);
    grouped.get(rec.stateAbbr).push(rec);
  }
  for (const recs of grouped.values()) {
    recs.sort((a, b) => b.population - a.population);
    while (recs.length > top) recs.pop();
  }
  return grouped;
}

function main() {
  const targetStates = typeof options.states === 'string'
    ? new Set(options.states.split(',').map((s) => s.trim().toUpperCase()).filter(Boolean))
    : null;
  const topN = options.top ? Number(options.top) : 5;
  const tolerance = options.tolerance ? Number(options.tolerance) : 0; // default exact match

  const features = loadCitiesLayer();
  const featureById = new Map(features.map((f) => [String(f.id), f]));
  const populationRecords = loadPopulationRecords();
  const grouped = groupTopPlaces(populationRecords, topN, targetStates);

  let issues = 0;
  for (const [stateAbbr, recs] of grouped.entries()) {
    console.log(`\nState ${stateAbbr} — top ${recs.length} incorporated places`);
    for (const rec of recs) {
      const feature = featureById.get(rec.id);
      if (!feature) {
        issues += 1;
        console.log(`  ✗ Missing ${rec.name} (#${rec.id}) expected pop ${rec.population.toLocaleString()}`);
        continue;
      }
      const diff = Math.abs((feature.population || 0) - rec.population);
      if (diff > tolerance) {
        issues += 1;
        console.log(
          `  ⚠ Population mismatch ${rec.name}: overlay ${feature.population?.toLocaleString?.() || feature.population} vs ${rec.population.toLocaleString()} (Δ=${diff.toLocaleString()})`,
        );
      } else {
        console.log(`  ✓ ${rec.name} — ${rec.population.toLocaleString()} (id ${rec.id})`);
      }
    }
  }

  if (!grouped.size) {
    console.warn('No states matched the requested filters.');
  }
  if (issues > 0) {
    console.error(`\nDetected ${issues} issue(s).`);
    process.exitCode = 1;
  } else {
    console.log('\nAll checked cities match the overlay populations.');
  }
}

main();
