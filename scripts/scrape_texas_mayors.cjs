const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();

    const url = 'https://directory.tml.org/results?search%5Btitle%5D%5B0%5D=AAAA&search%5Btype%5D=title&sortBy=city&sortDir=asc';
    console.log(`Navigating to ${url}`);

    await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });

    // Scrape all relevant links in order
    // This approach works regardless of Table/Div layout by relying on the logical sequence: City -> Mayor
    const items = await page.$$eval('a', anchors => {
        return anchors.map(a => ({
            text: a.innerText.trim(),
            href: a.href
        })).filter(a => a.href.includes('/profile/city/') || a.href.includes('/profile/individual/'));
    });

    console.log(`Found ${items.length} relevant links.`);

    const cleaned = [];
    let currentCity = null;

    for (const item of items) {
        if (item.href.includes('/profile/city/')) {
            currentCity = item.text;
        } else if (item.href.includes('/profile/individual/') && currentCity) {
            // Found a person, assign current city
            let cleanCity = currentCity;
            const prefixes = ["City of ", "Town of ", "Village of "];
            for (const p of prefixes) {
                if (cleanCity.startsWith(p)) {
                    cleanCity = cleanCity.substring(p.length);
                    break;
                }
            }
            if (!cleanCity.endsWith(", TX")) {
                cleanCity = `${cleanCity}, TX`;
            }

            cleaned.push({
                name: item.text,
                city: cleanCity,
                originalCity: currentCity,
                detailsUrl: item.href,
                party: "Nonpartisan",
                photoUrl: null,
                phone: null,
                email: null
            });
        }
    }

    console.log(`Extracted and paired ${cleaned.length} mayors.`);
    if (cleaned.length > 0) console.log("Sample:", cleaned[0]);

    if (cleaned.length > 0) {
        const outputPath = path.join(__dirname, '../data/mayors_tx_full.json');
        fs.writeFileSync(outputPath, JSON.stringify(cleaned, null, 2));
        console.log(`Saved to ${outputPath}`);
    }

    await browser.close();
})();
