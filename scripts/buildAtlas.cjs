#!/usr/bin/env node
/**
 * buildAtlas.cjs
 * Generate a compact atlas.ts from a raw state-level shapefile (Census cartographic boundary or similar).
 * Minimal manual steps: just place .shp/.shx/.dbf (+ .prj recommended) under data/raw and run npm run build:atlas.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
// (topojson-server not required for this simplified pipeline; using mapshaper + d3-geo)

// Lazy require mapshaper programmatic API
let mapshaper;
try { mapshaper = require('mapshaper'); } catch (e) {
  console.error('mapshaper package not installed. Install dev dependency first.');
  process.exit(1);
}

const args = process.argv.slice(2);
const argMap = {};
for (let i = 0; i < args.length; i++) {
  if (args[i].startsWith('--')) {
    const key = args[i].replace(/^--/, '');
    const val = args[i+1] && !args[i+1].startsWith('--') ? args[i+1] : true;
    argMap[key] = val;
  }
}

// Accept single --input or comma-separated list: --input a.shp,b.shp,c.shp
const inputRaw = argMap.input || argMap.inputs || argMap.i;
if (!inputRaw) {
  console.error('Missing --input path(s) to .shp file(s). Use --input file.shp or comma-separated list.');
  process.exit(1);
}
const inputList = inputRaw.split(',').map(s => s.trim()).filter(Boolean);

const simplify = Number(argMap.simplify || 8); // percent for visvalingam
const dissolve = argMap.dissolve || argMap.group || null; // attribute name to dissolve/merge by
const outFile = argMap.out || 'data/atlas.generated.ts';
const width = Number(argMap.width || 975);
const height = Number(argMap.height || 610);
const reuseProjection = !!argMap['reuse-projection'];

(async () => {
  const msInputs = {};
  const inputNames = [];
  const exts = ['.shp', '.shx', '.dbf', '.prj'];
  for (const input of inputList) {
    if (!fs.existsSync(input)) {
      console.error('Input shapefile not found:', input);
      process.exit(1);
    }
    const base = input.replace(/\.shp$/i, '');
    const files = exts.filter(ext => fs.existsSync(base + ext)).map(ext => base + ext);
    if (!files.length) {
      console.error('No associated shapefile components found for', base);
      process.exit(1);
    }
    for (const f of files) {
      const name = path.basename(base) + path.extname(f); // avoid collisions
      inputNames.push(name);
      msInputs[name] = fs.readFileSync(f);
    }
  }

    // Build mapshaper command dynamically with all inputs
    // Use combine-files to ensure a single layer if multiple inputs
    // NOTE: We intentionally DO NOT project in mapshaper by default to avoid double projection when we later
    // feed raw lon/lat coords through d3.geoAlbersUsa(). If you pass --ms-proj we keep the old behavior and skip d3 fit.
    const useMapshaperProjection = !!(argMap['ms-proj'] || argMap['proj']);
  let cmd = `-i ${inputNames.filter(n => n.endsWith('.shp')).join(' ')} combine-files` + (useMapshaperProjection ? ' -proj albersusa' : '');
  if (dissolve && dissolve !== 'none') {
    cmd += ` -dissolve ${dissolve}`;
  }
  // We'll attempt filter-fields but only include fields we know exist; introspect DBF minimally by trying all first, falling back silently in CLI.
  // For programmatic API we can't easily inspect attributes before running commands without a first pass, so keep safest (no filter) then trim in JS.
  cmd += ` -simplify visvalingam ${simplify}% keep-shapes -o format=geojson precision=0.0001 merged.geojson`;

  let geojsonStr;
  try {
    geojsonStr = await new Promise((resolve, reject) => {
      mapshaper.runCommands(cmd, msInputs, (err, outputs) => {
        if (err) return reject(err);
        if (!outputs) return reject(new Error('No outputs object from mapshaper'));
        const key = Object.keys(outputs).find(k => /merged\.geojson$/i.test(k)) || Object.keys(outputs)[0];
        if (!key) return reject(new Error('No output key found'));
        resolve(outputs[key].toString('utf8'));
      });
    });
  } catch (e) {
    console.warn('Programmatic mapshaper failed:', e.message, '\nAttempting CLI fallback...');
    try {
      const tmpOut = '.tmp-merged.geojson';
      // Only include -dissolve when user specified a field. (Previously always added bare -dissolve which merged all features into one and introduced frame artifacts.)
      const dissolvePart = dissolve ? `-dissolve ${dissolve}` : '';
  const cliCmd = `npx mapshaper -i ${inputList.map(p => '"'+p+'"').join(' ')} combine-files ${useMapshaperProjection ? '-proj albersusa ' : ''}${dissolvePart} -simplify visvalingam ${simplify}% keep-shapes -o format=geojson precision=0.0001 ${tmpOut}`;
      execSync(cliCmd, { stdio: 'inherit' });
      geojsonStr = fs.readFileSync(tmpOut, 'utf8');
      fs.unlinkSync(tmpOut);
    } catch (cliErr) {
      console.error('CLI fallback failed:', cliErr.message);
      process.exit(1);
    }
  }

  const geo = JSON.parse(geojsonStr);
  const geomTypes = (geo.features || []).map(f => f.geometry && f.geometry.type).slice(0,5).join(', ');
  console.log(`[buildAtlas] Parsed ${geo.features ? geo.features.length : 0} features. Sample geometry types: ${geomTypes}`);
  if (!geo.features) {
    console.error('Expected FeatureCollection with features');
    process.exit(1);
  }

  // Detect boundary-line shapefile misuse (LineString geometries) which will render as strokes only.
  const firstGeomType = geo.features[0] && geo.features[0].geometry && geo.features[0].geometry.type;
  if (/LineString/i.test(firstGeomType)) {
    console.error('\n[ERROR] The input appears to be a boundary line dataset (geometry type LineString).');
    console.error('       You need a polygon (area) shapefile (e.g. cb_2023_us_state_5m.shp from TIGER/Cartographic Boundary).');
    console.error('       Result would only show lines, not filled states. Aborting without writing atlas.');
    process.exit(1);
  }

  // Use d3-geo via dynamic import (ESM) inside CJS script
  const d3 = await import('d3-geo');
  let projection;
  if (useMapshaperProjection) {
    // Geometry already projected to Albers USA by mapshaper; we only need to normalize scale/translate to viewport.
    // Compute bounds and derive uniform scaling.
    const allCoords = [];
    for (const f of geo.features) {
      d3.geoStream(f, {
        point(x,y){ allCoords.push([x,y]); },
        lineStart() {}, lineEnd() {}, polygonStart() {}, polygonEnd() {}
      });
    }
    const xs = allCoords.map(c=>c[0]);
    const ys = allCoords.map(c=>c[1]);
    const minX = Math.min(...xs), maxX = Math.max(...xs), minY = Math.min(...ys), maxY = Math.max(...ys);
    const spanX = maxX - minX;
    const spanY = maxY - minY;
    const scale = Math.min(width / spanX, height / spanY) * 0.98; // slight padding
    const tx = (width - spanX * scale)/2 - minX * scale;
    const ty = (height - spanY * scale)/2 - minY * scale;
    projection = { // minimal projection interface with stream() applying affine transform
      stream(sink){
        return {
          point(x,y){ sink.point(x*scale + tx, y*scale + ty); },
          sphere(){ sink.sphere && sink.sphere(); },
          lineStart(){ sink.lineStart && sink.lineStart(); },
          lineEnd(){ sink.lineEnd && sink.lineEnd(); },
          polygonStart(){ sink.polygonStart && sink.polygonStart(); },
          polygonEnd(){ sink.polygonEnd && sink.polygonEnd(); }
        };
      }
    };
  } else {
    // Optionally reuse previously computed scale/translate (canonical) instead of refitting
    if (reuseProjection) {
      try {
        const prev = JSON.parse(fs.readFileSync('data/atlasProjection.json','utf8'));
        if (prev.scale && prev.translate) {
          projection = d3.geoAlbersUsa().scale(prev.scale).translate(prev.translate);
          console.log('[buildAtlas] Reused existing projection params');
        } else {
          console.warn('[buildAtlas] atlasProjection.json missing scale/translate – falling back to fit');
          projection = d3.geoAlbersUsa();
          projection.fitSize([width,height], geo);
        }
      } catch (e) {
        console.warn('[buildAtlas] Failed to reuse projection, fitting instead:', e.message);
        projection = d3.geoAlbersUsa();
        try { projection.fitSize([width,height], geo); } catch (e2) {
          console.warn('projection.fitSize failed, fallback heuristic:', e2.message);
          projection.translate([width / 2, height / 2]).scale(Math.min(width, height) * 1.25 * 1.9);
        }
      }
    } else {
      projection = d3.geoAlbersUsa();
      try {
        projection.fitSize([width, height], geo);
      } catch (e) {
        console.warn('projection.fitSize failed, fallback heuristic:', e.message);
        projection.translate([width / 2, height / 2]).scale(Math.min(width, height) * 1.25 * 1.9);
      }
    }
  }
  const pathGen = d3.geoPath(projection);

  if (geo.features.length > 150 && !dissolve) {
    console.warn('[WARN] Large feature count detected (' + geo.features.length + '). You may want to use --dissolve STUSPS (or appropriate field) to merge sub-geometries.');
  }

  // Helper to strip any outer-frame rectangle accidentally introduced (buggy dissolve w/o attribute previously)
  const RECT_SUBPATH_RE = /^M[0-9.+-]+,[0-9.+-]+L[0-9.+-]+,[0-9.+-]+L[0-9.+-]+,[0-9.+-]+L[0-9.+-]+,[0-9.+-]+Z$/;
  function isAxisAlignedRect(p){
    p = p.trim();
    if(!RECT_SUBPATH_RE.test(p)) return false;
    const coords = [...p.matchAll(/[ML]([0-9.+-]+),([0-9.+-]+)/g)].map(m=>[Number(m[1]),Number(m[2])]);
    // Accept either 4 (M + 3 L) or 5 (M + 4 L) coordinate entries depending on whether path repeats start.
    if (!(coords.length === 4 || coords.length === 5)) return false;
    const [x1,y1] = coords[0];
    const [x2,y2] = coords[1];
    const [x3,y3] = coords[2];
    const [x4,y4] = coords[3];
    return x1===x4 && y1===y2 && x2===x3 && y3===y4 && x1!==x2 && y1!==y3;
  }
  function cleanPath(d) {
    if (!d) return d;
    // Split into subpaths on 'M' (keeping the leading M by re-adding later)
    const parts = d.split('M').filter(Boolean).map(p => 'M' + p);
    const filtered = parts.filter(p => !isAxisAlignedRect(p));
    // Deduplicate exact repeats to shrink size
    const uniq = []; const seen = new Set();
    for (const p of filtered) { if (!seen.has(p)) { seen.add(p); uniq.push(p); } }
    return uniq.join('');
  }

  // Compute bounds directly from the cleaned SVG path string (since the source GeoJSON
  // geometries may retain an outer frame ring that we strip from the path). This avoids
  // every state's bbox appearing as the full map extent.
  function pathBounds(d){
    let minX= Infinity, minY= Infinity, maxX=-Infinity, maxY=-Infinity;
    const re = /[ML](-?[0-9]+(?:\.[0-9]+)?),(-?[0-9]+(?:\.[0-9]+)?)/g;
    let m; let found=false;
    while((m = re.exec(d))){
      found = true;
      const x = +m[1]; const y = +m[2];
      if(x<minX) minX=x; if(x>maxX) maxX=x; if(y<minY) minY=y; if(y>maxY) maxY=y;
    }
    if(!found){ return [0,0,0,0]; }
    return [Number(minX.toFixed(2)), Number(minY.toFixed(2)), Number(maxX.toFixed(2)), Number(maxY.toFixed(2))];
  }

  function pathCentroid(b){
    const [minX,minY,maxX,maxY] = b;
    return [Number(((minX+maxX)/2).toFixed(2)), Number(((minY+maxY)/2).toFixed(2))];
  }

  const excludeTerritories = !!argMap['continental-only'] || !!argMap['exclude-territories'];
  const TERRITORY_IDS = new Set(['AS','GU','MP','PR','VI']);
  const states = geo.features.map(f => {
    const props = f.properties || {};
  const id = props.STUSPS || props.STATE || props.STATE_ABBR || props.GEOID || 'UNK';
  const name = props.NAME || props.STATE_NAME || id;
    let d = pathGen(f);
    d = cleanPath(d);
    if (!d) return null;
    // Use cleaned path-derived bounds/centroid to avoid contamination by spurious frame ring.
    const bbox = pathBounds(d);
    const centroid = pathCentroid(bbox);
    if (excludeTerritories && TERRITORY_IDS.has(id)) return null;
    return {
      id,
      name,
      fips: (props.GEOID || '').toString(),
      path: d,
      bbox,
      centroid,
      geometry: f.geometry,
    };
  }).filter(Boolean).sort((a,b) => a.id.localeCompare(b.id));

  // Capture projection parameters (scale/translate) if available so overlays can reuse exact transform.
  let projScale = null, projTranslate = null;
  try { if (typeof projection.scale === 'function') projScale = projection.scale(); } catch {}
  try { if (typeof projection.translate === 'function') projTranslate = projection.translate(); } catch {}
  const atlas = { width, height, projection: 'albersUsa', states, projectionParams: { scale: projScale, translate: projTranslate } };
  const banner = '// THIS FILE IS AUTO-GENERATED. DO NOT EDIT MANUALLY.\n';
  const out = `${banner}import { Atlas } from '../types';\nexport const atlas: Atlas = ${JSON.stringify(atlas, null, 2)};\n`;

  fs.writeFileSync(outFile, out);
  // Also emit a lightweight JSON for projection reuse by overlay builder
  try {
    fs.writeFileSync('data/atlasProjection.json', JSON.stringify({ scale: projScale, translate: projTranslate, width, height }, null, 2));
  } catch (e) {
    console.warn('Could not write data/atlasProjection.json:', e.message);
  }
  if (states.some(s => s.path.split('M').length > 500)) {
    console.warn('[WARN] Extremely complex path data detected. Consider increasing simplify percentage (e.g. --simplify 12) to reduce file size.');
  }
  console.log('Atlas written to', outFile, `(${states.length} features)`, useMapshaperProjection ? '[ms-proj mode]' : '[d3 proj mode]');
})();
