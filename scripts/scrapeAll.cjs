const { execSync } = require('child_process');
const path = require('path');

const SCRIPTS = [
    'scrapeGovernors.mjs',
    'scrapeSenate.mjs',
    'scrapeHouse.mjs',
    'scrapeUsaGov.mjs'
];

console.log('🚀 Starting Unified Data Scraping Pipeline...\n');

SCRIPTS.forEach((script, index) => {
    console.log(`\n---------------------------------------------------------`);
    console.log(`[${index + 1}/${SCRIPTS.length}] Running ${script}...`);
    console.log(`---------------------------------------------------------`);
    try {
        execSync(`node scripts/${script}`, { stdio: 'inherit' });
    } catch (error) {
        console.error(`❌ Error running ${script}. Pipeline stopped.`);
        process.exit(1);
    }
});

console.log('\n✅ All data scraping tasks completed successfully!');
