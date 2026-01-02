const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '../data/CITY_AND_TOWN_DATA.xlsx');
const workbook = XLSX.readFile(filePath);

// It seems there are multiple sheets.
// "GENERAL DATA" was sheet 1.
// Mayors might be in "OFFICIALS" or similar sheet.

console.log("Sheet Names:", workbook.SheetNames);

let targetSheet = null;
let headers = null;
let headerRowIndex = -1;

// Look for a sheet with "Mayor" column
for (const name of workbook.SheetNames) {
    console.log(`Checking sheet: ${name}`);
    const sheet = workbook.Sheets[name];
    const rawData = XLSX.utils.sheet_to_json(sheet, { header: 1 });

    // Check first 10 rows for headers
    for (let r = 0; r < Math.min(10, rawData.length); r++) {
        const row = rawData[r];
        if (row && row.some(c => typeof c === 'string' && /Mayor/i.test(c))) {
            console.log(`Found Mayor column in sheet '${name}' at row ${r}`);
            targetSheet = rawData;
            headerRowIndex = r;
            headers = row;
            break;
        }
    }
    if (targetSheet) break;
}

if (!targetSheet) {
    console.error("Could not find a sheet with Mayor data.");
    // Fallback: Check if "GENERAL DATA" sheet implies one row per city and we can join with another sheet?
    // Or maybe the data is transposed?
    process.exit(1);
}

const cleaned = [];
// Iterate
for (let i = headerRowIndex + 1; i < targetSheet.length; i++) {
    const row = targetSheet[i];
    if (!row || row.length === 0) continue;

    // We need City Name.
    // In "GENERAL DATA" sheet, col 0 was NAME.
    // In the sheet we found, is there a Name?
    // Try to find "NAME" or "CITY" or "MUNICIPALITY" column
    const cityIdx = headers.findIndex(h => /NAME/i.test(h) || /CITY/i.test(h));
    const mayorIdx = headers.findIndex(h => /Mayor/i.test(h));

    if (cityIdx !== -1 && mayorIdx !== -1) {
        const cityVal = row[cityIdx];
        const mayorVal = row[mayorIdx];

        if (cityVal && mayorVal) {
            let city = cityVal.toString().trim();
            const prefixes = ["City of ", "Town of "];
            for (const p of prefixes) {
                if (city.startsWith(p)) {
                    city = city.substring(p.length);
                    break;
                }
            }
            if (!city.endsWith(", AZ")) city = `${city}, AZ`;

            // Clean Mayor Name (sometimes includes "Mayor" prefix if extracted weirdly)
            let mayorName = mayorVal.toString().trim();

            cleaned.push({
                name: mayorName,
                city: city,
                originalCity: cityVal,
                detailsUrl: "https://azleague.org/DocumentCenter/View/1599/CITY_AND_TOWN_DATA",
                party: "Nonpartisan",
                photoUrl: null
            });
        }
    }
}

const outputPath = path.join(__dirname, '../data/mayors_az_full.json');
fs.writeFileSync(outputPath, JSON.stringify(cleaned, null, 2));
console.log(`Saved ${cleaned.length} mayors to ${outputPath}`);
