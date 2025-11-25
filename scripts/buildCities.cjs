#!/usr/bin/env node
/**
 * buildCities.cjs
 * Generate a cities (populated places) point overlay.
 * Supports three inputs:
 *  1) TIGER/Line populated place points (tl_YYYY_us_popplace.shp)
 *  2) TIGER/Line place polygons (tl_YYYY_us_place.shp) with --centroid
 *  3) Census Gazetteer Places (YYYY_Gaz_place_national.txt) pipe-delimited with INTPTLAT/INTPTLONG
 *
 * Example usage (TIGER populated place points):
 *   node scripts/buildCities.cjs \
 *     --input data/raw/tl_2023_us_popplace/tl_2023_us_popplace.shp \
 *     --out data/overlays/cities.generated.ts \
 *     --year 2023 --minpop 50000
 *
 * For place boundaries (polygons) and centroid extraction:
 *   node scripts/buildCities.cjs \
 *     --input data/raw/tl_2023_us_place/tl_2023_us_place.shp \
 *     --out data/overlays/cities.generated.ts \
 *     --year 2023 --centroid --minpop 50000
 *
 * Example usage (Gazetteer Places file):
 *   node scripts/buildCities.cjs \
 *     --input data/raw/places/2025_Gaz_place_national.txt \
 *     --out data/overlays/cities.generated.ts \
 *     --year 2025 --minpop 50000
 *
 * Notes:
 * - The TIGER/Line place shapefile does not include population. Provide a CSV with GEOID,population
 *   via --popcsv path/to/pop.csv (header required) to enable population filtering and sorting.
 * - If no population data is supplied, minpop is ignored and we fallback to feature count capping.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
let mapshaperApi = null; try { mapshaperApi = require('mapshaper'); } catch(_) {}

const args = process.argv.slice(2);
const arg={};
for(let i=0;i<args.length;i++){ if(args[i].startsWith('--')) arg[args[i].slice(2)] = (args[i+1] && !args[i+1].startsWith('--')) ? args[i+1] : true; }

const input = arg.input;
if(!input){ console.error('Missing --input (shp file)'); process.exit(1); }
const outFile = arg.out || 'data/overlays/cities.generated.ts';
const year = arg.year || '2023';
const wantCentroid = !!arg.centroid; // treat polygon boundaries as point features via centroid
const popCsvPath = arg.popcsv || 'data/raw/sub-est2024_8.csv'; // optional population join
const minPop = Number(arg.minpop || 0);
const allowMissingPopulation = !!arg['allow-missing-population'];
const limit = Number(arg.limit || 2500); // safety cap if no pop filter
const width = 975, height = 610;

if(!fs.existsSync(input)){ console.error('Input file not found', input); process.exit(1); }

const ALL_STATES = [
  ['AL','Alabama'], ['AK','Alaska'], ['AZ','Arizona'], ['AR','Arkansas'], ['CA','California'], ['CO','Colorado'], ['CT','Connecticut'], ['DE','Delaware'], ['DC','District of Columbia'],
  ['FL','Florida'], ['GA','Georgia'], ['HI','Hawaii'], ['ID','Idaho'], ['IL','Illinois'], ['IN','Indiana'], ['IA','Iowa'], ['KS','Kansas'],
  ['KY','Kentucky'], ['LA','Louisiana'], ['ME','Maine'], ['MD','Maryland'], ['MA','Massachusetts'], ['MI','Michigan'], ['MN','Minnesota'], ['MS','Mississippi'],
  ['MO','Missouri'], ['MT','Montana'], ['NE','Nebraska'], ['NV','Nevada'], ['NH','New Hampshire'], ['NJ','New Jersey'], ['NM','New Mexico'], ['NY','New York'],
  ['NC','North Carolina'], ['ND','North Dakota'], ['OH','Ohio'], ['OK','Oklahoma'], ['OR','Oregon'], ['PA','Pennsylvania'], ['RI', 'Rhode Island'], ['SC','South Carolina'], ['SD','South Dakota'],
  ['TN','Tennessee'], ['TX','Texas'], ['UT','Utah'], ['VT','Vermont'], ['VA','Virginia'], ['WA','Washington'], ['WV','West Virginia'], ['WI','Wisconsin'], ['WY','Wyoming']
];
const stateAbbrToName = new Map(ALL_STATES);
const stateNameToAbbr = new Map(ALL_STATES.map(([abbr, name]) => [name, abbr]));

// Load optional population CSV mapping GEOID -> population
let popMap = null;
const popCsvDir = 'data/raw/census-csv';

if (fs.existsSync(popCsvDir)) {
  const popFiles = fs.readdirSync(popCsvDir).filter(f => /\.csv$/i.test(f));
  if (popFiles.length > 0) {
    popMap = new Map();
    let header = null;
    let allRows = [];

    for (const file of popFiles) {
      const filePath = path.join(popCsvDir, file);
      const fileContent = fs.readFileSync(filePath, 'utf8').split(/\r?\n/).filter(Boolean);
      if (fileContent.length === 0) continue;

      if (!header) {
        header = fileContent[0];
      }
      allRows.push(...fileContent.slice(1));
    }

    if (header && allRows.length > 0) {
      const headerCols = header.split(',');
      const resolvePopIndex = (cols) => {
        const matches = cols
          .map((name, idx) => ({ name, idx, year: (() => {
            const match = name.match(/POPESTIMATE(\d{4})/i);
            return match ? Number(match[1]) : null;
          })() }))
          .filter((entry) => /popestimate/i.test(entry.name));
        if (matches.length) {
          matches.sort((a, b) => (a.year || 0) - (b.year || 0));
          return matches[matches.length - 1].idx;
        }
        return cols.findIndex((h) => /popestimate/i.test(h));
      };
      const geoidIdx = headerCols.findIndex(h => /geoid/i.test(h));
      const stateIdx = headerCols.findIndex(h => /^STATE/i.test(h));
      const placeIdx = headerCols.findIndex(h => /^PLACE/i.test(h));
      const nameIdx = headerCols.findIndex(h => /^NAME/i.test(h));
      const stnameIdx = headerCols.findIndex(h => /^STNAME/i.test(h));
      const popIdx = resolvePopIndex(headerCols);
  const sumlevIdx = headerCols.findIndex(h => /^SUMLEV$/i.test(h));

      if ((geoidIdx === -1 && (stateIdx === -1 || placeIdx === -1) && (nameIdx === -1 || stnameIdx === -1)) || popIdx === -1) {
        console.warn('Population CSV missing GEOID or POP header (or STATE+PLACE or NAME+STNAME); ignoring population data');
        popMap = null;
      } else {
        for (const row of allRows) {
          const cols = row.split(',');
          const sumlev = sumlevIdx !== -1 ? (cols[sumlevIdx] || '').trim() : null;
          if (sumlev && sumlev !== '162') continue;
          let key;
          if (geoidIdx !== -1) {
            key = (cols[geoidIdx] || '').trim();
          } else if (stateIdx !== -1 && placeIdx !== -1) {
            key = (cols[stateIdx] || '').trim().padStart(2, '0') + (cols[placeIdx] || '').trim().padStart(5, '0');
          } else {
            key = `${(cols[stnameIdx] || '').trim()}-${(cols[nameIdx] || '').trim()}`;
          }
          const p = Number(cols[popIdx]);
          if (key && !isNaN(p)) {
            const prev = popMap.get(key);
            if (typeof prev !== 'number' || p > prev) {
              popMap.set(key, p);
            }
          }
        }
        console.log('Loaded population rows from', popFiles.length, 'files:', popMap.size);
      }
    }
  }
} else if (popCsvPath && fs.existsSync(popCsvPath)) {
  // Fallback to single file if directory doesn't exist but old path does
  if(!fs.existsSync(popCsvPath)) { console.warn('Population CSV path does not exist, ignoring:', popCsvPath); }
  else {
    popMap = new Map();
    const raw = fs.readFileSync(popCsvPath,'utf8').split(/\r?\n/).filter(Boolean);
    const header = raw[0].split(',');
    const resolvePopIndex = (cols) => {
      const matches = cols
        .map((name, idx) => ({ name, idx, year: (() => {
          const match = name.match(/POPESTIMATE(\d{4})/i);
          return match ? Number(match[1]) : null;
        })() }))
        .filter((entry) => /popestimate/i.test(entry.name));
      if (matches.length) {
        matches.sort((a, b) => (a.year || 0) - (b.year || 0));
        return matches[matches.length - 1].idx;
      }
      return cols.findIndex((h) => /popestimate/i.test(h));
    };
    const geoidIdx = header.findIndex(h=>/geoid/i.test(h));
    const stateIdx = header.findIndex(h=>/^STATE/i.test(h));
    const placeIdx = header.findIndex(h=>/^PLACE/i.test(h));
    const nameIdx = header.findIndex(h=>/^NAME/i.test(h));
    const stnameIdx = header.findIndex(h=>/^STNAME/i.test(h));
    const popIdx = resolvePopIndex(header);
  const sumlevIdx = header.findIndex(h=>/^SUMLEV$/i.test(h));
    if((geoidIdx===-1 && (stateIdx===-1 || placeIdx===-1) && (nameIdx===-1 || stnameIdx===-1)) || popIdx===-1){ console.warn('Population CSV missing GEOID or POP header (or STATE+PLACE or NAME+STNAME); ignoring population data'); popMap=null; }
    else {
      for(let i=1;i<raw.length;i++){
        const cols = raw[i].split(',');
        const sumlev = sumlevIdx !== -1 ? (cols[sumlevIdx] || '').trim() : null;
        if(sumlev && sumlev !== '162') continue;
        let key;
        if (geoidIdx !== -1) {
          key = (cols[geoidIdx] || '').trim();
        } else if (stateIdx !== -1 && placeIdx !== -1) {
          key = (cols[stateIdx] || '').trim().padStart(2,'0') + (cols[placeIdx] || '').trim().padStart(5,'0');
        } else {
          key = `${(cols[stnameIdx] || '').trim()}-${(cols[nameIdx] || '').trim()}`;
        }
        const p = Number(cols[popIdx]);
        if(key && !isNaN(p)){
          const prev = popMap.get(key);
          if(typeof prev !== 'number' || p > prev){
            popMap.set(key, p);
          }
        }
      }
      console.log('Loaded population rows:', popMap.size);
    }
  }
}

// Detect input type: Gazetteer .txt vs Shapefile .shp
const isGazetteer = /\.txt$/i.test(input) || /gazetteer|gaz_|_gaz_/i.test(input);
// Prepare in-memory inputs for optional mapshaper API fallback (for shapefiles only)
let msInputs = null, shpName = null, fileBase = null;
if(!isGazetteer){
  const base = input.replace(/\.shp$/i,'');
  const dir = path.dirname(base);
  fileBase = path.basename(base);
  const parts = ['.shp','.shx','.dbf','.prj'].filter(ext => fs.existsSync(path.join(dir, fileBase + ext)));
  msInputs = {};
  for(const ext of parts){ msInputs[fileBase + ext] = fs.readFileSync(path.join(dir, fileBase + ext)); }
  shpName = Object.keys(msInputs).find(n=>/\.shp$/i.test(n));
}

(async () => {
  let geojsonStr = null;
  let gazRows = null;

  if (isGazetteer) {
    // Parse Gazetteer pipe-delimited text with headers including INTPTLAT/INTPTLONG.
    // Gazetteer file does NOT include population, so we optionally inject a curated major city list later.
    const raw = fs.readFileSync(input, 'utf8').split(/\r?\n/).filter(Boolean);
    if (!raw.length) { console.error('Gazetteer file is empty:', input); process.exit(1); }
    const headerLine = raw[0];
    const delim = headerLine.includes('|') ? '|' : '\t';
    const headers = headerLine.split(delim).map(h => h.trim());
    const idx = (nameRegex) => headers.findIndex(h => nameRegex.test(h));
    const nameIdx = idx(/^(NAME|NAMELSAD)$/i);
    const geoidIdx = idx(/^GEOIDF?Q?$/i) !== -1 ? idx(/^GEOIDF?Q?$/i) : idx(/^GEOID$/i);
    const latIdx = idx(/^INTPTLAT$/i);
    const lonIdx = idx(/^INTPTLONG$/i);
    if (latIdx === -1 || lonIdx === -1) {
      console.error('Gazetteer missing INTPTLAT/INTPTLONG headers. Found:', headers.join(','));
      process.exit(1);
    }
    gazRows = raw.slice(1).map(line => {
      const cols = line.split(delim).map(s => s.trim());
      // Some Gazetteer rows begin with leading delimiter when first column is empty; normalize length
      while (cols.length < headers.length) cols.push('');
      const name = nameIdx !== -1 ? cols[nameIdx] : '';
      const gid = geoidIdx !== -1 ? cols[geoidIdx] : '';
      const lat = Number(cols[latIdx]);
      const lon = Number(cols[lonIdx]);
      if (isNaN(lat) || isNaN(lon)) return null;
      return { id: gid || name, name: name || gid || 'Place', lat, lon };
    }).filter(Boolean);
    // If no population CSV supplied, we still want the major US cities present even if we cap early rows.
    const majorCityNames = [
      'New York city','Los Angeles city','Chicago city','Houston city','Phoenix city',
      'Philadelphia city','San Antonio city','San Diego city','Dallas city','San Jose city'
    ];
    // We'll allow selecting these later even if not in the capped feature slice by keeping full gazRows reference.
  } else {
    // Shapefile path: Attempt CLI first (supports spaces in path)
    try {
    const tmpOut = path.join(process.cwd(), 'tmp_cities_out.geojson');
    // If centroiding polygons, ask mapshaper to emit point geometries directly
    const centroidCmd = wantCentroid ? ' -points centroid ' : ' ';
    const cli = `npx mapshaper -i "${input}"${centroidCmd}-o format=geojson precision=0.0001 ${tmpOut}`;
      if(process.env.DEBUG_CITIES) console.log('[buildCities] CLI:', cli);
      execSync(cli, { stdio:'inherit' });
      if(fs.existsSync(tmpOut)) { geojsonStr = fs.readFileSync(tmpOut,'utf8'); fs.unlinkSync(tmpOut); }
    } catch(e) { console.warn('[buildCities] CLI failed, trying API fallback:', e.message); }
    if(!geojsonStr && mapshaperApi && msInputs && shpName){
      try {
        geojsonStr = await new Promise((resolve,reject)=>{
          const cmd = `-i ${shpName} -o format=geojson out.geojson`;
          mapshaperApi.runCommands(cmd, msInputs, (err, outputs)=>{
            if(err || !outputs) return reject(err||new Error('No outputs')); const k=Object.keys(outputs).find(k=>/out\.geojson$/i.test(k)); if(!k) return reject(new Error('Missing out.geojson')); resolve(outputs[k].toString('utf8')); });
        });
      } catch(e){ console.error('[buildCities] API fallback failed:', e.message); }
    }
    if(!geojsonStr){ console.error('Failed to read geometry for cities (shapefile).'); process.exit(1); }
  }

  const d3 = await import('d3-geo');
  let projection = d3.geoAlbersUsa();
  try {
    const projPath = path.join('data','atlasProjection.json');
    if(fs.existsSync(projPath)){
      const params = JSON.parse(fs.readFileSync(projPath,'utf8'));
      if(params.scale && params.translate) projection = d3.geoAlbersUsa().scale(params.scale).translate(params.translate);
    }
  } catch(e){ /* projection fallback not critical for point projection */ }

  let features;
  if (isGazetteer) {
    features = (gazRows || []).map((r, i) => {
      const projected = projection([r.lon, r.lat]);
      if (!projected) return null;
      const pop = popMap ? popMap.get(r.id) || null : null;
      return {
        id: r.id || String(i),
        name: r.name || `City ${i+1}`,
        x: Number(projected[0].toFixed(2)),
        y: Number(projected[1].toFixed(2)),
        lon: Number(r.lon.toFixed(4)),
        lat: Number(r.lat.toFixed(4)),
        population: pop
      };
    }).filter(Boolean);
  } else {
    const geo = JSON.parse(geojsonStr);
    // Convert features to point features (either original point geometry, or centroid of polygon)
    function featureToPoint(f){
      if(!f) return null;
      if(f.geometry && f.geometry.type === 'Point') return f.geometry.coordinates;
      // For polygons/multipolygons compute centroid via d3.geoCentroid
      try { return d3.geoCentroid(f); } catch { return null; }
    }
    features = (geo.features || [])
      .map((f, i) => {
        const coords = featureToPoint(f);
        if (!coords) return null;
        const [lon, lat] = coords;
        const projected = projection([lon, lat]);
        if (!projected) return null;
        const geoid = (f.properties && (f.properties.GEOID || f.properties.PLACEFP || f.properties.GNIS_ID)) || String(i);
        const name = (f.properties && (f.properties.NAME || f.properties.NAMELSAD)) || `City ${i + 1}`;
        const stateFips = f.properties && f.properties.STATEFP;
        const stateName = stateFips ? stateAbbrToName.get(stateFips) : null;
        
        let pop = null;
        if (popMap) {
          if (popMap.has(geoid)) {
            pop = popMap.get(geoid);
          } else if (stateName) {
            const key = `${stateName}-${name}`;
            if (popMap.has(key)) {
              pop = popMap.get(key);
            }
          }
        }
        
        return {
          id: geoid,
          name,
          x: Number(projected[0].toFixed(2)),
          y: Number(projected[1].toFixed(2)),
          lon: Number(lon.toFixed(4)),
          lat: Number(lat.toFixed(4)),
          population: pop
        };
      })
      .filter(Boolean);
  }

  // Filter & prioritize
  if(popMap && !allowMissingPopulation){
    const before = features.length;
    features = features.filter(f => typeof f.population === 'number' && !Number.isNaN(f.population));
    const dropped = before - features.length;
    if(dropped > 0){
      console.warn(`[buildCities] Dropped ${dropped.toLocaleString('en-US')} features missing population data (use --allow-missing-population to keep them).`);
    }
  }
  if(popMap && minPop > 0){ features = features.filter(f => (f.population||0) >= minPop); }
  if(!popMap && limit && features.length > limit){
    // Preserve original truncated slice
    let base = features.slice(0, limit);
    // Ensure inclusion of curated major cities if available in full feature set
    const majorNames = new Set(['New York city','Los Angeles city','Chicago city','Houston city','Phoenix city','Philadelphia city','San Antonio city','San Diego city','Dallas city','San Jose city']);
    const present = new Set(base.map(f=>f.name));
    for(const f of features){
      if(base.length >= limit + majorNames.size) break; // avoid runaway growth
      if(majorNames.has(f.name) && !present.has(f.name)) { base.push(f); present.add(f.name); }
    }
    features = base;
  }
  // Optional sorting by population desc if available
  if(popMap){ features.sort((a,b)=>(b.population||0)-(a.population||0)); }

  let projScale=null, projTranslate=null;
  try { projScale = projection.scale(); } catch {}
  try { projTranslate = projection.translate(); } catch {}

  const layer = { key:'cities', label:`Cities (${year})`, features, source:'Census TIGER/Line', stroke:'#ef4444', fill:'rgba(239,68,68,0.25)', projectionParams:{ scale: projScale, translate: projTranslate } };
  const banner='// AUTO-GENERATED by buildCities.cjs. DO NOT EDIT.\n';
  const out = `${banner}import type { CityLayer } from '../../types';\nexport const citiesLayer: CityLayer = ${JSON.stringify(layer,null,2)};\nexport default citiesLayer;\n`;
  fs.writeFileSync(outFile, out);
  console.log('Cities overlay written', outFile, features.length,'features');
})();
