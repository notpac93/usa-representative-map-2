const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
    const browser = await chromium.launch({ headless: true });
    // Use a context to block images/css for speed, as we are visiting 460 pages
    const context = await browser.newContext({
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    });
    // routing to abort unneeded resources
    await context.route('**/*.{png,jpg,jpeg,gif,svg,css,woff,woff2}', route => route.abort());

    const page = await context.newPage();

    console.log("Loading Main Directory...");
    // Main directory 
    await page.goto('https://alm.imiscloud.com/ALALM/ALALM/About/ALM-Municipal-Directory.aspx', { timeout: 60000 });

    try {
        await page.waitForSelector('.rgPager a', { timeout: 10000 });
        const showAllClicked = await page.evaluate(() => {
            const links = Array.from(document.querySelectorAll('.rgPager a'));
            const showAll = links.find(a => a.innerText.includes('Show all'));
            if (showAll) {
                showAll.click();
                return true;
            }
            return false;
        });

        if (showAllClicked) {
            console.log("Clicked 'Show all', waiting for reload...");
            await page.waitForFunction(() => document.querySelectorAll('table.rgMasterTable tbody tr').length > 50, { timeout: 30000 });
        }
    } catch (e) {
        console.log("Might already be showing all or selector failed");
    }

    // Extract all City Profile Links
    const cities = await page.$$eval('table.rgMasterTable tbody tr', rows => {
        return rows.map(tr => {
            const link = tr.querySelector('a[href*="ORGpublicProfileRoster.aspx"]');
            if (!link) return null;

            // Fix URL Extraction: The href is often a JS call: javascript:ShowDialog...
            // We need to regex extract the ID or the URL from it.
            // Example: javascript:ShowDialog_NoReturnValue('.../ORGpublicProfileRoster.aspx?ID=10931', ...)
            const href = link.href;
            const match = href.match(/ORGpublicProfileRoster\.aspx\?ID=(\d+)/);

            if (match) {
                return {
                    cityRaw: link.innerText.trim(),
                    // Construct clean URL
                    profileUrl: `https://alm.imiscloud.com/ALALM/ALALM/About/ORGpublicProfileRoster.aspx?ID=${match[1]}`
                };
            }
            // If it's a direct link (rare but possible)
            if (href.startsWith('http')) {
                return {
                    cityRaw: link.innerText.trim(),
                    profileUrl: href
                };
            }

            return null;
        }).filter(x => x);
    });

    console.log(`Found ${cities.length} municipalities. Starting scraping (this will take time)...`);

    const mayors = [];
    const BATCH_SIZE = 5;

    for (let i = 0; i < cities.length; i += BATCH_SIZE) {
        const batch = cities.slice(i, i + BATCH_SIZE);
        const promises = batch.map(async (city) => {
            const p = await context.newPage();
            try {
                if (i === 0 && batch.indexOf(city) === 0) console.log(`Debugging URL: ${city.profileUrl}`);

                await p.goto(city.profileUrl, { waitUntil: 'load', timeout: 30000 });

                // Try to find ANY content first to debug emptiness
                const result = await p.evaluate(() => {
                    const rows = Array.from(document.querySelectorAll('tr'));
                    for (const r of rows) {
                        const cells = r.querySelectorAll('td');
                        // Name is col 0, Title is col 1
                        if (cells.length >= 2) {
                            const name = cells[0].innerText.trim();
                            const title = cells[1].innerText.trim();

                            if (title.includes('Mayor')) {
                                return { found: true, name: name };
                            }
                        }
                    }
                    return { found: false };
                });

                if (result.found) {
                    return {
                        name: result.name,
                        cityRaw: city.cityRaw,
                        state: "AL",
                        sourceUrl: city.profileUrl
                    };
                }

            } catch (e) {
                // console.log(`Failed for ${city.cityRaw}: ${e.message}`);
            } finally {
                await p.close();
            }
            return null;
        });

        const results = await Promise.all(promises);
        results.forEach(r => {
            if (r) mayors.push(r);
        });

        process.stdout.write(`\rScraped ${Math.min(i + BATCH_SIZE, cities.length)}/${cities.length} | Found: ${mayors.length}`);
    }

    console.log(`\nScraping complete. Found ${mayors.length} mayors.`);

    if (mayors.length > 0) {
        const cleaned = mayors.map(m => {
            let city = m.cityRaw;
            if (!city.endsWith(", AL")) city = `${city}, AL`;

            return {
                name: m.name,
                city: city,
                originalCity: m.cityRaw,
                detailsUrl: m.sourceUrl,
                party: "Nonpartisan",
                photoUrl: null
            };
        });

        const outputPath = path.join(__dirname, '../data/mayors_al_full.json');
        fs.writeFileSync(outputPath, JSON.stringify(cleaned, null, 2));
        console.log(`Saved to ${outputPath}`);
    }

    await browser.close();
})();
