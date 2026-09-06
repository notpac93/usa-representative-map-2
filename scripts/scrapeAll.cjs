const { execSync } = require('child_process');
const path = require('path');

const tasks = [
  { name: 'House', script: './scrapeHouse.mjs' },
  { name: 'Senate', script: './scrapeSenate.mjs' },
  { name: 'Governors', script: './scrapeGovernors.mjs' },
  { name: 'Mayors (Various)', script: './scrapeMayors.cjs' },
  { name: 'Supreme Court', script: './scrapeSupremeCourt.mjs' }
];

console.log('🚀 Starting Unified Data Scraping Pipeline...\n');

tasks.forEach((task, index) => {
    console.log(`\n---------------------------------------------------------`);
    console.log(`[${index + 1}/${tasks.length}] Running ${task.name} script: ${task.script}...`);
    console.log(`---------------------------------------------------------`);
    try {
        execSync(`node scripts/${task.script.replace('./', '')}`, { stdio: 'inherit' });
    } catch (error) {
        console.error(`❌ Error running ${task.name}. Pipeline stopped.`);
        process.exit(1);
    }
});

console.log('\n✅ All data scraping tasks completed successfully!');
