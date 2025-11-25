#!/usr/bin/env node
/**
 * fullRebuild.cjs
 * One-shot end-to-end data build pipeline:
 *  1. Derive (or refresh) canonical projection via buildCanonical.cjs using high-detail states + key overlays.
 *  2. Rebuild atlas from counties (dissolve) sharing simplification with overlays for boundary identity.
 *  3. Rebuild all overlays (reuse canonical projection).
 *  4. Summarize projection params and basic integrity metrics.
 *
 * Environment options:
 *  SIMPLIFY=8           # simplification percent for atlas (counties dissolve) and overlays
 *  SKIP_CANONICAL=1     # reuse existing atlasProjection.json instead of recomputing union-fit
 */
const { execSync } = require('child_process');
const fs = require('fs');

const SIMPLIFY = Number(process.env.SIMPLIFY || 8);
const skipCanonical = !!process.env.SKIP_CANONICAL;

// Source shapefiles
const STATE_SHAPE = 'data/raw/cb_2023_us_state_5m/cb_2023_us_state_5m.shp';
const COUNTIES_SHAPE = 'data/raw/cb_2023_us_state_5m/US County/cb_2018_us_county_500k.shp';
const CANON_OVERLAYS = [
  'data/raw/cb_2023_us_state_5m/US County/cb_2018_us_county_500k.shp',
  'data/raw/cb_2023_us_state_5m/Congressional Districts 116th Congress/cb_2018_us_cd116_500k.shp',
  'data/raw/cb_2023_us_state_5m/Urban Areas/cb_2018_us_ua10_500k.shp'
];

function exists(p){ if(!fs.existsSync(p)){ console.error('[fullRebuild] Missing shapefile:', p); process.exit(1);} }
exists(STATE_SHAPE); exists(COUNTIES_SHAPE); CANON_OVERLAYS.forEach(exists);

try {
  if (!skipCanonical) {
    console.log('\n[fullRebuild] Step 1: Computing canonical projection (union-fit) ...');
  // Quote each overlay path (contains spaces) so buildCanonical receives intact arguments
  const overArg = CANON_OVERLAYS.map(p=>`"${p}"`).join(',');
  const cmd = `node scripts/buildCanonical.cjs --states "${STATE_SHAPE}" --overlays ${overArg} --atlas-out data/atlas.generated.ts --atlas-simplify ${SIMPLIFY}`;
    execSync(cmd, { stdio: 'inherit' });
  } else {
    console.log('[fullRebuild] Skipping canonical projection (reuse existing atlasProjection.json)');
  }

  console.log('\n[fullRebuild] Step 2: Rebuilding atlas from dissolved counties (shared boundaries) ...');
  const atlasCmd = `node scripts/buildAtlasFromCounties.cjs --input "${COUNTIES_SHAPE}" --simplify ${SIMPLIFY} --out data/atlas.generated.ts --reuse-projection`;
  execSync(atlasCmd, { stdio: 'inherit' });

  console.log('\n[fullRebuild] Step 3: Rebuilding overlays ...');
  process.env.UNIFIED_SIMPLIFY = String(SIMPLIFY);
  execSync('node scripts/buildAllOverlays.cjs', { stdio: 'inherit' });

  console.log('\n[fullRebuild] Step 4: Summary');
  const proj = JSON.parse(fs.readFileSync('data/atlasProjection.json','utf8'));
  const atlas = fs.readFileSync('data/atlas.generated.ts','utf8');
  const stateCount = (atlas.match(/"id": "/g)||[]).length;
  console.log('[fullRebuild] Projection', { scale: proj.scale, translate: proj.translate });
  console.log('[fullRebuild] States:', stateCount, 'Simplify %:', SIMPLIFY);
  console.log('\n[fullRebuild] COMPLETE');
} catch (e) {
  console.error('[fullRebuild] Failed:', e.message);
  process.exit(1);
}
