const fs = require('fs');
const path = require('path');

const ARGS = process.argv.slice(2);
const STATE_CODE = ARGS[0] || 'AL'; // Default to AL if not provided for testing
const RAW_FILE_NAME = `mayors_${STATE_CODE.toLowerCase()}_full.json`;

const RAW_FILE = path.join(__dirname, `../data/${RAW_FILE_NAME}`);
const ASSET_FILE = path.join(__dirname, '../assets/data/mayors.json');

if (!fs.existsSync(RAW_FILE)) {
    console.error(`Error: Raw file ${RAW_FILE} not found.`);
    process.exit(1);
}

try {
    const rawData = JSON.parse(fs.readFileSync(RAW_FILE, 'utf8'));
    let assetData = {};

    if (fs.existsSync(ASSET_FILE)) {
        assetData = JSON.parse(fs.readFileSync(ASSET_FILE, 'utf8'));
    }

    if (!assetData[STATE_CODE]) {
        assetData[STATE_CODE] = [];
    }

    const oldStateMayors = assetData[STATE_CODE];

    // Create lookup for existing data (mainly for photos/phone/email)
    const existingMap = new Map();
    oldStateMayors.forEach(m => {
        const key = m.city.toLowerCase().trim();
        existingMap.set(key, m);
    });

    console.log(`[${STATE_CODE}] Merging ${rawData.length} new records with ${oldStateMayors.length} existing records.`);

    const mergedList = rawData.map(newMayor => {
        const key = newMayor.city.toLowerCase().trim();
        const existing = existingMap.get(key);

        if (existing) {
            // Keep rich data from existing if available
            return {
                ...newMayor,
                photoUrl: existing.photoUrl || newMayor.photoUrl,
                detailsUrl: existing.detailsUrl || newMayor.detailsUrl,
                phone: existing.phone || newMayor.phone,
                email: existing.email || newMayor.email
            };
        }
        return newMayor;
    });

    // Also include existing mayors that weren't in the scraped list (safety net)
    // e.g. if scraping failed for a major city but we had it manually
    oldStateMayors.forEach(existing => {
        // Naive check: if we scraped it, the city key matches my normalized scraping
        // But scraping normalization might differ slightly. 
        // For now, let's assume the scraped list is the source of truth for presence,
        // but if we fear losing data, we can add non-matched existing ones back.
        // However, "Mayor changed" is a common case, so purely adding back might keep old mayors.
        // Let's stick to the scraped list as the authority for *who* is mayor, 
        // assuming the scraper covers everyone.
    });

    // Replace State entry
    assetData[STATE_CODE] = mergedList;

    fs.writeFileSync(ASSET_FILE, JSON.stringify(assetData, null, 2));
    console.log(`Successfully updated ${ASSET_FILE} with ${mergedList.length} mayors for ${STATE_CODE}.`);

} catch (e) {
    console.error("Merge failed:", e);
}
