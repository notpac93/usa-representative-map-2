#!/usr/bin/env node
/**
 * buildAtlasFromCounties.cjs
 * Generate `atlas.generated.ts` state geometries by dissolving a counties shapefile.
 * This guarantees that state boundaries share the exact same simplified arcs as the
 * counties overlay (when the same simplification percent is used), eliminating
 * coastal / boundary drift caused by independently simplified datasets.
 *
 * Usage:
 *   node scripts/buildAtlasFromCounties.cjs \
 *     --input data/raw/cb_2023_us_state_5m/US\ County/cb_2018_us_county_500k.shp \
 *     --out data/atlas.generated.ts \
 *     --simplify 8
 *
 * Notes:
 *  - If `data/atlasProjection.json` (canonical projection) exists, its scale/translate
 *    are reused. Otherwise we fit a fresh geoAlbersUsa to the dissolved states.
 *  - For perfect alignment with the Counties overlay, set the counties overlay build
 *    simplification percent to match `--simplify` here.
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const args = process.argv.slice(2);
const arg = {};
for (let i = 0; i < args.length; i++) {
  if (args[i].startsWith('--')) {
    const key = args[i].replace(/^--/, '');
    const val = args[i+1] && !args[i+1].startsWith('--') ? args[i+1] : true;
    arg[key] = val;
  }
}

const input = arg.input;
if (!input) {
  console.error('Missing --input counties shapefile');
  process.exit(1);
}
if (!fs.existsSync(input)) {
  console.error('Input shapefile not found:', input);
  process.exit(1);
}

const simplify = Number(arg.simplify || 8);
const outFile = arg.out || 'data/atlas.generated.ts';
const width = Number(arg.width || 975);
const height = Number(arg.height || 610);
const reuseProjection = !!arg['reuse-projection'];

// Static mapping STATEFP (FIPS) -> STUSPS abbreviation (Census standard)
// Source: https://www2.census.gov/geo/docs/reference/state.txt (trimmed)
const STATE_FIPS_TO_STUSPS = {
  '01':'AL','02':'AK','04':'AZ','05':'AR','06':'CA','08':'CO','09':'CT','10':'DE','11':'DC','12':'FL','13':'GA',
  '15':'HI','16':'ID','17':'IL','18':'IN','19':'IA','20':'KS','21':'KY','22':'LA','23':'ME','24':'MD','25':'MA',
  '26':'MI','27':'MN','28':'MS','29':'MO','30':'MT','31':'NE','32':'NV','33':'NH','34':'NJ','35':'NM','36':'NY',
  '37':'NC','38':'ND','39':'OH','40':'OK','41':'OR','42':'PA','44':'RI','45':'SC','46':'SD','47':'TN','48':'TX',
  '49':'UT','50':'VT','51':'VA','53':'WA','54':'WV','55':'WI','56':'WY','60':'AS','66':'GU','69':'MP','72':'PR','78':'VI'
};
const STATE_ABBR_TO_NAME = {
  AL:'Alabama', AK:'Alaska', AZ:'Arizona', AR:'Arkansas', CA:'California', CO:'Colorado', CT:'Connecticut', DE:'Delaware', DC:'District of Columbia', FL:'Florida', GA:'Georgia',
  HI:'Hawaii', ID:'Idaho', IL:'Illinois', IN:'Indiana', IA:'Iowa', KS:'Kansas', KY:'Kentucky', LA:'Louisiana', ME:'Maine', MD:'Maryland', MA:'Massachusetts',
  MI:'Michigan', MN:'Minnesota', MS:'Mississippi', MO:'Missouri', MT:'Montana', NE:'Nebraska', NV:'Nevada', NH:'New Hampshire', NJ:'New Jersey', NM:'New Mexico', NY:'New York',
  NC:'North Carolina', ND:'North Dakota', OH:'Ohio', OK:'Oklahoma', OR:'Oregon', PA:'Pennsylvania', RI:'Rhode Island', SC:'South Carolina', SD:'South Dakota', TN:'Tennessee', TX:'Texas',
  UT:'Utah', VT:'Vermont', VA:'Virginia', WA:'Washington', WV:'West Virginia', WI:'Wisconsin', WY:'Wyoming', AS:'American Samoa', GU:'Guam', MP:'Northern Mariana Islands', PR:'Puerto Rico', VI:'U.S. Virgin Islands'
};

(async () => {
  // Create dissolved states (after simplifying counties so shared arcs remain)
  const tmpStates = '.tmp_states_from_counties.geojson';
  try {
    const cli = `npx mapshaper -i "${input}" -simplify visvalingam ${simplify}% keep-shapes -dissolve STATEFP copy-fields=STATEFP -o format=geojson precision=0.0001 ${tmpStates}`;
    execSync(cli, { stdio: 'inherit' });
  } catch (e) {
    console.error('[buildAtlasFromCounties] mapshaper failed:', e.message);
    process.exit(1);
  }
  if (!fs.existsSync(tmpStates)) {
    console.error('Failed to produce dissolved states GeoJSON');
    process.exit(1);
  }
  const geo = JSON.parse(fs.readFileSync(tmpStates, 'utf8'));
  fs.unlinkSync(tmpStates);
  if (!geo.features) {
    console.error('Unexpected dissolved GeoJSON structure (missing features)');
    process.exit(1);
  }

  const d3 = await import('d3-geo');
  let projection;
  if (reuseProjection) {
    try {
      const prev = JSON.parse(fs.readFileSync('data/atlasProjection.json', 'utf8'));
      if (prev.scale && prev.translate) {
        projection = d3.geoAlbersUsa().scale(prev.scale).translate(prev.translate);
        console.log('[buildAtlasFromCounties] Reused canonical projection');
      } else {
        projection = d3.geoAlbersUsa();
        projection.fitSize([width, height], geo);
      }
    } catch (e) {
      projection = d3.geoAlbersUsa();
      projection.fitSize([width, height], geo);
    }
  } else {
    projection = d3.geoAlbersUsa();
    projection.fitSize([width, height], geo);
  }
  const pathGen = d3.geoPath(projection);

  // Rectangle artifact filter (same heuristic as primary atlas builder)
  const RECT_SUBPATH_RE = /^M[0-9.+-]+,[0-9.+-]+L[0-9.+-]+,[0-9.+-]+L[0-9.+-]+,[0-9.+-]+L[0-9.+-]+,[0-9.+-]+Z$/;
  function isAxisAlignedRect(p){
    p = p.trim();
    if(!RECT_SUBPATH_RE.test(p)) return false;
    const coords = [...p.matchAll(/[ML]([0-9.+-]+),([0-9.+-]+)/g)].map(m=>[Number(m[1]),Number(m[2])]);
    if(!(coords.length===4 || coords.length===5)) return false;
    const [x1,y1] = coords[0];
    const [x2,y2] = coords[1];
    const [x3,y3] = coords[2];
    const [x4,y4] = coords[3];
    return x1===x4 && y1===y2 && x2===x3 && y3===y4 && x1!==x2 && y1!==y3;
  }
  function cleanPath(d){
    if(!d) return d;
    const parts = d.split('M').filter(Boolean).map(p=>'M'+p);
    const filtered = parts.filter(p=>!isAxisAlignedRect(p));
    const seen = new Set();
    const uniq=[]; for(const p of filtered){ if(!seen.has(p)){ seen.add(p); uniq.push(p);} }
    return uniq.join('');
  }

  function pathBounds(d){
    let minX= Infinity, minY= Infinity, maxX=-Infinity, maxY=-Infinity; let m; const re=/[ML](-?[0-9]+(?:\.[0-9]+)?),(-?[0-9]+(?:\.[0-9]+)?)/g;
    while((m=re.exec(d))){ const x=+m[1], y=+m[2]; if(x<minX)minX=x; if(x>maxX)maxX=x; if(y<minY)minY=y; if(y>maxY)maxY=y; }
    if(minX===Infinity) return [0,0,0,0];
    return [Number(minX.toFixed(2)),Number(minY.toFixed(2)),Number(maxX.toFixed(2)),Number(maxY.toFixed(2))];
  }
  function pathCentroid(b){ const [a,bY,c,d]=b; return [Number(((a+c)/2).toFixed(2)), Number(((bY+d)/2).toFixed(2))]; }

  const states = geo.features.map(f => {
    const props = f.properties || {};
    const fips = (props.STATEFP || props.STATE || props.GEOID || '').toString().padStart(2,'0');
    const id = STATE_FIPS_TO_STUSPS[fips] || fips;
    const name = STATE_ABBR_TO_NAME[id] || id;
    let d = pathGen(f);
    d = cleanPath(d);
    if(!d) return null;
    const bbox = pathBounds(d);
    const centroid = pathCentroid(bbox);
    return { id, name, fips, path: d, bbox, centroid };
  }).filter(Boolean).sort((a,b)=>a.id.localeCompare(b.id));

  let projScale=null, projTranslate=null;
  try { if (typeof projection.scale === 'function') projScale = projection.scale(); } catch {}
  try { if (typeof projection.translate === 'function') projTranslate = projection.translate(); } catch {}

  const atlas = { width, height, projection: 'albersUsa', states, projectionParams: { scale: projScale, translate: projTranslate } };
  const banner='// THIS FILE IS AUTO-GENERATED (buildAtlasFromCounties). DO NOT EDIT.\n';
  const out = `${banner}import { Atlas } from '../types';\nexport const atlas: Atlas = ${JSON.stringify(atlas,null,2)};\n`;
  fs.writeFileSync(outFile, out);
  try {
    if (!reuseProjection) {
      fs.writeFileSync('data/atlasProjection.json', JSON.stringify({ scale: projScale, translate: projTranslate, width, height }, null, 2));
    }
  } catch (e) { console.warn('[buildAtlasFromCounties] Could not write atlasProjection.json:', e.message); }
  console.log('[buildAtlasFromCounties] Atlas written', outFile, `(${states.length} features)`);
})();
