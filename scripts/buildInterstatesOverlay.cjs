#!/usr/bin/env node
/**
 * buildInterstatesOverlay.cjs
 * Aggregates TIGER ROADS GeoJSON slices (generated via processTigerLayer.cjs),
 * filters to Interstate highways, and feeds the result into buildOverlay.cjs
 * to emit data/overlays/interstates.generated.ts.
 */

const fs = require('node:fs');
const path = require('node:path');
const { execSync } = require('node:child_process');

const args = process.argv.slice(2);
const options = {};
for (let i = 0; i < args.length; i += 1) {
  const key = args[i];
  if (!key.startsWith('--')) continue;
  const value = args[i + 1] && !args[i + 1].startsWith('--') ? args[i + 1] : true;
  options[key.slice(2)] = value;
}

const projectRoot = path.resolve(__dirname, '..');
const defaultSourceDir = path.join(projectRoot, 'data', 'overlays', 'tiger', 'roads');
const defaultOutModule = path.join(projectRoot, 'data', 'overlays', 'interstates.generated.ts');
const defaultTmpDir = path.join(projectRoot, 'tmp');

const sourceDir = options.source ? path.resolve(options.source) : defaultSourceDir;
const outModule = options.out ? path.resolve(options.out) : defaultOutModule;
const tmpDir = options.tmp ? path.resolve(options.tmp) : defaultTmpDir;
const mergedGeojsonPath = path.join(tmpDir, options.tmpName || 'interstates-merged.geojson');
const overlayKey = options.key || 'interstates';
const overlayLabel = options.label || 'Interstate Highways';
const simplify = options.simplify || '3';
const lod = options.lod || '1,4,10';

const quote = (value) => `"${String(value).replace(/"/g, '\\"')}"`;

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function loadFeatureFile(filePath) {
  try {
    const raw = fs.readFileSync(filePath, 'utf8');
    const json = JSON.parse(raw);
    if (!json || !Array.isArray(json.features)) {
      console.warn('⚠︎ Skipping invalid GeoJSON (missing features):', filePath);
      return [];
    }
    return json.features;
  } catch (err) {
    console.warn('⚠︎ Failed reading', filePath, '-', err.message);
    return [];
  }
}

function isInterstateFeature(feature) {
  if (!feature || !feature.geometry) return false;
  const props = feature.properties || {};
  const rttyp = typeof props.RTTYP === 'string' ? props.RTTYP.toUpperCase() : '';
  const mtfcc = typeof props.MTFCC === 'string' ? props.MTFCC.toUpperCase() : '';
  const fullname = typeof props.FULLNAME === 'string' ? props.FULLNAME.toUpperCase() : '';
  if (rttyp === 'I') return true;
  if (mtfcc === 'S1100' && rttyp === 'U' && /^I[-\s]/.test(fullname)) return true;
  if (/^INTERSTATE\s/i.test(props.FULLNAME || '')) return true;
  if (/^I[- ]\d+/i.test(props.FULLNAME || '')) return true;
  return false;
}

function stripProperties(feature) {
  const props = feature.properties || {};
  return {
    type: 'Feature',
    geometry: feature.geometry,
    properties: {
      LINEARID: props.LINEARID,
      FULLNAME: props.FULLNAME,
      RTTYP: props.RTTYP,
      MTFCC: props.MTFCC,
      STATEFP: props.STATEFP || props.STATE,
      COUNTYFP: props.COUNTYFP || props.COUNTY,
    },
  };
}

function collectInterstateFeatures() {
  if (!fs.existsSync(sourceDir)) {
    console.error('Source directory not found:', sourceDir);
    process.exit(1);
  }
  const files = fs.readdirSync(sourceDir).filter((entry) => entry.toLowerCase().endsWith('.geojson'));
  if (!files.length) {
    console.error('No GeoJSON files found under', sourceDir);
    process.exit(1);
  }
  const collected = [];
  for (const file of files) {
    const abs = path.join(sourceDir, file);
    const features = loadFeatureFile(abs);
    if (!features.length) continue;
    for (const feat of features) {
      if (!isInterstateFeature(feat)) continue;
      collected.push(stripProperties(feat));
    }
  }
  if (!collected.length) {
    console.error('No interstate features detected. Ensure RTTYP="I" segments exist in the source GeoJSON.');
    process.exit(1);
  }
  return collected;
}

function writeMergedGeojson(features) {
  ensureDir(tmpDir);
  const collection = { type: 'FeatureCollection', features };
  fs.writeFileSync(mergedGeojsonPath, JSON.stringify(collection));
  console.log('✓ Wrote merged GeoJSON:', mergedGeojsonPath, `(${features.length} features)`);
}

function buildOverlayFromMerged() {
  const cmdParts = [
    'node',
    quote(path.join(__dirname, 'buildOverlay.cjs')),
    '--input', quote(mergedGeojsonPath),
    '--out', quote(outModule),
    '--key', quote(overlayKey),
    '--label', quote(overlayLabel),
    '--simplify', simplify,
    '--lod', lod,
  ];
  if (options.dissolve) {
    cmdParts.push('--dissolve', options.dissolve);
  }
  const cmd = cmdParts.join(' ');
  console.log('\n→ Building overlay via buildOverlay.cjs');
  execSync(cmd, { stdio: 'inherit', env: process.env });
}

function cleanup() {
  if (options.keepTemp) return;
  try {
    fs.unlinkSync(mergedGeojsonPath);
  } catch {}
}

function main() {
  const features = collectInterstateFeatures();
  writeMergedGeojson(features);
  buildOverlayFromMerged();
  cleanup();
  console.log('\nInterstates overlay ready at', outModule);
}

main();
