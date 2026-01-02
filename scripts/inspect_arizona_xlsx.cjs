const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');

const XLSX_URL = 'https://azleague.org/DocumentCenter/View/1599/CITY_AND_TOWN_DATA';
const TEMP_FILE = path.resolve(__dirname, '../data/temp_arizona_data.xlsx');

async function downloadXlsx() {
    const { default: fetch } = await import('node-fetch').catch(() => ({ default: global.fetch }));
    // Fallback to global fetch if node-fetch isn't available, but node 18+ has fetch. 
    // Actually, let's just use global fetch since we are in a modern node environment (likely).

    console.log(`Downloading XLSX from ${XLSX_URL}...`);
    const response = await fetch(XLSX_URL);
    if (!response.ok) {
        throw new Error(`Failed to fetch ${XLSX_URL}: ${response.statusText}`);
    }
    const arrayBuffer = await response.arrayBuffer();
    fs.writeFileSync(TEMP_FILE, Buffer.from(arrayBuffer));
    console.log(`Saved to ${TEMP_FILE}`);
}

async function inspect() {
    await downloadXlsx();

    const workbook = xlsx.readFile(TEMP_FILE);
    const sheetName = workbook.SheetNames[0];
    console.log(`Sheets: ${workbook.SheetNames.join(', ')}`);
    console.log(`Inspecting first sheet: ${sheetName}`);

    const sheet = workbook.Sheets[sheetName];
    const jsonData = xlsx.utils.sheet_to_json(sheet, { header: 1, defval: '' }); // header: 1 returns array of arrays

    console.log('--- First 10 rows ---');
    jsonData.slice(0, 10).forEach((row, i) => {
        console.log(`Row ${i}:`, JSON.stringify(row));
    });
}

inspect().catch(console.error);
