import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import { stateData } from '../data/stateData.ts';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
type UsaGovEntry = {
  state: string;
  stateGovSites?: Array<{ label: string; url: string }>;
  governorSites?: Array<{ label: string; url: string }>;
};

const usaGovSites: UsaGovEntry[] = JSON.parse(
  readFileSync(resolve(__dirname, '../data/usaGovSites.json'), 'utf8')
);

const stateByName = new Map<string, { id: string; name: string }>(
  Object.values(stateData).map(detail => [detail.name.toLowerCase(), { id: detail.id, name: detail.name }])
);

const missingStateSites: string[] = [];
const missingGovernorSites: string[] = [];
const missingStateRecords: string[] = [];

usaGovSites.forEach(entry => {
  const detailMeta = stateByName.get(entry.state.trim().toLowerCase());
  if (!detailMeta) {
    missingStateRecords.push(entry.state);
    return;
  }
  const detail = stateData[detailMeta.id];
  if (!detail?.state_sites?.length) {
    missingStateSites.push(`${detailMeta.id} (${detailMeta.name})`);
  }
  if (!detail?.governor_sites?.length) {
    missingGovernorSites.push(`${detailMeta.id} (${detailMeta.name})`);
  }
});

const missingFromJson = Object.values(stateData)
  .filter(detail => !usaGovSites.find(entry => entry.state.trim().toLowerCase() === detail.name.toLowerCase()))
  .map(detail => `${detail.id} (${detail.name})`);

console.log('Missing USA.gov entries:', missingStateRecords);
console.log('States missing state site links after merge:', missingStateSites);
console.log('States missing governor links after merge:', missingGovernorSites);
console.log('States missing entirely from JSON:', missingFromJson);
