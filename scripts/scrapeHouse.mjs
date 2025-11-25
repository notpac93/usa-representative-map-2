import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';

const BASE_URL = 'https://www.house.gov/representatives';
const CLERK_MEMBERS_URL = 'https://clerk.house.gov/Members/ViewMemberProfiles';
const CLERK_BASE_URL = 'https://clerk.house.gov';
const OUTPUT_JSON = path.resolve('data', 'houseMembers.json');
const PHOTO_DIR = path.resolve('public', 'representatives');

const rawStatePairs = [
  ['Alabama', 'AL'], ['Alaska', 'AK'], ['Arizona', 'AZ'], ['Arkansas', 'AR'], ['California', 'CA'],
  ['Colorado', 'CO'], ['Connecticut', 'CT'], ['Delaware', 'DE'], ['District of Columbia', 'DC'], ['Florida', 'FL'],
  ['Georgia', 'GA'], ['Hawaii', 'HI'], ['Idaho', 'ID'], ['Illinois', 'IL'], ['Indiana', 'IN'],
  ['Iowa', 'IA'], ['Kansas', 'KS'], ['Kentucky', 'KY'], ['Louisiana', 'LA'], ['Maine', 'ME'],
  ['Maryland', 'MD'], ['Massachusetts', 'MA'], ['Michigan', 'MI'], ['Minnesota', 'MN'], ['Mississippi', 'MS'],
  ['Missouri', 'MO'], ['Montana', 'MT'], ['Nebraska', 'NE'], ['Nevada', 'NV'], ['New Hampshire', 'NH'],
  ['New Jersey', 'NJ'], ['New Mexico', 'NM'], ['New York', 'NY'], ['North Carolina', 'NC'], ['North Dakota', 'ND'],
  ['Ohio', 'OH'], ['Oklahoma', 'OK'], ['Oregon', 'OR'], ['Pennsylvania', 'PA'], ['Rhode Island', 'RI'],
  ['South Carolina', 'SC'], ['South Dakota', 'SD'], ['Tennessee', 'TN'], ['Texas', 'TX'], ['Utah', 'UT'],
  ['Vermont', 'VT'], ['Virginia', 'VA'], ['Washington', 'WA'], ['West Virginia', 'WV'], ['Wisconsin', 'WI'],
  ['Wyoming', 'WY'], ['Puerto Rico', 'PR'], ['Guam', 'GU'], ['American Samoa', 'AS'], ['Virgin Islands', 'VI'],
  ['U.S. Virgin Islands', 'VI'], ['Northern Mariana Islands', 'MP'], ['Commonwealth of the Northern Mariana Islands', 'MP']
];

const STATE_LOOKUP = new Map(rawStatePairs.map(([name, id]) => [name
  .toLowerCase()
  .normalize('NFKD')
  .replace(/[^a-z]/g, ''), id]));
const PARTY_MAP = new Map([
  ['R', 'Republican'],
  ['D', 'Democratic'],
  ['ID', 'Independent'],
  ['DFL', 'Democratic-Farmer-Labor'],
  ['L', 'Libertarian'],
  ['PPD', 'Partido Popular Democrático'],
  ['PNP', 'Partido Nuevo Progresista'],
  ['NP', 'Nonpartisan'],
  ['NPP', 'Nonpartisan'],
  ['IG', 'Independent'],
]);

const wait = (min = 200, max = 500) => new Promise(resolve => setTimeout(resolve, Math.floor(min + Math.random() * (max - min))));

const normalizeStateKey = (value = '') => value
  .toLowerCase()
  .normalize('NFKD')
  .replace(/[^a-z]/g, '');

const normalizeName = (value = '') => value
  .toLowerCase()
  .normalize('NFKD')
  .replace(/[^a-z0-9]/g, '');

const slugify = (value = '') => value
  .toLowerCase()
  .normalize('NFKD')
  .replace(/[^a-z0-9]+/g, '-')
  .replace(/(^-|-$)+/g, '') || 'representative';
