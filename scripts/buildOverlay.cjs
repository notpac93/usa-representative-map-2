#!/usr/bin/env node
/**
 * buildOverlay.cjs
 * Generic overlay builder producing a generated TS module with SVG paths for features.
 * Usage example:
 *   node scripts/buildOverlay.cjs \
 *     --input "data/raw/cb_2023_us_state_5m/Urban Areas/cb_2018_us_ua10_500k.shp" \
 *     --out data/overlays/urbanAreas.generated.ts \
 *     --key urban-areas --label "Urban Areas" --simplify 10
 */

const fs = require('fs');
const path = require('path');
// We prefer the CLI pathway (more reliable with some shapefiles + path spaces).
let mapshaperApi = null;
try { mapshaperApi = require('mapshaper'); } catch (_) { /* API optional */ }
const { execSync } = require('child_process');

const args = process.argv.slice(2);
const arg = {};
for (let i = 0; i < args.length; i++) {
  if (args[i].startsWith('--')) arg[args[i].slice(2)] = args[i + 1] && !args[i + 1].startsWith('--') ? args[i + 1] : true;
}

const input = arg.input;
if (!input) { console.error('Missing --input shapefile'); process.exit(1); }
const outFile = arg.out || 'data/overlays/generatedOverlay.ts';
const key = arg.key || 'overlay';
const label = arg.label || 'Overlay';
const simplify = Number(arg.simplify || 10);
// Optional LOD simplifies: comma-separated percentages, e.g. "2,6,12" (high,mid,low)
const lodArg = arg.lod || arg.lods || null;
let lodPercents = null; // [high, mid, low]
if (lodArg) {
  const parts = String(lodArg).split(',').map(s => Number(s.trim())).filter(n => !isNaN(n) && n >= 0);
  if (parts.length >= 2) {
    // Normalize to [high, mid, low]
    const sorted = parts.slice(0, 3);
    while (sorted.length < 3) sorted.push(sorted[sorted.length - 1]);
    lodPercents = sorted; // interpret as [high, mid, low]
  }
}

const clip = arg.clip || null;
const dissolve = arg.dissolve || null;
const width = Number(arg.width || 975);
const height = Number(arg.height || 610);

if (!fs.existsSync(input)) {
  console.error('Input not found', input);
  process.exit(1);
}
// Support directories (with spaces) by keeping full path for existence checks but
// providing only the filename (no directories) as the virtual input name to mapshaper.

const inputExt = path.extname(input).toLowerCase();
const isShapefile = inputExt === '.shp';

let shpName = null;
let msInputs = null;
if (isShapefile) {
  const base = input.replace(/\.shp$/i, '');
  const dir = path.dirname(base);
  const fileBase = path.basename(base);
  const parts = ['.shp', '.shx', '.dbf', '.prj'].filter(ext => fs.existsSync(path.join(dir, fileBase + ext)));
  msInputs = {};
  for (const ext of parts) {
    const full = path.join(dir, fileBase + ext);
    msInputs[fileBase + ext] = fs.readFileSync(full);
  }
  shpName = Object.keys(msInputs).find(n => /\.shp$/i.test(n));
  if (!shpName) {
    console.error('Could not locate .shp among inputs. Provided keys:', Object.keys(msInputs));
    process.exit(1);
  }
}

