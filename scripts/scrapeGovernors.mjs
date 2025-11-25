import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';

const LIST_URL = 'https://www.nga.org/governors/';
const OUTPUT_JSON = path.resolve('data', 'governors.json');
const PHOTO_DIR = path.resolve('public', 'governors');

const wait = (min = 300, max = 700) => new Promise(resolve => setTimeout(resolve, Math.floor(min + Math.random() * (max - min))));

const slugify = (value = '') => value
  .toLowerCase()
  .normalize('NFKD')
  .replace(/[^a-z0-9]+/g, '-')
  .replace(/(^-|-$)+/g, '') || 'governor';

const normalizeStateKey = (value = '') => value
  .toLowerCase()
  .normalize('NFKD')
  .replace(/[^a-z]/g, '');

const stripGovernorPrefix = (value = '') => value.replace(/^gov\.?\s+/i, '').trim();

const STATE_LOOKUP = new Map([
  ['alabama', 'AL'], ['alaska', 'AK'], ['arizona', 'AZ'], ['arkansas', 'AR'], ['california', 'CA'],
  ['colorado', 'CO'], ['connecticut', 'CT'], ['delaware', 'DE'], ['districtcolumbia', 'DC'], ['florida', 'FL'],
  ['georgia', 'GA'], ['hawaii', 'HI'], ['idaho', 'ID'], ['illinois', 'IL'], ['indiana', 'IN'],
  ['iowa', 'IA'], ['kansas', 'KS'], ['kentucky', 'KY'], ['louisiana', 'LA'], ['maine', 'ME'],
  ['maryland', 'MD'], ['massachusetts', 'MA'], ['michigan', 'MI'], ['minnesota', 'MN'], ['mississippi', 'MS'],
  ['missouri', 'MO'], ['montana', 'MT'], ['nebraska', 'NE'], ['nevada', 'NV'], ['newhampshire', 'NH'],
  ['newjersey', 'NJ'], ['newmexico', 'NM'], ['newyork', 'NY'], ['northcarolina', 'NC'], ['northdakota', 'ND'],
  ['ohio', 'OH'], ['oklahoma', 'OK'], ['oregon', 'OR'], ['pennsylvania', 'PA'], ['rhodeisland', 'RI'],
  ['southcarolina', 'SC'], ['southdakota', 'SD'], ['tennessee', 'TN'], ['texas', 'TX'], ['utah', 'UT'],
  ['vermont', 'VT'], ['virginia', 'VA'], ['washington', 'WA'], ['westvirginia', 'WV'], ['wisconsin', 'WI'],
  ['wyoming', 'WY'], ['puertorico', 'PR'], ['guam', 'GU'], ['americansamoa', 'AS'], ['virginislands', 'VI'],
  ['usvirginislands', 'VI'], ['northernmarianaislands', 'MP'], ['commonwealthofthenorthernmarianaislands', 'MP']
]);

const resolveStateId = (name = '') => STATE_LOOKUP.get(normalizeStateKey(name)) || null;

const resolveUrl = (url, base = LIST_URL) => {
  if (!url) return null;
  try {
    return new URL(url, base).href;
  } catch {
    return null;
  }
};

const parseGovernorList = async (page) => {
  await page.goto(LIST_URL, { waitUntil: 'domcontentloaded' });
  await wait();
  return page.evaluate(() => {
    const stripGovernorPrefix = value => value.replace(/^gov\.?\s+/i, '').trim();
    const entries = Array.from(document.querySelectorAll('.current-governors__item a'));
    return entries.map(anchor => {
      const state = anchor.querySelector('.state')?.textContent?.trim() || null;
      const nameText = anchor.textContent?.replace(/\s+/g, ' ').trim() || '';
      const name = stripGovernorPrefix(nameText);
      const img = anchor.querySelector('img');
      const photoUrl = img?.getAttribute('src') || null;
      return {
        state,
        name,
        profileUrl: anchor.href,
        listPhotoUrl: photoUrl
      };
    }).filter(item => item.state && item.name && item.profileUrl);
  });
};

