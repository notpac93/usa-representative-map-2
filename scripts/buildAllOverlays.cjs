#!/usr/bin/env node
/**
 * buildAllOverlays.cjs
 * Batch-generate multiple overlay layers via buildOverlay.cjs.
 * Adjust the entries array as you add raw shapefiles.
 */
const { execSync } = require('child_process');

// Allow orchestration (fullRebuild) to override simplification via env var
const UNIFIED_SIMPLIFY = Number(process.env.UNIFIED_SIMPLIFY || 2); // high-detail percent for close zooms
const UNIFIED_LOD = process.env.UNIFIED_LOD || '2,6,12'; // high,mid,low simplify percents
const STATE_SHAPE = 'data/raw/cb_2023_us_state_5m/cb_2023_us_state_5m.shp';

const entries = [
  {
    key: 'urban-areas',
    label: 'Urban Areas',
    input: 'data/raw/cb_2023_us_state_5m/Urban Areas/cb_2018_us_ua10_500k.shp',
    simplify: UNIFIED_SIMPLIFY,
    out: 'data/overlays/urbanAreas.generated.ts'
  },
  {
    key: 'regions',
    label: 'US Regions',
    input: 'data/raw/cb_2023_us_state_5m/Regions/cb_2018_us_region_500k.shp',
    simplify: UNIFIED_SIMPLIFY,
    out: 'data/overlays/regions.generated.ts'
  },
  {
    key: 'congressional-districts',
    label: 'Congressional Districts (116th)',
    input: 'data/raw/cb_2023_us_state_5m/Congressional Districts 116th Congress/cb_2018_us_cd116_500k.shp',
    simplify: UNIFIED_SIMPLIFY,
    out: 'data/overlays/cd116.generated.ts'
  },
  {
    key: 'counties',
    label: 'Counties',
    input: 'data/raw/cb_2023_us_state_5m/US County/cb_2018_us_county_500k.shp',
    simplify: UNIFIED_SIMPLIFY,
    out: 'data/overlays/counties.generated.ts'
  },
  {
    key: 'water-bodies',
    label: 'Water Bodies',
    input: 'data/raw/naturalearth/ne_10m_lakes/ne_10m_lakes.shp',
    simplify: UNIFIED_SIMPLIFY,
    customBuild: 'node scripts/buildWater.cjs',
    out: 'data/overlays/water.generated.ts'
  }
];

for (const e of entries) {
  try {
    console.log(`\n[buildAllOverlays] Building ${e.key} ...`);
    if (e.customBuild) {
      execSync(e.customBuild, { stdio: 'inherit' });
    } else {
      const clipArg = e.clip ? `--clip "${e.clip}"` : '';
      execSync(`node scripts/buildOverlay.cjs --input "${e.input}" --out ${e.out} --key ${e.key} --label "${e.label}" --simplify ${e.simplify} --lod ${UNIFIED_LOD} ${clipArg}`, { stdio: 'inherit' });
    }
  } catch (err) {
    console.warn(`[buildAllOverlays] Failed building ${e.key}:`, err.message);
  }
}

console.log('\n[buildAllOverlays] Complete.');
