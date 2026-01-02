const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();

    // Alaska DCRA City Mayors Dataset
    const url = 'https://dcra-cdo-dcced.opendata.arcgis.com/datasets/city-mayors/explore?showTable=true';
    console.log(`Navigating to ${url}`);

    await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });

    // Wait for the table/grid
    try {
        await page.waitForSelector('tbody tr', { timeout: 30000 });
    } catch (e) {
        console.log("Row selector timeout. Dumping debug info...");
    }

    // Scroll to load all
    console.log("Scrolling table...");

    // Valid selectors for ArcGIS Hub tables
    // They often use virtual scrolling, so we must scroll the CONTAINER
    let previousCount = 0;

    for (let i = 0; i < 30; i++) {
        // 1. Try to scroll the tbody's parent (often the scroller)
        await page.evaluate(() => {
            const tbody = document.querySelector('tbody');
            if (tbody && tbody.parentElement) {
                tbody.parentElement.scrollTop = tbody.parentElement.scrollHeight;
            }
            // Also scroll window
            window.scrollTo(0, document.body.scrollHeight);
        });

        await page.keyboard.press('PageDown');

        await page.waitForTimeout(2000);

        const rowCount = await page.$$eval('tbody tr', rows => rows.length);
        process.stdout.write(`\rRows: ${rowCount} `);

        if (rowCount >= 160) break;
        if (rowCount === previousCount && i > 5) {
            // Try clicking "Load More" if it exists? 
            // Normally ArcGIS Hub is infinite scroll.
            break;
        }
        previousCount = rowCount;
    }
    console.log("");

    const mayors = await page.$$eval('tbody tr', rows => {
        return rows.map(r => {
            const cells = r.querySelectorAll('td');
            return Array.from(cells).map(c => c.innerText.trim());
        });
    });

    console.log(`Scraped ${mayors.length} rows.`);

    const cleaned = [];
    mayors.forEach(row => {
        let name = null;
        let cityRaw = null;

        // ArcGIS Hub Table Layout for "City Mayors"- 
        // Based on typical layout:
        // Col 1 (index 0): Community Name
        // Col 3 (index 2): Official Name
        // Let's implement fuzzy detection in case columns shift

        if (row.length >= 3) {
            cityRaw = row[0]; // Community Name
            name = row[2]; // Official Name
        }

        if (cityRaw && name && name !== "" && cityRaw !== "") {
            let city = cityRaw;
            // Normalize
            city = city.replace(/, Municipality of/i, '')
                .replace(/, City and Borough of/i, '')
                .replace(/, City of/i, '')
                .replace(/ City/i, '')
                .replace(/, City/i, '')
                .trim();

            if (!city.endsWith(", AK")) city = `${city}, AK`;

            cleaned.push({
                name: name,
                city: city,
                originalCity: cityRaw,
                detailsUrl: url,
                party: "Nonpartisan",
                photoUrl: null
            });
        }
    });

    const outputPath = path.join(__dirname, '../data/mayors_ak_full.json');
    fs.writeFileSync(outputPath, JSON.stringify(cleaned, null, 2));
    console.log(`Saved ${cleaned.length} records to ${outputPath}`);

    await browser.close();
})();
