
import { StateDetail, StateDetailData, Official, HouseRepresentative } from '../types';
import usaGovSites from './usaGovSites.json';
import senatorsDataRaw from './senators.json';
import governorsDataRaw from './governors.json';
import houseMembersRaw from './houseMembers.json';

type LinkItem = { label: string; url: string };
type UsaGovEntry = {
  state: string;
  sourceUrl?: string;
  stateGovSites?: LinkItem[];
  governorSites?: LinkItem[];
};

type GovernorLink = { label?: string | null; url?: string | null };

type GovernorProfile = {
  name: string;
  party?: string | null;
  terms?: string[];
  born?: string | null;
  birthState?: string | null;
  school?: string | null;
  spouse?: string | null;
  contact?: {
    address?: string | null;
    phone?: string | null;
    fax?: string | null;
    email?: string | null;
    [key: string]: string | null | undefined;
  } | null;
  links?: GovernorLink[];
  about?: string[];
  photoUrl?: string | null;
  photoLocalPath?: string | null;
};

type GovernorStateRecord = {
  state: string;
  stateId: string;
  sourceUrl?: string;
  scrapedAt?: string;
  governor: GovernorProfile;
};

type HouseRepEntry = {
  name: string;
  officialName?: string;
  party: string;
  partyName?: string;
  district: string;
  districtNumber?: number | null;
  isAtLarge?: boolean;
  isDelegate?: boolean;
  office?: string | null;
  phone?: string | null;
  committees?: string[];
  website?: string | null;
  slug?: string;
  bioguideId?: string | null;
  hometown?: string | null;
  profileUrl?: string | null;
  photoUrl?: string | null;
  photoLocalPath?: string | null;
};

type HouseStateRecord = {
  state: string;
  stateId: string;
  sourceUrl?: string;
  scrapedAt?: string;
  representatives: HouseRepEntry[];
};

type SenatorJsonEntry = {
  name: string;
  party: string;
  website?: string | null;
  contactUrl?: string | null;
  hometown?: string | null;
  officeAddress?: string | null;
  phone?: string | null;
  committeeUrl?: string | null;
  bioguideUrl?: string | null;
  bioguideId?: string | null;
  photoUrl?: string | null;
  photoLocalPath?: string | null;
};

type SenatorStateRecord = {
  state: string;
  stateId: string;
  sourceUrl?: string;
  scrapedAt?: string;
  senators: SenatorJsonEntry[];
};

