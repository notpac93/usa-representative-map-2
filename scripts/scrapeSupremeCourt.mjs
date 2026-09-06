import fs from 'node:fs/promises';
import path from 'node:path';
import { chromium } from 'playwright';

const JSON_PATH = path.resolve('assets', 'data', 'supreme_court.json');
const IMG_DIR = path.resolve('assets', 'img', 'supremecourt');

async function downloadImage(url, destPath) {
  try {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Status ${res.status}`);
    const buffer = await res.arrayBuffer();
    await fs.writeFile(destPath, Buffer.from(buffer));
    console.log(`Downloaded: ${path.basename(destPath)}`);
    return true;
  } catch (err) {
    console.error(`Failed to download ${url}: ${err.message}`);
    return false;
  }
}

async function run() {
  await fs.mkdir(IMG_DIR, { recursive: true });

  console.log('Downloading Supreme Court Group Photo...');
  await downloadImage(
    'https://www.supremecourt.gov/about/images/2022_Roberts_Court_Formal_083122_Web.jpg',
    path.join(IMG_DIR, 'group_photo.jpg')
  );

  const dataStr = await fs.readFile(JSON_PATH, 'utf-8');
  const justices = JSON.parse(dataStr);

  console.log('Launching browser to scrape Supreme Court images...');
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  await page.goto('https://www.supremecourt.gov/about/biographies.aspx', { waitUntil: 'domcontentloaded' });

  // Get all images on the page
  const images = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('img')).map(img => {
      return {
        src: img.src,
        title: img.getAttribute('title') || img.getAttribute('alt') || ''
      };
    });
  });

  await browser.close();

  console.log(`Found ${images.length} images on page. Mapping to justices...`);

  let updatedCount = 0;

  for (let justice of justices) {
    // Find matching image by name
    const match = images.find(img => {
      const titleLower = img.title.toLowerCase();
      const lastName = justice.name.split(' ').pop().toLowerCase().replace('jr.', '').trim();
      // Use the last name if it's not Jr, else use the word before it.
      const names = justice.name.split(' ');
      const actualLastName = names[names.length - 1].toLowerCase() === 'jr.' ? names[names.length - 2].toLowerCase() : names[names.length - 1].toLowerCase();
      
      return titleLower.includes(actualLastName.replace(',', ''));
    });
    
    if (match && match.src) {
      const ext = path.extname(new URL(match.src).pathname) || '.jpg';
      const filename = justice.name.replace(/[^a-z0-9]/gi, '_').toLowerCase() + ext;
      const destPath = path.join(IMG_DIR, filename);
      
      const success = await downloadImage(match.src, destPath);
      if (success) {
        justice.photoLocalPath = 'supremecourt/' + filename;
        updatedCount++;
      }
    } else {
      console.warn(`No matching image found on official site for: ${justice.name}`);
    }
  }

  await fs.writeFile(JSON_PATH, JSON.stringify(justices, null, 2));
  console.log(`Updated supreme_court.json with ${updatedCount} local images.`);
}

run().catch(console.error);
