import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';

const BASE_URL = 'https://www.senate.gov';
const OUTPUT_JSON = path.resolve('data', 'senators.json');
const PHOTO_DIR = path.resolve('public', 'senators');

const STATES = [
  ['AL', 'Alabama'], ['AK', 'Alaska'], ['AZ', 'Arizona'], ['AR', 'Arkansas'], ['CA', 'California'],
  ['CO', 'Colorado'], ['CT', 'Connecticut'], ['DE', 'Delaware'], ['FL', 'Florida'], ['GA', 'Georgia'],
  ['HI', 'Hawaii'], ['ID', 'Idaho'], ['IL', 'Illinois'], ['IN', 'Indiana'], ['IA', 'Iowa'],
  ['KS', 'Kansas'], ['KY', 'Kentucky'], ['LA', 'Louisiana'], ['ME', 'Maine'], ['MD', 'Maryland'],
  ['MA', 'Massachusetts'], ['MI', 'Michigan'], ['MN', 'Minnesota'], ['MS', 'Mississippi'], ['MO', 'Missouri'],
  ['MT', 'Montana'], ['NE', 'Nebraska'], ['NV', 'Nevada'], ['NH', 'New Hampshire'], ['NJ', 'New Jersey'],
  ['NM', 'New Mexico'], ['NY', 'New York'], ['NC', 'North Carolina'], ['ND', 'North Dakota'], ['OH', 'Ohio'],
  ['OK', 'Oklahoma'], ['OR', 'Oregon'], ['PA', 'Pennsylvania'], ['RI', 'Rhode Island'], ['SC', 'South Carolina'],
  ['SD', 'South Dakota'], ['TN', 'Tennessee'], ['TX', 'Texas'], ['UT', 'Utah'], ['VT', 'Vermont'],
  ['VA', 'Virginia'], ['WA', 'Washington'], ['WV', 'West Virginia'], ['WI', 'Wisconsin'], ['WY', 'Wyoming']
];

const wait = (min = 300, max = 700) => new Promise(resolve => setTimeout(resolve, Math.floor(min + Math.random() * (max - min))));

const slugify = (value = '') => value
  .toLowerCase()
  .normalize('NFKD')
  .replace(/[^a-z0-9]+/g, '-')
  .replace(/(^-|-$)+/g, '') || 'senator';

const resolveUrl = (url, base) => {
  if (!url) return null;
  try {
    return new URL(url, base).href;
  } catch {
    return null;
  }
};

const absoluteBase = (stateId) => `${BASE_URL}/states/${stateId}/intro.htm`;

const extractOfficeDetails = (lines = []) => {
  const filtered = lines.filter(line => line && !/^contact$/i.test(line));
  const phone = filtered.find(line => /(\(\d{3}\)|\d{3}-\d{3}-\d{4})/.test(line));
  const addressLines = filtered.filter(line => line !== phone);
  return {
    officeAddress: addressLines.join(', ') || null,
    phone: phone || null
  };
};

const deriveBioguideId = (url) => {
  if (!url) return null;
  const match = url.match(/bio\/([A-Z0-9]+)/i);
  return match ? match[1] : null;
};

