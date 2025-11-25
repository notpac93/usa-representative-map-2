#!/usr/bin/env node
/**
 * buildAtlasFromBlockGroups.cjs
 * Aggregates per-state Census Block Group shapefiles into a single simplified state outline atlas.
 * This is a fallback when you only have block group (bg) layers, not the simpler state layer.
 * It dissolves (merges) all geometries in each state's file into one multi/ polygon, then projects + simplifies.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
let mapshaper;
try { mapshaper = require('mapshaper'); } catch (e) {
  console.error('mapshaper dependency missing. Install it first.');
  process.exit(1);
}

const args = process.argv.slice(2);
const opts = {};
for (let i=0;i<args.length;i++) {
  if (args[i].startsWith('--')) {
    const k = args[i].replace(/^--/,'');
    const v = args[i+1] && !args[i+1].startsWith('--') ? args[i+1] : true;
    opts[k] = v;
  }
}

const root = opts.root || 'data/raw';
const simplify = Number(opts.simplify || 8);
const outFile = opts.out || 'data/atlas.generated.ts';
const width = Number(opts.width || 975);
const height = Number(opts.height || 610);
const includeFilter = opts.include ? new Set(String(opts.include).split(',').map(s=>s.trim().toLowerCase())) : null;

// Heuristic to find a .shp inside each subfolder matching *_bg_*.shp
function findShapefile(dir) {
  const files = fs.readdirSync(dir).filter(f => f.toLowerCase().endsWith('.shp'));
  // prefer block group pattern
  const bg = files.find(f => /_bg_/.test(f));
  return bg ? path.join(dir, bg) : (files[0] ? path.join(dir, files[0]) : null);
}

if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
  console.error('Root folder not found or not a directory:', root);
  process.exit(1);
}

let subdirs = fs.readdirSync(root).filter(d => fs.statSync(path.join(root,d)).isDirectory());
if (includeFilter) {
  subdirs = subdirs.filter(d => includeFilter.has(d.toLowerCase()) || includeFilter.has(d.slice(0,2).toLowerCase()));
}
if (!subdirs.length) {
  console.error('No state subdirectories found under', root);
  process.exit(1);
}

// Map of stateId -> temporary merged GeoJSON feature path (in memory)
const stateFeatures = [];

async function dissolveState(shpPath) {
  const base = shpPath.replace(/\.shp$/i,'');
  const layerName = path.basename(base);
  const exts = ['.shp','.shx','.dbf','.prj'];
  const inputs = {};
  for (const ext of exts) {
    const full = base + ext;
    if (fs.existsSync(full)) {
      inputs[path.basename(full)] = fs.readFileSync(full);
    }
  }
  // Dissolve ALL geometries (no attribute) => single feature
  const layerNames = Object.keys(inputs).filter(n=>n.endsWith('.shp'));
  const cmd = `-i ${layerNames.join(' ')} combine-files -proj albersusa -dissolve -simplify visvalingam ${simplify}% keep-shapes -o format=geojson precision=0.0001 merged.geojson`;
  if (opts.debug) {
    console.log('\n[DEBUG] mapshaper command:', cmd);
    console.log('[DEBUG] input files:', Object.keys(inputs));
  }
  return await new Promise((resolve, reject) => {
    mapshaper.runCommands(cmd, inputs, (err, outputs) => {
      if (err) {
        if (opts.debug) console.error('[DEBUG] mapshaper error:', err);
        return reject(err);
      }
      if (!outputs) return reject(new Error('No outputs returned by mapshaper'));
      const keys = Object.keys(outputs);
      if (opts.debug) console.log('[DEBUG] output keys:', keys);
      const outKey = keys.find(k => /merged\.geojson$/i.test(k)) || keys[0];
      if (!outKey) return reject(new Error('Could not determine output key'));
      try { resolve(JSON.parse(outputs[outKey].toString('utf8'))); } catch(e){ reject(e); }
    });
  });
}

(async () => {
  for (const dir of subdirs) {
    const full = path.join(root, dir);
    const shp = findShapefile(full);
    if (!shp) { console.warn('No shapefile in', full); continue; }
  process.stdout.write(`Processing ${dir}... `);
    try {
      let fc;
      try {
        fc = await dissolveState(shp);
      } catch (e) {
        if (opts.debug) console.warn('[DEBUG] programmatic mapshaper failed, attempting CLI fallback:', e.message);
        // CLI fallback: write output geojson into a temp folder
        const tmpDir = path.join('.tmp-mapshaper');
        if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir, { recursive: true });
        const outPath = path.join(tmpDir, 'merged.geojson');
        const cmd = `npx mapshaper -quiet -i "${shp}" -proj albersusa -dissolve -simplify visvalingam ${simplify}% keep-shapes -o format=geojson precision=0.0001 ${outPath}`;
        if (opts.debug) console.log('[DEBUG] CLI cmd:', cmd);
        try {
          execSync(cmd, { stdio: opts.debug ? 'inherit' : 'ignore' });
          const geo = JSON.parse(fs.readFileSync(outPath, 'utf8'));
          fc = geo;
        } catch (cliErr) {
          throw new Error('CLI fallback failed: ' + cliErr.message);
        }
      }
      if (!fc.features || !fc.features.length) { console.warn('empty'); continue; }
      let feature = fc.features[0];
      // Derive state code heuristically from filename (cb_2018_48_bg...) -> the two-digit FIPS after year
      const match = path.basename(shp).match(/cb_\d{4}_(\d{2})_bg/i);
      let fips = match ? match[1] : '';
      // We'll map FIPS -> USPS later (provide mapping here)
      const fipsToUsps = {
        '01':'AL','02':'AK','04':'AZ','05':'AR','06':'CA','08':'CO','09':'CT','10':'DE','11':'DC','12':'FL','13':'GA','15':'HI','16':'ID','17':'IL','18':'IN','19':'IA','20':'KS','21':'KY','22':'LA','23':'ME','24':'MD','25':'MA','26':'MI','27':'MN','28':'MS','29':'MO','30':'MT','31':'NE','32':'NV','33':'NH','34':'NJ','35':'NM','36':'NY','37':'NC','38':'ND','39':'OH','40':'OK','41':'OR','42':'PA','44':'RI','45':'SC','46':'SD','47':'TN','48':'TX','49':'UT','50':'VT','51':'VA','53':'WA','54':'WV','55':'WI','56':'WY','60':'AS','66':'GU','69':'MP','72':'PR','78':'VI'
      };
      const id = fipsToUsps[fips] || dir.slice(0,2).toUpperCase();
      feature.properties = { id, name: dir.replace(/_/g,' '), fips };
      stateFeatures.push(feature);
      console.log('ok');
    } catch (e) {
      console.warn('failed', e.message);
    }
  }

  if (!stateFeatures.length) {
    console.error('No state features produced.');
    process.exit(1);
  }

  // Use d3-geo for path generation
  const d3 = await import('d3-geo');
  const projection = d3.geoAlbersUsa().translate([width/2, height/2]).scale(Math.min(width,height)*1.25*1.9);
  const pathGen = d3.geoPath(projection);

  const states = stateFeatures.map(f => {
    const d = pathGen(f);
    if (!d) return null;
    const [[minX,minY],[maxX,maxY]] = pathGen.bounds(f);
    const [cx,cy] = pathGen.centroid(f);
    const props = f.properties || {};
    return {
      id: props.id || props.fips || 'UNK',
      name: props.name || props.id || 'Unknown',
      fips: props.fips || '',
      path: d,
      bbox: [Number(minX.toFixed(2)), Number(minY.toFixed(2)), Number(maxX.toFixed(2)), Number(maxY.toFixed(2))],
      centroid: [Number(cx.toFixed(2)), Number(cy.toFixed(2))]
    };
  }).filter(Boolean).sort((a,b)=>a.id.localeCompare(b.id));

  const atlas = { width, height, projection: 'albersUsa', states };
  const banner = '// AUTO-GENERATED from block group dissolves.\n';
  const out = `${banner}import { Atlas } from '../types';\nexport const atlas: Atlas = ${JSON.stringify(atlas,null,2)};\n`;
  fs.writeFileSync(outFile, out);
  console.log('Atlas written to', outFile, `(${states.length} states)`);
})();
