const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');

const TEMP_FILE = path.resolve(__dirname, '../data/temp_arizona_data.xlsx');

async function inspectSheet(sheetName) {
    const workbook = xlsx.readFile(TEMP_FILE);
    console.log(`Inspecting sheet: ${sheetName}`);

    const sheet = workbook.Sheets[sheetName];
    if (!sheet) {
        console.log(`Sheet "${sheetName}" not found.`);
        return;
    }

    const jsonData = xlsx.utils.sheet_to_json(sheet, { header: 1, defval: '' });

    console.log('--- First 10 rows ---');
    jsonData.slice(0, 10).forEach((row, i) => {
        console.log(`Row ${i}:`, JSON.stringify(row));
    });
}

inspectSheet('Officer Appointments').catch(console.error);