(async () => {
  let geojsonStr;
  // Direct CLI approach first (robust with path spaces)
  try {
    const tmpOut = path.join(process.cwd(), 'tmp_overlay_out.geojson');
    const dissolvePart = dissolve ? `-dissolve ${dissolve}` : '';
    const clipPart = clip ? `-clip "${clip}" remove-slivers` : '';
    const cli = `npx mapshaper -i "${input}" ${clipPart} ${dissolvePart} -simplify visvalingam ${simplify}% keep-shapes -o format=geojson precision=0.0001 ${tmpOut}`;
    console.log('[buildOverlay] CLI:', cli);
    execSync(cli, { stdio: 'inherit' });
    if (fs.existsSync(tmpOut)) {
      geojsonStr = fs.readFileSync(tmpOut, 'utf8');
      fs.unlinkSync(tmpOut);
    }
  } catch (e) {
    console.warn('[buildOverlay] CLI attempt failed, trying API (reduced command).', e.message);
  }
  // API fallback (optional, shapefile only)
  if (!geojsonStr && isShapefile && mapshaperApi) {
    try {
      geojsonStr = await new Promise((resolve, reject) => {
        const cmd = `-i ${shpName} -o format=geojson out.geojson`;
        mapshaperApi.runCommands(cmd, msInputs, (err, outputs) => {
          if (err || !outputs) return reject(err || new Error('No outputs from API fallback'));
          const k = Object.keys(outputs).find(k => /out\.geojson$/i.test(k));
          if (!k) return reject(new Error('API fallback missing out.geojson'));
          resolve(outputs[k].toString('utf8'));
        });
      });
    } catch (e) {
      console.error('[buildOverlay] API fallback failed:', e.message);
    }
  }
  // GeoJSON direct read fallback
  if (!geojsonStr && !isShapefile) {
    try {
      geojsonStr = fs.readFileSync(input, 'utf8');
    } catch (e) {
      console.error('Failed to read GeoJSON input:', e.message);
    }
  }
  if (!geojsonStr) {
    console.error('Failed to produce GeoJSON from overlay input. Aborting.');
    process.exit(1);
  }
  const geo = JSON.parse(geojsonStr);
  let geoMid = null, geoLow = null;
  if (lodPercents) {
    // Build additional simplified versions via CLI for mid/low
    const tmpMid = path.join(process.cwd(), 'tmp_overlay_mid.geojson');
    const tmpLow = path.join(process.cwd(), 'tmp_overlay_low.geojson');
    const dissolvePart = dissolve ? `-dissolve ${dissolve}` : '';
    const clipPart = clip ? `-clip "${clip}" remove-slivers` : '';
    try {
      const midPct = lodPercents[1];
      const lowPct = lodPercents[2];
      const cliMid = `npx mapshaper -i "${input}" ${clipPart} ${dissolvePart} -simplify visvalingam ${midPct}% keep-shapes -o format=geojson precision=0.0001 ${tmpMid}`;
      const cliLow = `npx mapshaper -i "${input}" ${clipPart} ${dissolvePart} -simplify visvalingam ${lowPct}% keep-shapes -o format=geojson precision=0.0001 ${tmpLow}`;
      execSync(cliMid, { stdio: 'inherit' });
      execSync(cliLow, { stdio: 'inherit' });
      if (fs.existsSync(tmpMid)) { geoMid = JSON.parse(fs.readFileSync(tmpMid, 'utf8')); fs.unlinkSync(tmpMid); }
      if (fs.existsSync(tmpLow)) { geoLow = JSON.parse(fs.readFileSync(tmpLow, 'utf8')); fs.unlinkSync(tmpLow); }
    } catch (e) {
      console.warn('[buildOverlay] LOD generation failed:', e.message);
      geoMid = null; geoLow = null;
    }
  }
  const d3 = await import('d3-geo');
  let projection = d3.geoAlbersUsa();
  // Attempt to reuse atlas projection params for perfect alignment
  try {
    const projPath = path.join('data', 'atlasProjection.json');
    if (fs.existsSync(projPath)) {
      const params = JSON.parse(fs.readFileSync(projPath, 'utf8'));
      if (params.scale && params.translate) {
        projection = d3.geoAlbersUsa().scale(params.scale).translate(params.translate);
      } else {
        projection.fitSize([width, height], geo);
      }
    } else {
      projection.fitSize([width, height], geo);
    }
  } catch (e) {
    try { projection.fitSize([width, height], geo); } catch { }
  }
  const pathGen = d3.geoPath(projection);

  function boundsFromPath(d) {
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity; let m; const re = /[ML](-?[0-9]+(?:\.[0-9]+)?),(-?[0-9]+(?:\.[0-9]+)?)/g;
    while ((m = re.exec(d))) { const x = +m[1], y = +m[2]; if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
    if (minX === Infinity) return [0, 0, 0, 0];
    return [Number(minX.toFixed(2)), Number(minY.toFixed(2)), Number(maxX.toFixed(2)), Number(maxY.toFixed(2))];
  }

  // Helper to extract stable id/name
  function getIdName(f, i) {
    const id = (f.properties && (f.properties.GEOID10 || f.properties.GEOID || f.properties.CODE || f.properties.ID)) || String(i);
    const name = (f.properties && (f.properties.NAME10 || f.properties.NAME || f.properties.NAMELSAD10)) || `Feature ${i + 1}`;
    return { id, name };
  }

  // Build high detail features first
  const features = (geo.features || []).map((f, i) => {
    const p = pathGen(f);
    if (!p) return null;
    // Remove any large axis-aligned rectangle subpaths (artifact similar to earlier atlas issue)
    function cleanPath(d) {
      if (!d) return d;
      const parts = d.split('M').filter(Boolean).map(seg => 'M' + seg);
      const RECT_RE = /^M[-0-9.]+,[-0-9.]+L[-0-9.]+,[-0-9.]+L[-0-9.]+,[-0-9.]+L[-0-9.]+,[-0-9.]+Z$/;
      const filtered = parts.filter(seg => {
        // Drop any simple axis-aligned rectangle subpath outright (common artifact injected by some shapefiles)
        if (RECT_RE.test(seg.trim())) return false;
        return true;
      });
      // Deduplicate
      const seen = new Set();
      const uniq = []; for (const seg of filtered) { if (!seen.has(seg)) { seen.add(seg); uniq.push(seg); } }
      return uniq.join('');
    }
    const cleaned = cleanPath(p);
    const bbox = boundsFromPath(cleaned);
    // Drop artifacts whose bbox spans ~entire viewport (likely the stray frame rectangle pattern)
    const spanW = bbox[2] - bbox[0];
    const spanH = bbox[3] - bbox[1];
    if (spanW > width * 0.5 && spanH > height * 0.5) return null;
    const { id, name } = getIdName(f, i);
    return { id, name, path: cleaned || '', bbox };
  }).filter(Boolean);

  // Optionally attach mid/low detail paths by id
  function attachAltPaths(geoSrc, key) {
    if (!geoSrc) return;
    const feats = geoSrc.features || [];
    for (let i = 0; i < feats.length; i++) {
      const f = feats[i];
      const { id } = getIdName(f, i);
      const p = pathGen(f);
      if (!p) continue;
      // reuse cleaner and skip giant rects
      function cleanPath(d) {
        if (!d) return d;
        const parts = d.split('M').filter(Boolean).map(seg => 'M' + seg);
        const RECT_RE = /^M[-0-9.]+,[-0-9.]+L[-0-9.]+,[-0-9.]+L[-0-9.]+,[-0-9.]+L[-0-9.]+,[-0-9.]+Z$/;
        const filtered = parts.filter(seg => !RECT_RE.test(seg.trim()));
        const seen = new Set(); const uniq = []; for (const seg of filtered) { if (!seen.has(seg)) { seen.add(seg); uniq.push(seg); } }
        return uniq.join('');
      }
      const cleaned = cleanPath(p);
      const rec = features.find(ff => ff.id === id);
      if (rec) {
        if (key === 'mid') rec.pathMid = cleaned || rec.pathMid;
        if (key === 'low') rec.pathLow = cleaned || rec.pathLow;
      }
    }
  }

  if (lodPercents) {
    attachAltPaths(geoMid, 'mid');
    attachAltPaths(geoLow, 'low');
  }

  // Capture projection params (scale & translate) when possible for diagnostic comparison to atlas
  let projScale = null, projTranslate = null;
  try { if (typeof projection.scale === 'function') projScale = projection.scale(); } catch { }
  try { if (typeof projection.translate === 'function') projTranslate = projection.translate(); } catch { }
  const layer = { key, label, features, source: 'Census', stroke: '#2563eb', fill: 'rgba(59,130,246,0.35)', projectionParams: { scale: projScale, translate: projTranslate } };
  if (outFile.endsWith('.json')) {
    fs.writeFileSync(outFile, JSON.stringify(layer, null, 2));
    console.log('Overlay written (JSON)', outFile, features.length, 'features');
  } else {
    const banner = '// AUTO-GENERATED by buildOverlay.cjs. DO NOT EDIT.\n';
    function toCamel(str) { return str.split(/[-_\s]+/).map((p, i) => i === 0 ? p.toLowerCase() : p.charAt(0).toUpperCase() + p.slice(1).toLowerCase()).join(''); }
    const varBase = toCamel(key);
    const varName = varBase.endsWith('Layer') ? varBase : varBase + 'Layer';
    const out = `${banner}import type { OverlayLayer } from '../../types';\nexport const ${varName}: OverlayLayer = ${JSON.stringify(layer, null, 2)};\nexport default ${varName};\n`;
    fs.writeFileSync(outFile, out);
    console.log('Overlay written', outFile, features.length, 'features');
  }
})();
