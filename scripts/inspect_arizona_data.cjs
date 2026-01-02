const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');

async function inspect() {
    const url = 'https://azleague.org/DocumentCenter/View/1599/CITY_AND_TOWN_DATA';
    console.log(`Fetching ${url}...`);

    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`Failed to fetch: ${response.statusText}`);

        const arrayBuffer = await response.arrayBuffer();
        const buffer = Buffer.from(arrayBuffer);

        const workbook = XLSX.read(buffer, { type: 'buffer' });

        workbook.SheetNames.forEach(name => {
            console.log(`\n--- Sheet: ${name} ---`);
            const sheet = workbook.Sheets[name];
            const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });
            // Log first 5 non-empty rows
            const nonEmpty = data.filter(r => r.length > 0).slice(0, 5);
            nonEmpty.forEach((row, i) => console.log(`Row ${i}:`, JSON.stringify(row)));
        });

    } catch (error) {
        console.error('Error:', error);
    }
}

inspect();
