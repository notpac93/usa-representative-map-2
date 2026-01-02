const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const STATES = [
    "Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado", "Connecticut", "Delaware", "District of Columbia", "Florida", "Georgia", "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky", "Louisiana", "Maine", "Maryland", "Massachusetts", "Michigan", "Minnesota", "Mississippi", "Missouri", "Montana", "Nebraska", "Nevada", "New Hampshire", "New Jersey", "New Mexico", "New York", "North Carolina", "North Dakota", "Ohio", "Oklahoma", "Oregon", "Pennsylvania", "Rhode Island", "South Carolina", "South Dakota", "Tennessee", "Texas", "Utah", "Vermont", "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming"
];

(async () => {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext();
    const page = await context.newPage();

    const allMayors = [];

    try {
        console.log("Navigating to US Mayors database...");
        await page.goto('https://www.usmayors.org/mayors/');

        for (const state of STATES) {
            console.log(`Searching for mayors in ${state}...`);

            // Fill the search form (assuming generic input logic or based on inspection)
            // The previous inspection showed an input[type="text"] and input[type="submit"]
            await page.fill('input[type="text"]', state);
            await page.click('input[type="submit"]');

            // Wait for results
            await page.waitForLoadState('networkidle');

            // Inspect results
            // We need to find the cards. We'll look for elements that seem to contain mayor info.
            // Based on typical structure, let's grab all text or specific containers.
            // Since I don't have the exact selector, I'll extract data broadly.
            // However, usually these are in some 'result-item' or 'mayor-card'.
            // Let's try to find potential list items.

            // 1. Get the container content
            const cardData = await page.$$eval('.fusion-text ul', uls => {
                return uls.map(ul => {
                    const img = ul.querySelector('img')?.src;
                    const nameEl = ul.querySelector('b');
                    const name = nameEl ? nameEl.innerText.trim() : null;

                    if (!name) return null; // Skip if no name found

                    // Text content for city/state often follows the name
                    // Since it's unstructured text nodes, we might grab the full text and parse
                    const fullText = ul.innerText;

                    // Bio Link
                    const bioLink = Array.from(ul.querySelectorAll('a'))
                        .find(a => a.innerText.includes('Bio'))?.href;

                    return {
                        name,
                        img,
                        bioLink,
                        fullText // We can parse City/State from this later if needed
                    };
                }).filter(item => item !== null);
            });

            if (cardData.length > 0) {
                console.log(`Found ${cardData.length} mayors for ${state}`);
                // Add to our list
                cardData.forEach(mayor => {
                    // Basic parsing for City (text after name)
                    // This is rough but better than nothing
                    // Format usually: Name \n City, State
                    const lines = mayor.fullText.split('\n').map(l => l.trim()).filter(l => l);
                    const nameIndex = lines.indexOf(mayor.name);
                    const cityState = (nameIndex !== -1 && lines[nameIndex + 1]) ? lines[nameIndex + 1] : "Unknown";

                    allMayors.push({
                        state,
                        name: mayor.name,
                        photoUrl: mayor.img,
                        detailsUrl: mayor.bioLink,
                        city: cityState,
                        rawText: mayor.fullText
                    });
                });
            } else {
                console.log(`No mayors found for ${state} with current selector.`);
            }

            // Go back for next state
            await page.goto('https://www.usmayors.org/mayors/');
        }

        const outputPath = path.join(__dirname, '../data/mayors_raw.json');
        fs.writeFileSync(outputPath, JSON.stringify(allMayors, null, 2));
        console.log(`Saved raw mayor data to ${outputPath}`);

    } catch (e) {
        console.error("Scraping failed:", e);
    } finally {
        await browser.close();
    }
})();