const downloadPhoto = async (url, destPath) => {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Failed to download ${url}: ${response.status}`);
  const arrayBuffer = await response.arrayBuffer();
  await fs.writeFile(destPath, Buffer.from(arrayBuffer));
};

async function scrapeState(page, stateId, stateName) {
  const stateUrl = absoluteBase(stateId);
  console.info(`\n➡️  Fetching senators for ${stateName}`);
  await page.goto(stateUrl, { waitUntil: 'domcontentloaded' });
  await wait();
  const rawSenators = await page.evaluate(() => {
    const sanitize = (value = '') => value.replace(/\s+/g, ' ').trim();
    const collectLinesBetween = (start, end) => {
      const segments = [];
      let node = start?.nextSibling || null;
      while (node && node !== end) {
        if (node.nodeType === Node.TEXT_NODE) {
          const text = node.textContent?.trim();
          if (text) segments.push(text);
        } else if (node.nodeType === Node.ELEMENT_NODE) {
          if (node.tagName === 'BR') {
            segments.push('\n');
          } else {
            const text = node.textContent?.trim();
            if (text) segments.push(text);
          }
        }
        node = node.nextSibling;
      }
      return segments.join(' ').replace(/\s*\n\s*/g, '\n').split('\n').map(line => line.trim()).filter(Boolean);
    };

    const columns = Array.from(document.querySelectorAll('.state-row .state-column'));
    return columns.map(col => {
      const strong = col.querySelector('strong');
      const strongText = sanitize(strong?.textContent || '');
      const nameLink = strong?.querySelector('a');
      const image = col.querySelector('img');
      const hometown = col.querySelector('em');
      const hrs = Array.from(col.querySelectorAll('hr'));
      const officeLines = hrs.length >= 2 ? collectLinesBetween(hrs[0], hrs[1]) : [];
      const anchors = Array.from(col.querySelectorAll('a'));

      return {
        name: sanitize(nameLink?.textContent || strongText.replace(/\([^)]*\)/g, '')),
        party: (strongText.match(/\(([A-Za-z]+)\)/) || [null, null])[1],
        website: nameLink?.href || null,
        contactUrl: anchors.find(a => /contact/i.test(a.textContent || ''))?.href || null,
        committeeUrl: anchors.find(a => /committee assignments/i.test(a.textContent || ''))?.href || null,
        bioguideUrl: anchors.find(a => /biographical directory/i.test(a.textContent || ''))?.href || null,
        hometown: sanitize(hometown?.textContent || '').replace(/^Hometown:\s*/i, '') || null,
        officeLines,
        photoUrl: image?.src || null
      };
    }).filter(Boolean);
  });

  const senators = [];
  for (const raw of rawSenators) {
    if (!raw.name) continue;
    const normalized = { ...raw };
    normalized.website = resolveUrl(normalized.website, stateUrl);
    normalized.contactUrl = resolveUrl(normalized.contactUrl, stateUrl);
    normalized.committeeUrl = resolveUrl(normalized.committeeUrl, stateUrl);
    normalized.bioguideUrl = resolveUrl(normalized.bioguideUrl, stateUrl);
    normalized.photoUrl = resolveUrl(normalized.photoUrl, stateUrl);
    const officeDetails = extractOfficeDetails(normalized.officeLines);
    normalized.officeAddress = officeDetails.officeAddress;
    normalized.phone = officeDetails.phone;
    normalized.bioguideId = deriveBioguideId(normalized.bioguideUrl);
    delete normalized.officeLines;
    senators.push(normalized);
  }

  return { stateId, stateName, stateUrl, senators };
}

async function main() {
  await fs.mkdir(path.dirname(OUTPUT_JSON), { recursive: true });
  await fs.mkdir(PHOTO_DIR, { recursive: true });

  const browser = await chromium.launch({
    headless: process.env.HEADLESS !== 'false',
    slowMo: process.env.SLOWMO ? Number(process.env.SLOWMO) : undefined
  });
  const page = await browser.newPage();

  const results = [];

  for (const [stateId, stateName] of STATES) {
    try {
      const { senators } = await scrapeState(page, stateId, stateName);
      const enriched = [];
      for (const senator of senators) {
        const slug = slugify(`${stateId}-${senator.name}`);
        let photoLocalPath = null;
        if (senator.photoUrl) {
          try {
            const urlObj = new URL(senator.photoUrl);
            const ext = path.extname(urlObj.pathname) || '.jpg';
            const filename = `${slug}${ext}`;
            const destination = path.join(PHOTO_DIR, filename);
            await downloadPhoto(senator.photoUrl, destination);
            photoLocalPath = path.relative(path.resolve('public'), destination).replace(/\\/g, '/');
          } catch (err) {
            console.warn(`   ⚠️  Failed to download photo for ${senator.name}:`, err.message);
          }
        }
        enriched.push({
          name: senator.name,
          party: senator.party,
          website: senator.website,
          contactUrl: senator.contactUrl,
          hometown: senator.hometown,
          officeAddress: senator.officeAddress,
          phone: senator.phone,
          committeeUrl: senator.committeeUrl,
          bioguideUrl: senator.bioguideUrl,
          bioguideId: senator.bioguideId,
          photoUrl: senator.photoUrl,
          photoLocalPath
        });
      }

      console.info(`   ✔️  ${stateName}: ${enriched.length} senator record(s)`);

      results.push({
        state: stateName,
        stateId,
        sourceUrl: absoluteBase(stateId),
        scrapedAt: new Date().toISOString(),
        senators: enriched
      });
    } catch (err) {
      console.error(`   ❌  Failed for ${stateName}:`, err);
    }
  }

  await browser.close();
  await fs.writeFile(OUTPUT_JSON, JSON.stringify(results, null, 2));
  console.info(`\n💾  Saved ${results.length} state records to ${OUTPUT_JSON}`);
}

main().catch(err => {
  console.error('Scrape failed:', err);
  process.exitCode = 1;
});