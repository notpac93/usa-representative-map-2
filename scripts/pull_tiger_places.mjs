import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BASE_URL = 'https://www2.census.gov/geo/tiger/TIGER2024/PLACE/';
const DEST_DIR = path.resolve(__dirname, '../data/raw/tiger-places');
const EXTRACT_DIR = path.resolve(__dirname, '../data/raw/tiger-places-extracted');

// All state FIPS codes (excluding territories for now, can add later)
const STATE_FIPS = [
    '01', '02', '04', '05', '06', '08', '09', '10', '11', '12',
    '13', '15', '16', '17', '18', '19', '20', '21', '22', '23',
    '24', '25', '26', '27', '28', '29', '30', '31', '32', '33',
    '34', '35', '36', '37', '38', '39', '40', '41', '42', '44',
    '45', '46', '47', '48', '49', '50', '51', '53', '54', '55', '56'
];

if (!fs.existsSync(DEST_DIR)) {
    fs.mkdirSync(DEST_DIR, { recursive: true });
}

if (!fs.existsSync(EXTRACT_DIR)) {
    fs.mkdirSync(EXTRACT_DIR, { recursive: true });
}

async function downloadFile(url, dest) {
    if (fs.existsSync(dest)) {
        console.log(`[skip] ${dest} already exists`);
        return true;
    }

    console.log(`[downloading] ${url}`);
    return new Promise((resolve, reject) => {
        const file = fs.createWriteStream(dest);
        https.get(url, (res) => {
            if (res.statusCode !== 200) {
                reject(new Error(`Failed to download ${url}: ${res.statusCode}`));
                return;
            }
            res.pipe(file);
            file.on('finish', () => {
                file.close();
                resolve(true);
            });
        }).on('error', (err) => {
            fs.unlink(dest, () => { });
            reject(err);
        });
    });
}

async function extractZip(zipPath, extractTo) {
    console.log(`[extracting] ${path.basename(zipPath)}`);
    try {
        await execAsync(`unzip -o "${zipPath}" -d "${extractTo}"`);
        return true;
    } catch (error) {
        console.error(`Error extracting ${zipPath}:`, error.message);
        return false;
    }
}

async function run() {
    console.log(`Downloading ${STATE_FIPS.length} state Places shapefiles...`);

    for (const fips of STATE_FIPS) {
        const filename = `tl_2024_${fips}_place.zip`;
        const url = `${BASE_URL}${filename}`;
        const dest = path.join(DEST_DIR, filename);

        try {
            await downloadFile(url, dest);

            // Extract the shapefile
            const stateExtractDir = path.join(EXTRACT_DIR, fips);
            if (!fs.existsSync(stateExtractDir)) {
                fs.mkdirSync(stateExtractDir, { recursive: true });
            }
            await extractZip(dest, stateExtractDir);

        } catch (error) {
            console.error(`Error processing FIPS ${fips}:`, error.message);
        }
    }

    console.log('Download and extraction complete!');
    console.log(`Shapefiles extracted to: ${EXTRACT_DIR}`);
}

run().catch(console.error);
