const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const CENSUS_DIR = 'data/raw/census';
const OUT_FILE = 'data/atlas-highres.json';

const STATE_SHP = path.join(CENSUS_DIR, 'tl_2023_us_state/tl_2023_us_state.shp');
const COUNTY_SHP = path.join(CENSUS_DIR, 'tl_2023_us_county/tl_2023_us_county.shp');

console.log('[buildCensusAtlas] Starting high-res atlas build...');

if (!fs.existsSync(STATE_SHP)) {
    console.error('[buildCensusAtlas] Missing STATE shapefile:', STATE_SHP);
    process.exit(1);
}

try {
    // 1. Process States
    // Filter: Lower 48 + AK + HI + DC (FIPS codes or filtering by STUSPS)
    // TIGER data includes territories (GU, VI, MP, AS, PR). We might want to keep them or strictly 50 states.
    // Standard map usually 50 + DC.
    // STUSPS is the state abbreviation.

    // We'll keep it simple: Use mapshaper to convert to TopoJSON.
    // Simplification: TIGER is 1:1 (very detailed). We need SOME simplification for web performance, 
    // but much less than the national map. try 5% or "resolution=..."

    // Output structure:
    // { type: "Topology", objects: { states: { ... }, counties: { ... } } }

    const CMD = `
    npx mapshaper \
    -i "${STATE_SHP}" name=states \
    -filter "['AS','GU','MP','VI'].indexOf(STUSPS) == -1" \
    -simplify visvalingam 4% keep-shapes \
    -clean \
    -o "${OUT_FILE}" format=topojson precision=0.001
  `;
    // Note: Skipping counties for now to keep file size manageable for the first pass of "State View" geometry. 
    // If user wants high-res counties, we add "-i '${COUNTY_SHP}' name=counties" and merge or separate file.
    // The user asked for "perfect map zoom logics", implying detailed state outlines first.

    console.log('[buildCensusAtlas] Running mapshaper...');
    execSync(CMD, { stdio: 'inherit' });

    console.log(`[buildCensusAtlas] Wrote ${OUT_FILE}`);

} catch (err) {
    console.error('[buildCensusAtlas] Error:', err);
    process.exit(1);
}
