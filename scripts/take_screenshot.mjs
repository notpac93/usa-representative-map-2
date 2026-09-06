import { chromium } from 'playwright';
import path from 'path';
import fs from 'fs';

async function run() {
  console.log('Launching browser to capture screenshot...');
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  await page.goto('http://127.0.0.1:8080', { waitUntil: 'domcontentloaded' });
  
  console.log('Waiting for Supreme Court button...');
  // The supreme court button should be a FloatingActionButton or similar with a scale icon
  // Wait for the icon to be visible or wait 5 seconds.
  await new Promise(r => setTimeout(r, 5000));
  
  console.log('Clicking on the screen roughly where the top right button is...');
  await page.mouse.click(1150, 50); // Guess coordinates of the button
  
  await new Promise(r => setTimeout(r, 2000));
  
  const dest = path.resolve('/Users/kennygrimblejr./.gemini/antigravity-ide/brain/39585221-4e5e-40e9-a10c-b72b9d10fb03/screenshot_scotus_row.png');
  await page.screenshot({ path: dest });
  console.log('Saved screenshot to ' + dest);

  await browser.close();
}

run().catch(console.error);
