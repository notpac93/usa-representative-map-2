const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Base URL for TIGER 2023 data
const BASE_URL = 'https://www2.census.gov/geo/tiger/TIGER2023';

const DOWNLOAD_DIR = path.resolve(__dirname, '../data/raw/census');
if (!fs.existsSync(DOWNLOAD_DIR)) {
    fs.mkdirSync(DOWNLOAD_DIR, { recursive: true });
}

// Files to download
// Note: 'PLACE' and 'AREAWATER' are usually per-state. 
// For national 'perfect' state zoom, we typically need 'STATE' and 'COUNTY' at high res (1:500k or 1:100k doesn't exist, TIGER is 1:1).
// We'll stick to 'STATE' and 'COUNTY' (cb_2023_us_state_500k) for now, 
// but for 'perfect' zoom we might want the full 'tl_2023_us_state.zip'.

const FILES = [
    { dir: 'STATE', file: 'tl_2023_us_state.zip' },   // High res states
    { dir: 'COUNTY', file: 'tl_2023_us_county.zip' }, // High res counties
    // { dir: 'PLACE', file: 'tl_2023_<STATE_FIPS>_place.zip' } // We would need to loop states for this
];

async function download() {
    console.log('[downloadCensus] Starting download list to', DOWNLOAD_DIR);

    for (const item of FILES) {
        const url = `${BASE_URL}/${item.dir}/${item.file}`;
        const dest = path.join(DOWNLOAD_DIR, item.file);

        if (fs.existsSync(dest)) {
            console.log(`[skip] ${item.file} exists`);
            continue;
        }

        console.log(`[download] ${url} ...`);
        try {
            execSync(`curl -L -o "${dest}" "${url}"`, { stdio: 'inherit' });

            // Unzip
            const unzipDir = path.join(DOWNLOAD_DIR, path.basename(item.file, '.zip'));
            if (!fs.existsSync(unzipDir)) fs.mkdirSync(unzipDir);
            console.log(`[unzip] Extracting to ${unzipDir}...`);
            execSync(`unzip -o "${dest}" -d "${unzipDir}"`, { stdio: 'inherit' });

        } catch (err) {
            console.error(`[error] Failed to download/unzip ${item.file}:`, err.message);
        }
    }
}

download();
