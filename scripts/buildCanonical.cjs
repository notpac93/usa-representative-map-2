#!/usr/bin/env node
/**
 * buildCanonical.cjs
 * Derive a canonical Albers USA projection (scale/translate) by union-fitting
 * high-detail states + selected overlay layers simultaneously. Then rebuild
 * the atlas (with simplification) and overlays reusing that projection to
 * eliminate residual drift.
 *
 * Usage:
 *  node scripts/buildCanonical.cjs \
 *    --states data/raw/cb_2023_us_state_5m/cb_2018_us_state_500k/cb_2018_us_state_500k.shp \
 *    --overlays data/raw/.../cb_2018_us_county_500k.shp,data/raw/.../cb_2018_us_cd116_500k.shp \
 *    --atlas-out data/atlas.generated.ts --atlas-simplify 8
 */
const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');

const args = process.argv.slice(2);
const arg = {};
for (let i=0;i<args.length;i++) if(args[i].startsWith('--')) arg[args[i].slice(2)] = args[i+1] && !args[i+1].startsWith('--') ? args[i+1] : true;

if(!arg.states){ console.error('Missing --states shapefile'); process.exit(1);} 
const overlayList = (arg.overlays||'').split(',').map(s=>s.trim()).filter(Boolean);
if(!overlayList.length){ console.error('Missing --overlays (comma separated shapefiles)'); process.exit(1);} 
const atlasOut = arg['atlas-out'] || 'data/atlas.generated.ts';
const atlasSimplify = Number(arg['atlas-simplify'] || 8);
const width = Number(arg.width || 975);
const height = Number(arg.height || 610);

function shpExists(p){ if(!fs.existsSync(p)) { console.error('Shapefile not found:', p); process.exit(1);} }
shpExists(arg.states);
overlayList.forEach(shpExists);

function toTmp(shp){
  const out = path.join('tmp_fit_' + path.basename(shp, '.shp') + '.geojson');
  const cmd = `npx mapshaper -i "${shp}" -simplify visvalingam 0.1% keep-shapes -o format=geojson precision=0.0001 ${out}`;
  execSync(cmd, { stdio: 'inherit' });
  return out;
}

console.log('[canonical] Extracting low-simplify GeoJSON for fit...');
const tempFiles = [arg.states, ...overlayList].map(toTmp);
let allFeatures = [];
for (const f of tempFiles){
  const geo = JSON.parse(fs.readFileSync(f,'utf8'));
  if(geo.type==='FeatureCollection') allFeatures = allFeatures.concat(geo.features||[]);
}
const unionGeo = { type:'FeatureCollection', features: allFeatures };

(async () => {
  const d3 = await import('d3-geo');
  const proj = d3.geoAlbersUsa();
  try { proj.fitSize([width,height], unionGeo); } catch (e) {
    console.warn('[canonical] fitSize failed, fallback heuristic');
    proj.translate([width/2,height/2]).scale(Math.min(width,height)*1.25*1.9);
  }
  let scale=null, translate=null;
  try { scale = proj.scale(); translate = proj.translate(); } catch {}
  if(!scale || !translate){ console.error('Failed to obtain projection parameters'); process.exit(1);} 
  fs.writeFileSync('data/atlasProjection.json', JSON.stringify({ scale, translate, width, height, canonical:true }, null, 2));
  console.log('[canonical] Wrote data/atlasProjection.json with canonical scale/translate');
  const atlasCmd = `node scripts/buildAtlas.cjs --input ${arg.states} --out ${atlasOut} --simplify ${atlasSimplify} --reuse-projection`;
  console.log('[canonical] Rebuilding atlas:', atlasCmd);
  execSync(atlasCmd, { stdio:'inherit' });
  console.log('[canonical] Rebuild overlays using existing buildAllOverlays (will reuse projection) ...');
  try { execSync('node scripts/buildAllOverlays.cjs', { stdio:'inherit' }); } catch (e) { console.warn('[canonical] overlay rebuild warning:', e.message); }
  for (const f of tempFiles) { try { fs.unlinkSync(f); } catch {} }
  console.log('[canonical] Complete. Reload with ?diag=1 to inspect alignment.');
})();
