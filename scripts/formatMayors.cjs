const fs = require('fs');
const path = require('path');

const INPUT_FILE = path.resolve(__dirname, '../data/mayors_raw.json');
const OUTPUT_FILE = path.resolve(__dirname, '../assets/data/mayors.json');

// Map full state name to 2-letter code (matches Atlas IDs hopefully)
const STATE_LOOKUP = {
    'alabama': 'AL', 'alaska': 'AK', 'arizona': 'AZ', 'arkansas': 'AR', 'california': 'CA',
    'colorado': 'CO', 'connecticut': 'CT', 'delaware': 'DE', 'district of columbia': 'DC', 'florida': 'FL',
    'georgia': 'GA', 'hawaii': 'HI', 'idaho': 'ID', 'illinois': 'IL', 'indiana': 'IN',
    'iowa': 'IA', 'kansas': 'KS', 'kentucky': 'KY', 'louisiana': 'LA', 'maine': 'ME',
    'maryland': 'MD', 'massachusetts': 'MA', 'michigan': 'MI', 'minnesota': 'MN', 'mississippi': 'MS',
    'missouri': 'MO', 'montana': 'MT', 'nebraska': 'NE', 'nevada': 'NV', 'new hampshire': 'NH',
    'new jersey': 'NJ', 'new mexico': 'NM', 'new york': 'NY', 'north carolina': 'NC', 'north dakota': 'ND',
    'ohio': 'OH', 'oklahoma': 'OK', 'oregon': 'OR', 'pennsylvania': 'PA', 'rhode island': 'RI',
    'south carolina': 'SC', 'south dakota': 'SD', 'tennessee': 'TN', 'texas': 'TX', 'utah': 'UT',
    'vermont': 'VT', 'virginia': 'VA', 'washington': 'WA', 'west virginia': 'WV', 'wisconsin': 'WI',
    'wyoming': 'WY'
};

function normalizeStateKey(name) {
    return name.toLowerCase().trim();
}

function main() {
    if (!fs.existsSync(INPUT_FILE)) {
        console.error(`Input file not found: ${INPUT_FILE}`);
        process.exit(1);
    }

    const rawData = JSON.parse(fs.readFileSync(INPUT_FILE, 'utf8'));
    const groupedMayors = {};

    rawData.forEach(entry => {
        // rawData may contain duplicates or multiple entries per state if scraping logic wasn't perfect
        // but our current scraper pushes one object per state? No, looking at raw file:
        // [ { state: "Alabama", name: "...", ... }, { state: "Alabama", ... } ]
        // The scraper pushes individual mayor objects? 
        // Let's verify format.
        // "allMayors.push({ state, ... })" inside the loop for each mayor found.
        // Yes, a flat list of mayor objects.

        const stateKey = normalizeStateKey(entry.state);
        const stateId = STATE_LOOKUP[stateKey];

        if (!stateId) {
            console.warn(`Could not map state "${entry.state}" to ID. Skipping.`);
            return;
        }

        if (!groupedMayors[stateId]) {
            groupedMayors[stateId] = [];
        }

        groupedMayors[stateId].push({
            name: entry.name,
            photoUrl: entry.photoUrl,
            detailsUrl: entry.detailsUrl,
            city: entry.city,
            party: null, // Scraper doesn't parse this yet
            phone: null, // Scraper captured rawText, we could try to regex it better here
            email: null  // Same as above
        });
    });

    // Ensure output dir exists
    fs.mkdirSync(path.dirname(OUTPUT_FILE), { recursive: true });

    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(groupedMayors, null, 2));
    console.log(`Saved formatted mayors to ${OUTPUT_FILE}`);
}

main();
