const fs = require('fs');
const path = require('path');

const RAW_FILE = path.join(__dirname, '../data/mayors_tx_full.json');
const ASSET_FILE = path.join(__dirname, '../assets/data/mayors.json');

try {
    const rawData = JSON.parse(fs.readFileSync(RAW_FILE, 'utf8'));
    const assetData = JSON.parse(fs.readFileSync(ASSET_FILE, 'utf8'));

    if (!assetData['TX']) {
        assetData['TX'] = [];
    }

    const oldTxMayors = assetData['TX'];

    // Create lookup for existing data (mainly for photos)
    const existingMap = new Map();
    oldTxMayors.forEach(m => {
        // Normalize city key for matching
        const key = m.city.toLowerCase().trim();
        existingMap.set(key, m);
    });

    console.log(`Loaded ${rawData.length} new mayors and ${oldTxMayors.length} existing mayors.`);

    // Merge
    const mergedList = rawData.map(newMayor => {
        const key = newMayor.city.toLowerCase().trim();
        const existing = existingMap.get(key);

        if (existing) {
            // Preserve rich data from existing source if available
            return {
                ...newMayor,
                photoUrl: existing.photoUrl || newMayor.photoUrl,
                // prefer existing detailsUrl if it is not generic
                detailsUrl: existing.detailsUrl || newMayor.detailsUrl,
                phone: existing.phone || newMayor.phone,
                email: existing.email || newMayor.email
            };
        }
        return newMayor;
    });

    // Replace TX entry
    assetData['TX'] = mergedList;

    fs.writeFileSync(ASSET_FILE, JSON.stringify(assetData, null, 2));
    console.log(`Successfully updated assets/data/mayors.json with ${mergedList.length} Texas mayors.`);

} catch (e) {
    console.error("Merge failed:", e);
}