const formatDisplayName = (value = '') => {
  const trimmed = value.replace(/\s+/g, ' ').trim();
  if (!trimmed) return '';
  if (trimmed.includes(',')) {
    const [last, rest] = trimmed.split(',', 2);
    return `${rest.trim()} ${last.trim()}`.replace(/\s+/g, ' ').trim();
  }
  return trimmed;
};

const parseDistrictNumber = (value = '') => {
  const cleaned = value.toLowerCase().trim();
  if (!cleaned) return null;
  if (cleaned.includes('at large') || cleaned.includes('resident commissioner') || cleaned.includes('delegate')) return 0;
  const match = cleaned.match(/(\d+)/);
  return match ? Number(match[1]) : null;
};

const resolveClerkUrl = (value) => {
  if (!value) return null;
  try {
    return new URL(value, CLERK_BASE_URL).href;
  } catch {
    return null;
  }
};
const parseStateIdFromLabel = (value = '') => {
  if (!value) return null;
  const parenMatch = value.match(/\(([A-Z]{2})\)/);
  if (parenMatch) return parenMatch[1];
  return STATE_LOOKUP.get(normalizeStateKey(value)) || null;
};

const parseClerkProfiles = async (page) => {
  console.info('\n➡️  Loading Clerk.house.gov member profiles for portraits');
  await page.goto(CLERK_MEMBERS_URL, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('.members-list_content', { timeout: 20000 }).catch(() => {});

  const rawProfiles = await page.evaluate(() => {
    const sanitize = (value = '') => value.replace(/\s+/g, ' ').trim();
    const extractImagePath = (img) => {
      if (!img) return '';
      const orderedAttrs = ['src', 'data-src', 'data-lazy', 'data-original'];
      for (const attr of orderedAttrs) {
        const value = img.getAttribute(attr);
        if (value && value.trim().length) {
          return value.trim();
        }
      }
      const srcset = img.getAttribute('srcset') || img.getAttribute('data-srcset');
      if (srcset && srcset.trim().length) {
        const first = srcset.split(',').map(entry => entry.trim().split(' ')[0]).find(Boolean);
        if (first) return first;
      }
      return '';
    };
    return Array.from(document.querySelectorAll('.members-list_content')).map(card => {
      const link = card.querySelector('a.members-link, a.library-link')?.getAttribute('href') || '';
      const imagePath = extractImagePath(card.querySelector('img'));
      return {
        nameRaw: sanitize(card.querySelector('.member-name')?.textContent || ''),
        stateLabel: card.querySelector('.state')?.getAttribute('data-state') || sanitize(card.querySelector('.state')?.textContent || ''),
        districtLabel: card.querySelector('.district')?.getAttribute('data-district') || sanitize(card.querySelector('.district')?.textContent || ''),
        party: card.querySelector('.party')?.getAttribute('data-party') || sanitize(card.querySelector('.party')?.textContent || ''),
        hometown: card.querySelector('.hometown')?.getAttribute('data-hometown') || sanitize(card.querySelector('.hometown')?.textContent || ''),
        profilePath: link,
        imagePath
      };
    }).filter(item => item.nameRaw && item.stateLabel);
  });

  return rawProfiles
    .map(profile => {
      const stateId = parseStateIdFromLabel(profile.stateLabel);
      if (!stateId) return null;
      const profileUrl = resolveClerkUrl(profile.profilePath);
      const imageUrl = resolveClerkUrl(profile.imagePath);
      const bioguideMatch = profileUrl?.match(/\/members\/([A-Z0-9]+)/i) || imageUrl?.match(/\/([A-Z0-9]+)\.[a-z]+$/i);
      const bioguideId = bioguideMatch ? bioguideMatch[1] : null;
      return {
        nameRaw: profile.nameRaw,
        displayName: formatDisplayName(profile.nameRaw),
        stateId,
        districtLabel: profile.districtLabel,
        districtNumber: parseDistrictNumber(profile.districtLabel),
        party: profile.party || null,
        hometown: profile.hometown || null,
        profileUrl,
        imageUrl,
        bioguideId
      };
    })
    .filter((item) => !!item);
};

const buildClerkProfilePool = (profiles = []) => {
  const pool = new Map();
  profiles.forEach(profile => {
    if (!profile?.stateId) return;
    if (!pool.has(profile.stateId)) {
      pool.set(profile.stateId, []);
    }
    pool.get(profile.stateId).push(profile);
  });
  return pool;
};

const findMatchingClerkProfile = (pool, stateId, representative) => {
  if (!stateId) return null;
  const bucket = pool.get(stateId);
  if (!bucket || bucket.length === 0) return null;

  const normalizedRepName = normalizeName(representative.name || representative.officialName || '');
  const byDistrictIdx = representative.districtNumber !== null && representative.districtNumber !== undefined
    ? bucket.findIndex(profile => profile.districtNumber === representative.districtNumber)
    : -1;
  if (byDistrictIdx > -1) {
    return bucket.splice(byDistrictIdx, 1)[0];
  }

  if (representative.isDelegate) {
    const delegateIdx = bucket.findIndex(profile => /delegate|commissioner/i.test(profile.districtLabel || ''));
    if (delegateIdx > -1) {
      return bucket.splice(delegateIdx, 1)[0];
    }
  }

  if (representative.isAtLarge) {
    const atLargeIdx = bucket.findIndex(profile => /at large/i.test(profile.districtLabel || ''));
    if (atLargeIdx > -1) {
      return bucket.splice(atLargeIdx, 1)[0];
    }
  }

  const nameIdx = bucket.findIndex(profile => normalizeName(profile.displayName || profile.nameRaw) === normalizedRepName);
  if (nameIdx > -1) {
    return bucket.splice(nameIdx, 1)[0];
  }

  return null;
};

const relativizePublicPath = (absolutePath) => path.relative(path.resolve('public'), absolutePath).replace(/\\/g, '/');

const downloadClerkPhoto = async (url, slug) => {
  if (!url) return null;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  const urlObj = new URL(url);
  const ext = path.extname(urlObj.pathname) || '.jpg';
  const filename = `${slug}${ext}`;
  const destination = path.join(PHOTO_DIR, filename);
  const buffer = Buffer.from(await response.arrayBuffer());
  await fs.writeFile(destination, buffer);
  return relativizePublicPath(destination);
};

const parseMembersFromPage = async (page) => {
  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('.view-content table', { timeout: 15000 }).catch(() => {});
  return page.evaluate(() => {
    const extractText = el => el?.textContent?.replace(/\s+/g, ' ').trim() || '';
    const tables = Array.from(document.querySelectorAll('.view-content table'));
    return tables.map((table) => {
      const state = extractText(table.querySelector('caption'));
      const anchor = table.querySelector('caption')?.id || null;
      const rows = Array.from(table.querySelectorAll('tbody tr'));
      const members = rows.map((row) => {
        const cells = row.querySelectorAll('td');
        const district = extractText(cells[0]);
        const nameCell = cells[1];
        const website = nameCell?.querySelector('a')?.href || null;
        const nameRaw = extractText(nameCell);
        const party = extractText(cells[2]);
        const office = extractText(cells[3]);
        const phone = extractText(cells[4]);
        const committeesRaw = extractText(cells[5]);
        return {
          district,
          nameRaw,
          party,
          office,
          phone,
          committeesRaw,
          website,
        };
      }).filter(item => item.nameRaw);
      return { state, anchor, members };
    }).filter(entry => entry.state && entry.members.length);
  });
};

const partyLabel = (abbr = '') => PARTY_MAP.get(abbr.trim().toUpperCase()) || abbr;

const isDelegateDistrict = (district = '') => /delegate|resident commissioner/i.test(district);

const isAtLargeDistrict = (district = '') => /at large/i.test(district);

async function main() {
  await fs.mkdir(path.dirname(OUTPUT_JSON), { recursive: true });
  await fs.mkdir(PHOTO_DIR, { recursive: true });

  const browser = await chromium.launch({
    headless: process.env.HEADLESS !== 'false',
    slowMo: process.env.SLOWMO ? Number(process.env.SLOWMO) : undefined
  });
  const listContext = await browser.newContext();
  const listPage = await listContext.newPage();
  const clerkContext = await browser.newContext({ javaScriptEnabled: false });
  const clerkPage = await clerkContext.newPage();

  console.info('➡️  Loading House.gov representatives list');
  const tableData = await parseMembersFromPage(listPage);
  console.info(`   Found ${tableData.length} state/territory sections`);

  const clerkProfiles = await parseClerkProfiles(clerkPage);
  console.info(`   Matched ${clerkProfiles.length} Clerk profile cards`);
  const clerkProfilePool = buildClerkProfilePool(clerkProfiles);
  await clerkPage.close();
  await clerkContext.close();

  const scrapedAt = new Date().toISOString();
  const records = [];
  let downloadedPhotos = 0;

  for (const entry of tableData) {
    const key = normalizeStateKey(entry.state);
    const stateId = STATE_LOOKUP.get(key) || null;
    if (!stateId) {
      console.warn(`⚠️  Skipping unrecognized section: ${entry.state}`);
      continue;
    }

    const normalizedMembers = [];
    for (const [index, member] of entry.members.entries()) {
      const cleanNameRaw = member.nameRaw.replace(/\(link is external\)/gi, '').trim();
      const displayName = formatDisplayName(cleanNameRaw);
      const committees = member.committeesRaw
        ? member.committeesRaw.split('|').map(item => item.trim()).filter(Boolean)
        : [];
      const districtNumber = parseDistrictNumber(member.district);
      const slugBase = `${stateId || slugify(entry.state)}-${slugify(displayName || cleanNameRaw)}`;
      const normalized = {
        name: displayName || cleanNameRaw,
        officialName: cleanNameRaw,
        party: member.party || '',
        partyName: partyLabel(member.party || ''),
        district: member.district,
        districtNumber,
        isAtLarge: isAtLargeDistrict(member.district),
        isDelegate: isDelegateDistrict(member.district),
        office: member.office,
        phone: member.phone,
        committees,
        website: member.website,
        slug: slugBase,
        order: index,
        bioguideId: null,
        hometown: null,
        profileUrl: null,
        photoUrl: null,
        photoLocalPath: null
      };

      const clerkProfile = findMatchingClerkProfile(clerkProfilePool, stateId, normalized);
      if (clerkProfile) {
        normalized.bioguideId = clerkProfile.bioguideId || null;
        normalized.hometown = clerkProfile.hometown || null;
        normalized.profileUrl = clerkProfile.profileUrl || null;
        normalized.photoUrl = clerkProfile.imageUrl || null;
        if (clerkProfile.imageUrl) {
          try {
            const photoLocalPath = await downloadClerkPhoto(clerkProfile.imageUrl, slugBase);
            if (photoLocalPath) {
              normalized.photoLocalPath = photoLocalPath;
              downloadedPhotos += 1;
            }
          } catch (err) {
            console.warn(`   ⚠️  Photo download failed for ${normalized.name}: ${err.message}`);
          }
        }
      } else {
        console.warn(`   ⚠️  No Clerk profile match for ${normalized.name} (${stateId} ${normalized.district})`);
      }

      normalizedMembers.push(normalized);
    }

    records.push({
      state: entry.state,
      stateId,
      sourceUrl: entry.anchor ? `${BASE_URL}#${entry.anchor}` : BASE_URL,
      scrapedAt,
      representatives: normalizedMembers
    });

    await wait();
  }

  await listPage.close();
  await listContext.close();
  await browser.close();
  await fs.writeFile(OUTPUT_JSON, JSON.stringify(records, null, 2));
  console.info(`\n💾  Saved ${records.length} House delegation records to ${OUTPUT_JSON}`);
  console.info(`📸  Downloaded ${downloadedPhotos} representative photos to ${PHOTO_DIR}`);
}

main().catch(err => {
  console.error('House scrape failed:', err);
  process.exitCode = 1;
});
