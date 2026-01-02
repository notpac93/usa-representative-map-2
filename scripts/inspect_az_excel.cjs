const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');

async function inspectExcel() {
    const url = 'https://azleague.org/DocumentCenter/View/1599/CITY_AND_TOWN_DATA';
    console.log(`Downloading Excel from ${url}...`);

    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`Failed to fetch: ${response.statusText}`);

        const arrayBuffer = await response.arrayBuffer();
        const buffer = Buffer.from(arrayBuffer);

        const workbook = XLSX.read(buffer, { type: 'buffer' });
        console.log('Sheet Names:', workbook.SheetNames);

        workbook.SheetNames.forEach(sheetName => {
            console.log(`\n\n=== Sheet: ${sheetName} ===`);
            const worksheet = workbook.Sheets[sheetName];
            const data = XLSX.utils.sheet_to_json(worksheet, { header: 1, range: 0, defval: null });
            data.slice(0, 5).forEach((row, index) => {
                console.log(`Row ${index}:`, JSON.stringify(row));
            });
        });

    } catch (error) {
        console.error('Error:', error);
    }
}

inspectExcel();