const sanitizeLinks = (links?: LinkItem[]): LinkItem[] => {
  if (!links) return [];
  const seen = new Set<string>();
  const result: LinkItem[] = [];
  links.forEach(link => {
    const url = link?.url?.trim();
    if (!url || seen.has(url)) return;
    result.push({
      label: link.label?.trim() || url.replace(/^https?:\/\//, '').replace(/\/?$/, ''),
      url
    });
    seen.add(url);
  });
  return result;
};

// Base shape defaults (can be extended without editing every file)
export const BASE: Omit<StateDetail, 'id' | 'name'> = {
  last_updated: '2025-01-01',
  government: {
    branches: [],
    legislature: { upper_chamber_name: '', lower_chamber_name: '' }
  },
  federal_representation: { senators: [], house_districts: 0, representatives: [] },
  resources: [],
  sources: []
};

// Static seed data (can be gradually migrated into per‑state modules)
const seed: StateDetailData = {};

function define(partial: Partial<StateDetail> & { id: string; name: string }): StateDetail {
  const result: StateDetail = {
    ...BASE,
    ...partial,
    government: {
      ...BASE.government,
      ...partial.government,
      legislature: {
        ...BASE.government.legislature,
        ...(partial.government?.legislature || {})
      }
    },
    federal_representation: {
      ...BASE.federal_representation,
      ...partial.federal_representation,
      senators: partial.federal_representation?.senators || BASE.federal_representation.senators
    },
    resources: partial.resources || BASE.resources,
    sources: partial.sources || BASE.sources,
    officials: partial.officials
  };
  // Fallback auto-generation of officials if none specified
  if (!result.officials || result.officials.length === 0) {
    const fallback: Official[] = [];
  fallback.push({ id: 'governor', role: 'Governor', name: 'Governor (Add Name)', placeholder: true });
    if (result.federal_representation.senators.length) {
      result.federal_representation.senators.forEach(s => {
        const slug = s.name.toLowerCase().replace(/[^a-z0-9]+/g, '-');
  fallback.push({ id: `senator-${slug}`.replace(/-+/g, '-'), role: 'U.S. Senator', name: s.name, party: s.party, placeholder: true });
      });
    } else {
  fallback.push({ id: 'senator-1', role: 'U.S. Senator', name: 'Senator (Add Name)', placeholder: true });
  fallback.push({ id: 'senator-2', role: 'U.S. Senator', name: 'Senator (Add Name)', placeholder: true });
    }
    result.officials = fallback;
  }
  result.resources = [...(result.resources || [])];
  result.sources = [...(result.sources || [])];
  if (result.officials) {
    result.officials = result.officials.map(o => ({
      ...o,
      links: o.links ? [...o.links] : undefined,
      facts: o.facts ? [...o.facts] : undefined,
      promises: o.promises ? [...o.promises] : undefined
    }));
  }
  return result;
}

export function createEmptyDetail(id: string, name: string): StateDetail {
  return define({ id, name });
}

// Example migrated states
seed['CA'] = define({
  id: 'CA', name: 'California', last_updated: '2023-10-26',
  government: {
    branches: [
      { name: 'Executive', details: 'Headed by the Governor.' },
      { name: 'Legislative', details: 'California State Legislature, a bicameral body.' },
      { name: 'Judicial', details: 'Supreme Court of California and lower courts.' }
    ],
    legislature: { upper_chamber_name: 'State Senate', lower_chamber_name: 'State Assembly' }
  },
  federal_representation: { senators: [ { name: 'Laphonza Butler', party: 'D' }, { name: 'Alex Padilla', party: 'D' } ], house_districts: 52 },
  resources: [
    { label: 'Register to Vote', url: 'https://registertovote.ca.gov/' },
    { label: 'Find Your Representative', url: 'https://findyourrep.legislature.ca.gov/' }
  ],
  sources: [
    { label: 'Official State Website', url: 'https://www.ca.gov' },
    { label: 'U.S. Census Bureau', url: 'https://www.census.gov' }
  ],
  officials: [
    { id: 'governor', role: 'Governor', name: 'Gavin Newsom', party: 'D', facts: ['In office since 2019'], promises: ['Focus on climate initiatives'], links: [{ label: 'Official Site', url: 'https://www.gov.ca.gov/' }] },
    { id: 'senator-padilla', role: 'U.S. Senator', name: 'Alex Padilla', party: 'D', facts: ['Appointed 2021'], links: [{ label: 'Senate Page', url: 'https://www.padilla.senate.gov/' }] },
    { id: 'senator-butler', role: 'U.S. Senator', name: 'Laphonza Butler', party: 'D' }
  ]
});

seed['TX'] = define({
  id: 'TX', name: 'Texas', last_updated: '2023-10-25',
  government: {
    branches: [
      { name: 'Executive', details: 'Headed by the Governor.' },
      { name: 'Legislative', details: 'Texas Legislature, a bicameral body.' },
      { name: 'Judicial', details: 'Supreme Court of Texas and Texas Court of Criminal Appeals.' }
    ],
    legislature: { upper_chamber_name: 'Senate', lower_chamber_name: 'House of Representatives' }
  },
  federal_representation: { senators: [ { name: 'John Cornyn', party: 'R' }, { name: 'Ted Cruz', party: 'R' } ], house_districts: 38 },
  resources: [
    { label: 'Register to Vote', url: 'https://www.votetexas.gov/register-to-vote/' },
    { label: 'Who Represents Me?', url: 'https://wrm.capitol.texas.gov/' }
  ],
  sources: [
    { label: 'Official State Website', url: 'https://www.texas.gov' },
    { label: 'U.S. Census Bureau', url: 'https://www.census.gov' }
  ],
  officials: [
    { id: 'governor', role: 'Governor', name: 'Greg Abbott', party: 'R' },
    { id: 'senator-john-cornyn', role: 'U.S. Senator', name: 'John Cornyn', party: 'R' },
    { id: 'senator-ted-cruz', role: 'U.S. Senator', name: 'Ted Cruz', party: 'R' }
  ]
});

seed['RI'] = define({
  id: 'RI', name: 'Rhode Island', last_updated: '2023-10-22',
  government: {
    branches: [
      { name: 'Executive', details: 'Headed by the Governor.' },
      { name: 'Legislative', details: 'Rhode Island General Assembly, a bicameral body.' },
      { name: 'Judicial', details: 'Rhode Island Supreme Court.' }
    ],
    legislature: { upper_chamber_name: 'Senate', lower_chamber_name: 'House of Representatives' }
  },
  federal_representation: { senators: [ { name: 'Jack Reed', party: 'D' }, { name: 'Sheldon Whitehouse', party: 'D' } ], house_districts: 2 },
  resources: [
    { label: 'Register to Vote', url: 'https://vote.sos.ri.gov/' },
    { label: 'Find Your Legislators', url: 'https://www.ri.gov/representatives/' }
  ],
  sources: [
    { label: 'Official State Website', url: 'https://www.ri.gov' },
    { label: 'U.S. Census Bureau', url: 'https://www.census.gov' }
  ],
  officials: [
    { id: 'governor', role: 'Governor', name: 'Daniel McKee', party: 'D' },
    { id: 'senator-jack-reed', role: 'U.S. Senator', name: 'Jack Reed', party: 'D' },
    { id: 'senator-sheldon-whitehouse', role: 'U.S. Senator', name: 'Sheldon Whitehouse', party: 'D' }
  ]
});

// Bulk placeholder seeds for all remaining states not yet defined.
// These rely on the define() fallback to generate placeholder officials.
const ALL_STATES: Array<[string,string]> = [
  ['AL','Alabama'], ['AK','Alaska'], ['AZ','Arizona'], ['AR','Arkansas'], ['CA','California'], ['CO','Colorado'], ['CT','Connecticut'], ['DE','Delaware'], ['DC','District of Columbia'],
  ['FL','Florida'], ['GA','Georgia'], ['HI','Hawaii'], ['ID','Idaho'], ['IL','Illinois'], ['IN','Indiana'], ['IA','Iowa'], ['KS','Kansas'],
  ['KY','Kentucky'], ['LA','Louisiana'], ['ME','Maine'], ['MD','Maryland'], ['MA','Massachusetts'], ['MI','Michigan'], ['MN','Minnesota'], ['MS','Mississippi'],
  ['MO','Missouri'], ['MT','Montana'], ['NE','Nebraska'], ['NV','Nevada'], ['NH','New Hampshire'], ['NJ','New Jersey'], ['NM','New Mexico'], ['NY','New York'], ['RI','Rhode Island'],
  ['NC','North Carolina'], ['ND','North Dakota'], ['OH','Ohio'], ['OK','Oklahoma'], ['OR','Oregon'], ['PA','Pennsylvania'], ['SC','South Carolina'], ['SD','South Dakota'],
  ['TN','Tennessee'], ['TX','Texas'], ['UT','Utah'], ['VT','Vermont'], ['VA','Virginia'], ['WA','Washington'], ['WV','West Virginia'], ['WI','Wisconsin'], ['WY','Wyoming']
];

const STATE_NAME_TO_ID = new Map<string, string>(
  ALL_STATES.map(([id, name]) => [name.toLowerCase(), id])
);

const usaGovData = (usaGovSites as UsaGovEntry[]);
const senatorStateData = (senatorsDataRaw as SenatorStateRecord[]);
const governorStateData = (governorsDataRaw as GovernorStateRecord[]);
const houseStateData = (houseMembersRaw as HouseStateRecord[]);

type UsaGovRecord = {
  entry: UsaGovEntry;
  stateSites: LinkItem[];
  governorSites: LinkItem[];
};

const usaGovById = new Map<string, UsaGovRecord>();
const senatorRecordsByState = new Map<string, SenatorStateRecord>();
const governorRecordsByState = new Map<string, GovernorStateRecord>();
const houseRecordsByState = new Map<string, HouseStateRecord>();

usaGovData.forEach(entry => {
  const id = STATE_NAME_TO_ID.get(entry.state.trim().toLowerCase());
  if (!id) return;
  usaGovById.set(id, {
    entry,
    stateSites: sanitizeLinks(entry.stateGovSites),
    governorSites: sanitizeLinks(entry.governorSites)
  });
});

senatorStateData.forEach(record => {
  if (record?.stateId) {
    senatorRecordsByState.set(record.stateId.toUpperCase(), {
      ...record,
      senators: Array.isArray(record.senators) ? record.senators : []
    });
  }
});

governorStateData.forEach(record => {
  if (record?.stateId && record.governor) {
    governorRecordsByState.set(record.stateId.toUpperCase(), record);
  }
});

houseStateData.forEach(record => {
  if (record?.stateId && Array.isArray(record.representatives)) {
    houseRecordsByState.set(record.stateId.toUpperCase(), {
      ...record,
      representatives: record.representatives.filter(rep => !!rep?.name)
    });
  }
});

const normalizeName = (value?: string | null): string => {
  if (!value) return '';
  return value
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[^a-z0-9]/g, '');
};

