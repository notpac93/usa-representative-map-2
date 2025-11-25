#!/usr/bin/env node
/**
 * processTigerLayer.cjs
 * Helper to convert downloaded TIGER county datasets into simplified GeoJSON chunks
 * that we can later stitch into overlays.
 *
 * Usage:
 *   node scripts/processTigerLayer.cjs \
 *     --folder ROADS \
 *     --counties 01001,01003 \
 *     --simplify 8 \
 *     --out data/overlays/tiger/roads
 *
 * Env vars respected by downloadTiger2025.cjs (TIGER_FOLDERS, TIGER_ONLY) ensure the
 * source `.shp` files already exist under data/raw/tiger2025/<FOLDER>/tl_2025_<fips>_<suffix>.shp.
 */

const fs = require('node:fs');
const path = require('node:path');
const { execSync } = require('node:child_process');

const argPairs = process.argv.slice(2);
const args = {};
for (let i = 0; i < argPairs.length; i += 1) {
  const key = argPairs[i];
  if (!key.startsWith('--')) continue;
  const value = argPairs[i + 1] && !argPairs[i + 1].startsWith('--') ? argPairs[i + 1] : true;
  args[key.slice(2)] = value;
}

const folder = (args.folder || args.layer || '').toUpperCase();
if (!folder) {
  console.error('Missing --folder (e.g., ROADS, AREAWATER, COUNTY).');
  process.exit(1);
}
const countyFilter = args.counties ? String(args.counties).split(',').map((c) => c.trim()).filter(Boolean) : null;
const simplify = Number(args.simplify || 12);
const outputDir = args.out || path.join('data', 'overlays', 'tiger', folder.toLowerCase());
const sourceRoot = path.join('data', 'raw', 'tiger2025', folder);

if (!fs.existsSync(sourceRoot)) {
  console.error('Source folder not found:', sourceRoot);
  process.exit(1);
}
fs.mkdirSync(outputDir, { recursive: true });

const entries = fs.readdirSync(sourceRoot).filter((entry) => entry.startsWith('tl_'));
if (!entries.length) {
  console.warn('No tl_* folders located under', sourceRoot);
  process.exit(0);
}

const targets = entries.filter((entry) => {
  if (!countyFilter) return true;
  const match = entry.match(/tl_\d{4}_(\d{5})_/i);
  if (!match) return false;
  return countyFilter.includes(match[1]);
});

if (!targets.length) {
  console.warn('No folders matched the requested counties.');
  process.exit(0);
}

const runMapshaper = (shpPath, outPath) => {
  const cmd = `npx mapshaper -quiet -i "${shpPath}" -simplify visvalingam ${simplify}% keep-shapes -o format=geojson precision=0.0001 "${outPath}"`;
  execSync(cmd, { stdio: 'inherit' });
};

let processed = 0;
let skipped = 0;

for (const folderName of targets) {
  const baseName = folderName.replace(/\/$/, '');
  const datasetPath = path.join(sourceRoot, baseName);
  const shpCandidates = fs.readdirSync(datasetPath).filter((f) => f.endsWith('.shp'));
  if (!shpCandidates.length) {
    console.warn('⚠︎ No shapefile found in', datasetPath);
    skipped += 1;
    continue;
  }
  const shpName = shpCandidates[0];
  const shpPath = path.join(datasetPath, shpName);
  const countyIdMatch = shpName.match(/tl_\d{4}_(\d{5})_/i);
  const countyId = countyIdMatch ? countyIdMatch[1] : baseName;
  const outPath = path.join(outputDir, `${countyId}.geojson`);
  if (fs.existsSync(outPath) && !args.force) {
    console.log(`✓ ${countyId} already converted (${outPath})`);
    skipped += 1;
    continue;
  }
  console.log(`→ Converting ${folder}/${countyId}`);
  try {
    runMapshaper(shpPath, outPath);
    processed += 1;
  } catch (error) {
    console.error('✗ mapshaper failed for', shpPath, error.message);
    skipped += 1;
  }
}

console.log(`TIGER layer processed. ${processed} new GeoJSON files, ${skipped} skipped.`);
