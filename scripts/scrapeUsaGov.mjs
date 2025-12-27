import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';

const DIRECTORY_URL = 'https://www.usa.gov/state-governments';
const STATE_BASE = 'https://www.usa.gov/states/';
const OUTPUT_PATH = path.resolve('assets', 'data', 'usaGovSites.json');
const states = [
  'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado', 'Connecticut', 'Delaware', 'District of Columbia',
  'Florida', 'Georgia', 'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana', 'Maine',
  'Maryland', 'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada',
  'New Hampshire', 'New Jersey', 'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma',
  'Oregon', 'Pennsylvania', 'Rhode Island', 'South Carolina', 'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont',
  'Virginia', 'Washington', 'West Virginia', 'Wisconsin', 'Wyoming'
];

const wait = (min = 400, max = 950) => new Promise((resolve) => {
  const duration = Math.floor(min + Math.random() * (max - min));
  setTimeout(resolve, duration);
});

const slugify = (name) => name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');

async function scrapeState(page, stateName, url) {
  console.info(`\n➡️  Visiting ${stateName}`);
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await wait(500, 1100);

  const { stateGovSites, governorSites } = await page.evaluate(({ stateName }) => {
    const normalize = (value = '') => value.trim().toLowerCase();

    const collectLinks = (headingText) => {
      const headings = Array.from(document.querySelectorAll('h2, h3'));
      const targetHeading = headings.find((h) => normalize(h.textContent || '') === normalize(headingText));
      if (!targetHeading) return [];

      const blocks = [];
      let sibling = targetHeading.nextElementSibling;
      while (sibling && !/^H[1-6]$/.test(sibling.tagName)) {
        blocks.push(sibling);
        sibling = sibling.nextElementSibling;
      }
      if (!blocks.length && targetHeading.parentElement) {
        blocks.push(targetHeading.parentElement);
      }

      const links = [];
      for (const block of blocks) {
        block.querySelectorAll('a[href]').forEach((anchor) => {
          const label = (anchor.textContent || '').trim();
          const url = anchor.href;
          if (label && url) {
            links.push({ label, url });
          }
        });
      }
      return links;
    };

    return {
      stateGovSites: collectLinks('State government website'),
      governorSites: collectLinks('Governor')
    };
  }, { stateName });

  console.info(`   ✔️  Found ${stateGovSites.length} state-site link(s), ${governorSites.length} governor link(s)`);
  return {
    state: stateName,
    sourceUrl: url,
    stateGovSites,
    governorSites
  };
}

async function buildStateLinkMap(page) {
  await page.goto(DIRECTORY_URL, { waitUntil: 'domcontentloaded' });
  await wait(500, 900);
  const entries = await page.evaluate(() => {
    const anchors = Array.from(document.querySelectorAll('a[href*="/states/"]'));
    return anchors.map((a) => ({
      label: (a.textContent || '').trim(),
      href: a.href
    }));
  });

  const map = new Map();
  entries.forEach(({ label, href }) => {
    if (!label || !href) return;
    const normalized = label.replace(/\(.*?\)/, '').trim().toLowerCase();
    if (!normalized) return;
    map.set(normalized, href);
  });
  return map;
}

async function main() {
  const browser = await chromium.launch({ headless: process.env.HEADLESS !== 'false', slowMo: process.env.SLOWMO ? Number(process.env.SLOWMO) : undefined });
  const page = await browser.newPage();
  const linkMap = await buildStateLinkMap(page);

  const results = [];
  for (const state of states) {
    const normalized = state.toLowerCase();
    const targetUrl = linkMap.get(normalized) || linkMap.get(normalized.replace('district of ', '')) || `${STATE_BASE}${slugify(state)}`;
    const record = await scrapeState(page, state, targetUrl);
    record.scrapedAt = new Date().toISOString();
    results.push(record);
  }

  await browser.close();

  await fs.mkdir(path.dirname(OUTPUT_PATH), { recursive: true });
  await fs.writeFile(OUTPUT_PATH, JSON.stringify(results, null, 2), 'utf-8');
  console.info(`\n💾  Saved ${results.length} records to ${OUTPUT_PATH}`);
}

main().catch((err) => {
  console.error('Scrape failed:', err);
  process.exitCode = 1;
});
