const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
    const browser = await chromium.launch({ headless: true });
    // Use a context to block images/css for speed, as we are visiting 460 pages
    const context = await browser.newContext({
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    });
    const page = await context.newPage();

    const url = 'https://www.armunileague.org/member-directory/';
    console.log(`Navigating to ${url}...`);

    await page.goto(url, { waitUntil: 'load', timeout: 60000 });
    // IMPORTANT: Wait for the initial table load. 
    // "No matching records found" usually appears briefly or if filter is wrong.
    await page.waitForSelector('table.dataTable tbody tr td', { timeout: 10000 });
    // Wait for at least one record or "No matching" text.

    // Try selecting "Mayor" from the global search might NOT work if it's strictly keyword matching?
    // Let's scrape ALL 6000 entries and filter in memory? 
    // Or filter via column specific search if available?
    // The browser agent interaction showed a "Position" column. 
    // The global search usually works.
    // Maybe "Mayor" is case sensitive or needs wait?

    // Attempt 2: Scrape everything. 
    // There are 6000 entires. Paginating 100 at a time = 60 pages. Doable.

    console.log("Expanding table length to 100...");
    try {
        const select = await page.$('select[name$="_length"]');
        if (select) {
            await select.selectOption('100');
            await page.waitForTimeout(3000);
        }
    } catch (e) { }

    let allMayors = [];
    let hasNext = true;
    let pageNum = 1;

    const headers = await page.$$eval('table.dataTable thead th', ths => ths.map(t => t.innerText));
    const positionIndex = headers.findIndex(h => h.includes('Position'));
    const cityIndex = headers.findIndex(h => h.includes('City'));
    const nameIndex = headers.findIndex(h => h.includes('Name'));

    console.log("Headers:", headers);

    while (hasNext) {
        const rows = await page.$$eval('table.dataTable tbody tr', (trs, { cityIndex, nameIndex, positionIndex }) => {
            return trs.map(tr => {
                const cells = tr.querySelectorAll('td');
                if (cells.length < 3) return null;

                // If it's the "No matching records found" row, skip
                if (cells.length === 1) return null;

                const cIdx = cityIndex > -1 ? cityIndex : 0;
                const nIdx = nameIndex > -1 ? nameIndex : 1;
                const pIdx = positionIndex > -1 ? positionIndex : 2;

                return {
                    cityRaw: cells[cIdx].innerText.trim(),
                    name: cells[nIdx].innerText.trim(),
                    position: cells[pIdx].innerText.trim(),
                    // Filter here or later
                    isValid: cells[pIdx].innerText.toLowerCase().includes('mayor')
                };
            }).filter(x => x);
        }, { cityIndex, nameIndex, positionIndex });

        // Filter in memory to avoid search box issues
        const mayorsOnPage = rows.filter(r => r.isValid);
        allMayors.push(...mayorsOnPage);

        // process.stdout.write(`\rPage ${pageNum}: Scraped ${rows.length} rows, ${mayorsOnPage.length} mayors. Total: ${allMayors.length}  `);

        const nextBtn = await page.$('.paginate_button.next:not(.disabled)');
        if (nextBtn) {
            await nextBtn.click({ force: true });
            // Wait for table to change. 
            // Simple wait
            await page.waitForTimeout(1000);
            pageNum++;
        } else {
            hasNext = false;
        }

        if (pageNum > 200) break; // Safety
    }

    console.log(`\nScraping complete. Found ${allMayors.length} mayors.`);

    if (allMayors.length > 0) {
        const cleaned = allMayors.map(m => {
            let city = m.cityRaw;
            const prefixes = ["City of ", "Town of "];
            for (const p of prefixes) {
                if (city.startsWith(p)) {
                    city = city.substring(p.length);
                    break;
                }
            }
            if (!city.endsWith(", AR")) city = `${city}, AR`;

            return {
                name: m.name,
                city: city,
                originalCity: m.cityRaw,
                detailsUrl: url,
                party: "Nonpartisan",
                photoUrl: null
            };
        });

        // Deduplicate (same mayor might appear multiple times if data is dirty or pagination glitch)
        const unique = [];
        const seen = new Set();
        cleaned.forEach(m => {
            const key = `${m.city}|${m.name}`;
            if (!seen.has(key)) {
                seen.add(key);
                unique.push(m);
            }
        });

        const outputPath = path.join(__dirname, '../data/mayors_ar_full.json');
        fs.writeFileSync(outputPath, JSON.stringify(unique, null, 2));
        console.log(`Saved ${unique.length} unique mayors to ${outputPath}`);
    }

    await browser.close();
})();