const slugifyName = (value?: string | null): string => {
  if (!value) return 'senator';
  return value
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)+/g, '') || 'senator';
};

const isSenatorOfficial = (official: Official): boolean => /senator/i.test(official.role || '');

const createLinkItem = (label: string, url?: string | null): LinkItem | null => {
  if (!url) return null;
  return { label, url };
};

const convertGovernorLinks = (links?: GovernorLink[]): LinkItem[] => {
  if (!links) return [];
  return links
    .map(link => {
      const url = link?.url?.trim();
      if (!url) return null;
      return {
        label: link?.label?.trim() || url.replace(/^https?:\/\//, '').replace(/\/?$/, ''),
        url
      };
    })
    .filter((link): link is LinkItem => !!link);
};

const mergeLinks = (existing: LinkItem[] | undefined, additions: LinkItem[]): LinkItem[] | undefined => {
  const filteredAdditions = additions.filter(link => !!link);
  if ((!existing || existing.length === 0) && filteredAdditions.length === 0) {
    return existing;
  }
  const merged: LinkItem[] = existing ? existing.map(link => ({ ...link })) : [];
  const seen = new Set(merged.map(link => link.url));
  filteredAdditions.forEach(link => {
    if (link.url && !seen.has(link.url)) {
      merged.push(link);
      seen.add(link.url);
    }
  });
  return merged;
};

const mergeFacts = (existing: string[] | undefined, additions: string[]): string[] | undefined => {
  const cleanedAdditions = additions.map(item => item?.trim()).filter((item): item is string => !!item);
  if ((!existing || existing.length === 0) && cleanedAdditions.length === 0) {
    return existing;
  }
  const merged: string[] = existing ? [...existing] : [];
  const seen = new Set(merged.map(item => item.toLowerCase()));
  cleanedAdditions.forEach(item => {
    const key = item.toLowerCase();
    if (!seen.has(key)) {
      merged.push(item);
      seen.add(key);
    }
  });
  return merged;
};

const applyHouseData = (detail: StateDetail): StateDetail => {
  const record = houseRecordsByState.get(detail.id);
  if (!record) {
    return detail;
  }

  const representatives: HouseRepresentative[] = record.representatives.map(entry => {
    const localPhoto = entry.photoLocalPath?.replace(/^\/+/, '');
    return {
      name: entry.name,
      officialName: entry.officialName,
      party: entry.party,
      partyName: entry.partyName,
      district: entry.district,
      districtNumber: entry.districtNumber ?? null,
      isAtLarge: !!entry.isAtLarge,
      isDelegate: !!entry.isDelegate,
      office: entry.office || undefined,
      phone: entry.phone || undefined,
      committees: entry.committees ? [...entry.committees] : undefined,
      website: entry.website || undefined,
      slug: entry.slug,
      bioguideId: entry.bioguideId || undefined,
      hometown: entry.hometown || undefined,
      profileUrl: entry.profileUrl || undefined,
      photoLocalPath: localPhoto ? `/${localPhoto}` : undefined,
      photoUrl: entry.photoUrl || undefined
    };
  });

  detail.federal_representation.representatives = representatives;
  const countedSeats = representatives.filter(rep => !rep.isDelegate).length || representatives.length;
  if (!detail.federal_representation.house_districts || detail.federal_representation.house_districts < countedSeats) {
    detail.federal_representation.house_districts = countedSeats;
  }

  if (record.sourceUrl && !detail.sources.some(src => src.url === record.sourceUrl)) {
    detail.sources = [...detail.sources, { label: `House.gov (${detail.name})`, url: record.sourceUrl }];
  }

  return detail;
};

const applyGovernorData = (detail: StateDetail): StateDetail => {
  const record = governorRecordsByState.get(detail.id);
  if (!record?.governor) {
    return detail;
  }

  const profile = record.governor;
  if (!detail.officials) {
    detail.officials = [];
  }

  let governor = detail.officials.find(o => o.id === 'governor' || /governor/i.test(o.role));
  if (!governor) {
    governor = { id: 'governor', role: 'Governor', name: profile.name || 'Governor', placeholder: true };
    detail.officials.push(governor);
  }

  if (profile.name) {
    governor.name = profile.name;
  }
  if (profile.party) {
    governor.party = profile.party;
  }

  const localPhotoPath = profile.photoLocalPath?.replace(/^\/+/, '');
  const portraitCandidate = localPhotoPath
    ? `/${localPhotoPath}`
    : profile.photoUrl || governor.portrait_url;
  if (portraitCandidate) {
    governor.portrait_url = portraitCandidate;
  }
  governor.placeholder = false;

  const factAdditions: string[] = [];
  if (profile.terms?.length) {
    factAdditions.push(`Terms: ${profile.terms.join(' | ')}`);
  }
  const bornLine = profile.born && profile.birthState
    ? `${profile.born} (${profile.birthState})`
    : profile.born || profile.birthState;
  if (bornLine) {
    factAdditions.push(`Born: ${bornLine}`);
  }
  if (profile.school) {
    factAdditions.push(`Education: ${profile.school}`);
  }
  if (profile.spouse) {
    factAdditions.push(`Spouse: ${profile.spouse}`);
  }
  const contact = profile.contact || {};
  if (contact.address) {
    factAdditions.push(`Address: ${contact.address.replace(/\n+/g, ', ')}`);
  }
  if (contact.phone) {
    factAdditions.push(`Phone: ${contact.phone}`);
  }
  if (contact.email) {
    factAdditions.push(`Email: ${contact.email}`);
  }

  const mergedFacts = mergeFacts(governor.facts, factAdditions);
  if (mergedFacts) {
    governor.facts = mergedFacts;
  }

  const newLinks = convertGovernorLinks(profile.links);
  if (contact.email) {
    const emailUrl = /^mailto:/i.test(contact.email) ? contact.email : `mailto:${contact.email}`;
    newLinks.push({ label: 'Email', url: emailUrl });
  }
  const mergedLinks = mergeLinks(governor.links, newLinks);
  if (mergedLinks) {
    governor.links = mergedLinks;
  }
  if (newLinks.length) {
    const mergedGovernorSites = mergeLinks(detail.governor_sites, newLinks);
    if (mergedGovernorSites) {
      detail.governor_sites = mergedGovernorSites;
    }
  }

  if (record.sourceUrl && !detail.sources.some(src => src.url === record.sourceUrl)) {
    detail.sources = [...detail.sources, { label: `NGA (${detail.name})`, url: record.sourceUrl }];
  }

  return detail;
};

const enrichOfficialWithSenator = (official: Official | undefined, record: SenatorJsonEntry): Official => {
  const base: Official = official ? { ...official } : {
    id: `senator-${slugifyName(record.name)}`,
    role: 'U.S. Senator',
    name: record.name,
    party: record.party
  };

  const localPhotoPath = record.photoLocalPath?.replace(/^\/+/ , '');
  const portraitCandidate = localPhotoPath
    ? `/${localPhotoPath}`
    : record.photoUrl || base.portrait_url;

  const candidateLinks = [
    createLinkItem('Official Website', record.website),
    createLinkItem('Contact', record.contactUrl),
    createLinkItem('Committee Assignments', record.committeeUrl),
    createLinkItem('Biographical Directory', record.bioguideUrl)
  ].filter((link): link is LinkItem => !!link);

  return {
    ...base,
    name: record.name,
    party: record.party || base.party,
    portrait_url: portraitCandidate || base.portrait_url,
    placeholder: false,
    links: mergeLinks(base.links, candidateLinks)
  };
};

const applySenatorData = (detail: StateDetail): StateDetail => {
  const record = senatorRecordsByState.get(detail.id);
  const stateSenators = record?.senators || [];
  if (!stateSenators.length) {
    return detail;
  }

  detail.federal_representation.senators = stateSenators.map(s => ({
    name: s.name,
    party: s.party || ''
  }));

  const existingOfficials = detail.officials ? [...detail.officials] : [];
  const nonSenatorOfficials = existingOfficials.filter(o => !isSenatorOfficial(o));
  const senatorOfficials = existingOfficials.filter(isSenatorOfficial);

  const placeholderPool: Official[] = [];
  const namedSenators = new Map<string, Official>();
  senatorOfficials.forEach(official => {
    if (!official.name || /add name/i.test(official.name) || official.placeholder) {
      placeholderPool.push(official);
      return;
    }
    const key = normalizeName(official.name);
    if (!key) {
      placeholderPool.push(official);
      return;
    }
    if (!namedSenators.has(key)) {
      namedSenators.set(key, official);
    }
  });

  const updatedSenators: Official[] = stateSenators.map(senatorRecord => {
    const key = normalizeName(senatorRecord.name);
    const baseOfficial = key && namedSenators.has(key)
      ? namedSenators.get(key)
      : placeholderPool.shift();
    return enrichOfficialWithSenator(baseOfficial, senatorRecord);
  });

  detail.officials = [...nonSenatorOfficials, ...updatedSenators];

  if (record.sourceUrl && !detail.sources.some(src => src.url === record.sourceUrl)) {
    detail.sources = [...detail.sources, { label: `U.S. Senate (${detail.name})`, url: record.sourceUrl }];
  }

  return detail;
};

const cloneLinks = (links: LinkItem[]): LinkItem[] => links.map(link => ({ ...link }));

const deriveExecutiveName = (links: LinkItem[]): string | null => {
  const label = links
    .map(link => link.label?.trim())
    .filter((label): label is string => !!label)
    .find(label => !/^contact/i.test(label));
  return label || null;
};

const applyUsaGovData = (detail: StateDetail): StateDetail => {
  const record = usaGovById.get(detail.id);
  if (!record) return detail;
  const { entry, stateSites, governorSites } = record;

  if (stateSites.length) {
    detail.state_sites = cloneLinks(stateSites);
  }

  if (governorSites.length) {
    detail.governor_sites = cloneLinks(governorSites);
    const governor = detail.officials?.find(o => o.id === 'governor' || /governor/i.test(o.role));
    if (governor) {
      const existing = new Set((governor.links || []).map(l => l.url));
      const additions = governorSites.filter(link => !existing.has(link.url));
      if (additions.length) {
        governor.links = [...(governor.links || []), ...cloneLinks(additions)];
      }
      const derivedName = deriveExecutiveName(governorSites);
      const needsName = !governor.name || /add name/i.test(governor.name) || governor.placeholder;
      if (derivedName && needsName) {
        governor.name = derivedName;
        governor.placeholder = false;
      }
    }
  }

  if (entry.sourceUrl && !detail.sources.some(src => src.url === entry.sourceUrl)) {
    detail.sources = [...detail.sources, { label: `USA.gov (${detail.name})`, url: entry.sourceUrl }];
  }

  return detail;
};

ALL_STATES.forEach(([id,name]) => {
  if (!seed[id]) {
    seed[id] = define({
      id, name, last_updated: '2025-08-16',
      government: {
        branches: [
          { name: 'Executive', details: 'Headed by the Governor.' },
          { name: 'Legislative', details: `${name} Legislature.` },
          { name: 'Judicial', details: `${name} court system.` }
        ],
        legislature: { upper_chamber_name: 'Senate', lower_chamber_name: 'House of Representatives' }
      }
    });
  }
});

const applyAllEnrichments = (detail: StateDetail): StateDetail =>
  applyHouseData(applySenatorData(applyGovernorData(applyUsaGovData(detail))));

Object.keys(seed).forEach(id => {
  seed[id] = applyAllEnrichments(seed[id]);
});

export const stateData: StateDetailData = seed;

// Dynamic loader: place per-state module files in data/states/{ID}.ts exporting partial StateDetail as default.
export async function loadStateDetail(id: string): Promise<StateDetail | null> {
  const upper = id.toUpperCase();
  try {
    // Vite supports dynamic import with explicit pattern when using variables; we enumerate common path.
    const mod = await import(`./states/${upper}.ts`).catch(() => null);
    if (mod && mod.default) {
      return applyAllEnrichments(define({ id: upper, name: mod.default.name || upper, ...mod.default }));
    }
  } catch (e) {
    // ignore
  }
  const detail = stateData[upper] || null;
  return detail ? applyAllEnrichments(detail) : null;
}
