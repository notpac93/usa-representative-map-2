const fs = require('fs');
const XLSX = require('xlsx');

async function inspect() {
    const url = 'https://azleague.org/DocumentCenter/View/1599/CITY_AND_TOWN_DATA';
    console.log(`Fetching from ${url}...`);

    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`HTTP ${response.status} - ${response.statusText}`);

        const buffer = await response.arrayBuffer();
        const workbook = XLSX.read(Buffer.from(buffer), { type: 'buffer' });

        console.log('Sheets:', workbook.SheetNames);

        for (const name of workbook.SheetNames) {
            console.log(`\n--- Sheet: ${name} ---`);
            const sheet = workbook.Sheets[name];
            const rows = XLSX.utils.sheet_to_json(sheet, { header: 1 }).slice(0, 5);
            rows.forEach((r, i) => console.log(`Row ${i}:`, r));
        }

    } catch (err) {
        console.error('Error:', err);
    }
}

inspect();
