const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

async function scrapeArizonaMayors() {
    console.log('Launching browser for Arizona scrape...');
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();

    try {
        const url = 'https://azmayors.org/about/mayors/';
        console.log(`Navigating to ${url}...`);
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });

        // Wait for some content to load
        await page.waitForTimeout(3000);

        // Targeted extraction based on proven H3 (City) -> H4 (Mayor) pattern
        const mayors = await page.evaluate(() => {
            const results = [];
            const headers = document.querySelectorAll('h3, h4');

            let currentCity = null;

            headers.forEach(el => {
                const text = el.innerText.trim();
                if (el.tagName === 'H3') {
                    // It's a city
                    currentCity = text;
                } else if (el.tagName === 'H4' && currentCity) {
                    // It's a mayor matching the previous city
                    const mayorName = text;
                    // Clean up weird spaces if any
                    const cleanName = mayorName.replace(/\s+/g, ' ').trim();

                    results.push({
                        name: cleanName,
                        city: currentCity,
                        original_city: currentCity
                    });

                    // Reset current city to avoid duplicates/errors if H4s are repeated (unlikely)
                    currentCity = null;
                }
            });

            return results;
        });

        console.log(`Found ${mayors.length} mayors.`);

        // Normalize city names: Title Case
        const nomalizedMayors = mayors.map(m => {
            // Convert "CASA GRANDE" to "Casa Grande"
            const cityTitleCase = m.city.toLowerCase().replace(/(?:^|\s)\S/g, a => a.toUpperCase());
            return {
                name: m.name,
                city: `${cityTitleCase}, AZ`,
                source: 'azmayors.org'
            };
        });

        console.log('Writing to data/mayors_az_full.json');
        fs.writeFileSync('data/mayors_az_full.json', JSON.stringify(nomalizedMayors, null, 2));


    } catch (error) {
        console.error('Error scraping Arizona:', error);
    } finally {
        await browser.close();
    }
}

scrapeArizonaMayors();
