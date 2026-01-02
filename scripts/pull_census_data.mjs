import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BASE_URL = 'https://www2.census.gov/programs-surveys/popest/datasets/2020-2024/';
const DOWNLOAD_ROOT = path.resolve(__dirname, '../data/raw/census-csv');

const CATEGORIES = ['cities', 'counties', 'metro', 'national', 'state'];

async function fetchUrl(url) {
    return new Promise((resolve, reject) => {
        https.get(url, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => resolve(data));
            res.on('error', reject);
        });
    });
}

async function downloadFile(url, dest) {
    if (fs.existsSync(dest)) {
        console.log(`[skip] ${dest} already exists`);
        return;
    }

    console.log(`[downloading] ${url} -> ${dest}`);
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
                resolve();
            });
        }).on('error', (err) => {
            fs.unlink(dest, () => { });
            reject(err);
        });
    });
}

function extractLinks(html) {
    const regex = /href="([^"]+)"/g;
    const links = [];
    let match;
    while ((match = regex.exec(html)) !== null) {
        links.push(match[1]);
    }
    return links;
}

async function processCategory(category) {
    const catUrl = `${BASE_URL}${category}/`;
    const catDir = path.join(DOWNLOAD_ROOT, category);

    if (!fs.existsSync(catDir)) fs.mkdirSync(catDir, { recursive: true });

    console.log(`Processing category: ${category}`);

    // For most categories, they have subfolders like 'totals/' or 'asrh/'
    // We'll look for CSVs in the main folder and one level deep in 'totals/'

    const mainHtml = await fetchUrl(catUrl);
    const links = extractLinks(mainHtml);

    // Find subfolders and CSVs
    for (const link of links) {
        if (link.endsWith('.csv')) {
            await downloadFile(`${catUrl}${link}`, path.join(catDir, link));
        } else if (link.endsWith('/') && (link === 'totals/' || link === 'asrh/')) {
            const subfolder = link.slice(0, -1);
            const subDir = path.join(catDir, subfolder);
            if (!fs.existsSync(subDir)) fs.mkdirSync(subDir, { recursive: true });

            const subUrl = `${catUrl}${link}`;
            const subHtml = await fetchUrl(subUrl);
            const subLinks = extractLinks(subHtml);

            for (const subLink of subLinks) {
                if (subLink.endsWith('.csv')) {
                    await downloadFile(`${subUrl}${subLink}`, path.join(subDir, subLink));
                }
            }
        }
    }
}

async function run() {
    const limit = process.argv.includes('--limit') ? parseInt(process.argv[process.argv.indexOf('--limit') + 1]) || 5 : Infinity;
    let count = 0;

    for (const category of CATEGORIES) {
        if (count >= limit) break;
        await processCategory(category);
        count++;
    }

    console.log('Census data ingestion complete.');
}

run().catch(console.error);