const parseGovernorDetail = async (page, profileUrl) => {
  await page.goto(profileUrl, { waitUntil: 'domcontentloaded' });
  await wait();
  return page.evaluate(() => {
    const stripGovernorPrefix = value => value.replace(/^gov\.?\s+/i, '').trim();
    const collectTextLines = (element, selectorsToRemove = []) => {
      if (!element) return [];
      const clone = element.cloneNode(true);
      selectorsToRemove.forEach(selector => clone.querySelectorAll(selector).forEach(node => node.remove()));
      const segments = [];
      const walk = node => {
        node.childNodes.forEach(child => {
          if (child.nodeType === Node.TEXT_NODE) {
            const text = child.textContent?.replace(/\s+/g, ' ');
            if (text && text.trim()) {
              segments.push(text.trim());
            }
          } else if (child.nodeName === 'BR') {
            segments.push('\n');
          } else if (child.nodeType === Node.ELEMENT_NODE) {
            walk(child);
          }
        });
      };
      walk(clone);
      return segments.join('').split('\n').map(line => line.trim()).filter(Boolean);
    };

    const heroContainer = document.querySelector('.hero-post__container__right');
    const heroImg = document.querySelector('.hero-post__img-container img');

    const metadata = {};
    document.querySelectorAll('ul.list--horizontal li.item').forEach(li => {
      const label = li.querySelector('.label')?.textContent?.trim();
      if (!label) return;
      const lines = collectTextLines(li, ['.label']);
      if (!lines.length) return;
      if (label === 'Terms') {
        metadata.terms = lines;
      } else {
        metadata[label.toLowerCase()] = lines.join('\n');
      }
    });

    const contact = {};
    const contactGroup = Array.from(document.querySelectorAll('.page-publication__sidebar__group'))
      .find(group => /contact information/i.test(group.querySelector('h4')?.textContent || ''));
    if (contactGroup) {
      contactGroup.querySelectorAll('li.item').forEach(li => {
        const label = li.querySelector('small, .label, .content-block__item__description')?.textContent?.trim();
        if (!label) return;
        const key = label.toLowerCase();
        const lines = collectTextLines(li, ['small', '.label', '.content-block__item__description']);
        if (!lines.length) return;
        const value = lines.join('\n');
        if (/address/i.test(label)) contact.address = value;
        else if (/phone/i.test(label)) contact.phone = value;
        else if (/fax/i.test(label)) contact.fax = value;
        else if (/email/i.test(label)) contact.email = value;
        else contact[key] = value;
      });
    }

    const additionalGroup = Array.from(document.querySelectorAll('.page-publication__sidebar__group'))
      .find(group => /additional information/i.test(group.querySelector('h4')?.textContent || ''));
    const links = additionalGroup
      ? Array.from(additionalGroup.querySelectorAll('a[href]')).map(anchor => ({
          label: anchor.textContent?.trim() || anchor.href,
          url: anchor.href
        })).filter(link => link.url)
      : [];

    const aboutSection = document.querySelector('section[aria-labelledby="about-governor"], section#about-governor');
    const about = aboutSection
      ? Array.from(aboutSection.querySelectorAll('p')).map(p => p.textContent?.trim()).filter(text => !!text)
      : [];

    return {
      state: heroContainer?.querySelector('.title__label')?.textContent?.trim() || null,
      name: stripGovernorPrefix(heroContainer?.querySelector('h1')?.textContent || '') || null,
      party: metadata.party || null,
      terms: metadata.terms || [],
      born: metadata.born || null,
      birthState: metadata['birth state'] || null,
      school: metadata.school || null,
      spouse: metadata.spouse || null,
      contact,
      links,
      about,
      photoUrl: heroImg?.getAttribute('src') || null
    };
  });
};

const downloadPhoto = async (url, destinationPath) => {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Failed to download ${url}: ${response.status}`);
  const arrayBuffer = await response.arrayBuffer();
  await fs.writeFile(destinationPath, Buffer.from(arrayBuffer));
};

const serializeGovernor = (listEntry, detailEntry) => {
  const stateName = detailEntry.state || listEntry.state;
  const stateId = resolveStateId(stateName) || resolveStateId(listEntry.state) || null;
  const name = detailEntry.name || listEntry.name;
  return {
    state: stateName,
    stateId,
    sourceUrl: listEntry.profileUrl,
    scrapedAt: new Date().toISOString(),
    governor: {
      name,
      party: detailEntry.party || null,
      terms: detailEntry.terms || [],
      born: detailEntry.born || null,
      birthState: detailEntry.birthState || null,
      school: detailEntry.school || null,
      spouse: detailEntry.spouse || null,
      contact: detailEntry.contact || {},
      links: detailEntry.links || [],
      about: detailEntry.about || [],
      photoUrl: detailEntry.photoUrl || listEntry.listPhotoUrl || null
    }
  };
};

async function main() {
  await fs.mkdir(path.dirname(OUTPUT_JSON), { recursive: true });
  await fs.mkdir(PHOTO_DIR, { recursive: true });

  const browser = await chromium.launch({
    headless: process.env.HEADLESS !== 'false',
    slowMo: process.env.SLOWMO ? Number(process.env.SLOWMO) : undefined
  });
  const page = await browser.newPage();

  console.info('➡️  Fetching current governors list');
  const listEntries = await parseGovernorList(page);
  console.info(`   Found ${listEntries.length} entries on NGA`);

  const results = [];

  for (const entry of listEntries) {
    try {
      console.info(`\n➡️  Scraping ${entry.state}: ${entry.name}`);
      const detail = await parseGovernorDetail(page, entry.profileUrl);
      const record = serializeGovernor(entry, detail);
      const photoSource = record.governor.photoUrl;
      if (photoSource) {
        try {
          const url = new URL(photoSource);
          const cleanPath = url.pathname.split('?')[0];
          const ext = path.extname(cleanPath) || '.jpg';
          const stateSlug = record.stateId ? record.stateId.toLowerCase() : slugify(record.state || 'state');
          const filename = `${stateSlug}-${slugify(record.governor.name || stateSlug)}${ext}`;
          const destination = path.join(PHOTO_DIR, filename);
          await downloadPhoto(photoSource, destination);
          record.governor.photoLocalPath = path.relative(path.resolve('public'), destination).replace(/\\/g, '/');
        } catch (err) {
          console.warn(`   ⚠️  Photo download failed for ${record.state}:`, err.message);
        }
      }
      results.push(record);
    } catch (err) {
      console.error(`   ❌  Failed to scrape ${entry.state}:`, err);
    }
    await wait(200, 500);
  }

  await browser.close();
  await fs.writeFile(OUTPUT_JSON, JSON.stringify(results, null, 2));
  console.info(`\n💾  Saved ${results.length} governor records to ${OUTPUT_JSON}`);
}

main().catch(err => {
  console.error('Scrape failed:', err);
  process.exitCode = 1;
});
