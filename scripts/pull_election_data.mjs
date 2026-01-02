import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const URL = 'https://raw.githubusercontent.com/tonmcg/US_County_Level_Election_Results_08-24/master/2020_US_County_Level_Presidential_Results.csv';
const DEST_DIR = path.resolve(__dirname, '../data/raw');
const DEST_FILE = path.join(DEST_DIR, 'election_results.csv');

if (!fs.existsSync(DEST_DIR)) {
    fs.mkdirSync(DEST_DIR, { recursive: true });
}

console.log(`Downloading election data...`);
console.log(`Source: ${URL}`);
console.log(`Dest: ${DEST_FILE}`);

const file = fs.createWriteStream(DEST_FILE);

https.get(URL, (res) => {
    if (res.statusCode !== 200) {
        console.error(`Failed to download: ${res.statusCode}`);
        return;
    }
    res.pipe(file);
    file.on('finish', () => {
        file.close();
        console.log('Download complete.');
    });
}).on('error', (err) => {
    fs.unlink(DEST_FILE, () => { });
    console.error(`Error: ${err.message}`);
});
