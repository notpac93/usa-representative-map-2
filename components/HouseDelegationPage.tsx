import React from 'react';
import { HouseRepresentative, StateDetail } from '../types';
import { IconArrowLeft } from './Icons';

interface HouseDelegationPageProps {
  state: StateDetail;
  onBack: () => void;
}

const sortReps = (representatives: HouseRepresentative[]): HouseRepresentative[] => {
  const weight = (rep: HouseRepresentative) => {
    if (rep.isDelegate) return 2000 + (rep.districtNumber ?? 0);
    if (rep.isAtLarge) return -1;
    if (typeof rep.districtNumber === 'number') return rep.districtNumber;
    return 9999;
  };
  return [...representatives].sort((a, b) => {
    const diff = weight(a) - weight(b);
    if (diff !== 0) return diff;
    return a.name.localeCompare(b.name);
  });
};

const HouseDelegationPage: React.FC<HouseDelegationPageProps> = ({ state, onBack }) => {
  const representatives = sortReps(state.federal_representation.representatives || []);

  return (
    <div className="flex flex-col gap-4 p-4 md:p-6 flex-grow bg-surface">
      <div className="flex items-center gap-3">
        <button
          onClick={onBack}
          className="px-3 py-1 rounded border border-soft bg-panel text-xs font-medium text-muted hover:bg-surface flex items-center gap-1"
        >
          <IconArrowLeft className="w-4 h-4" />
          {state.name}
        </button>
        <h1 className="text-xl font-semibold">{state.name} House Delegation</h1>
      </div>
      <p className="text-sm text-muted">
        {representatives.length} representatives • {state.federal_representation.house_districts} districts
      </p>

      {representatives.length ? (
        <div className="grid gap-4 md:grid-cols-2">
          {representatives.map(rep => {
            const photo = rep.photoLocalPath || rep.photoUrl;
            const districtLabel = rep.isDelegate
              ? `${rep.district || 'Delegate'} Delegate`
              : rep.isAtLarge
                ? 'At-Large'
                : rep.district
                  ? `${rep.district} District`
                  : 'District';
            const partyLabel = rep.partyName || rep.party;
            const infoParts = [districtLabel, partyLabel].filter(Boolean);
            return (
              <article
                key={rep.slug || rep.bioguideId || rep.name}
                className="flex flex-col items-center text-center gap-3 px-3 py-4 rounded-xl border border-soft bg-panel"
              >
                <div className="w-24 h-24 rounded-lg bg-gray-100 dark:bg-gray-800 overflow-hidden flex items-center justify-center text-lg font-semibold text-gray-500">
                  {photo ? (
                    <img src={photo} alt={rep.name} className="object-cover w-full h-full" />
                  ) : (
                    rep.name
                      .split(/\s+/)
                      .slice(0, 2)
                      .map(part => part[0])
                      .join('')
                      .toUpperCase()
                  )}
                </div>
                <div className="w-full space-y-1 text-sm text-center">
                  <div className="font-semibold leading-tight">
                    {rep.name}
                  </div>
                  <div className="text-xs text-muted">{infoParts.join(' • ')}</div>
                  {rep.hometown && (
                    <div className="text-xs text-muted">Hometown: {rep.hometown}</div>
                  )}
                  {rep.phone && (
                    <div className="text-xs text-muted">
                      Phone:{' '}
                      <a href={`tel:${rep.phone}`} className="hover:underline">
                        {rep.phone}
                      </a>
                    </div>
                  )}
                  {rep.office && (
                    <div className="text-xs text-muted">Office: {rep.office}</div>
                  )}
                  <div className="flex flex-col items-center gap-2 pt-3 w-full">
                    {rep.website && (
                      <a
                        href={rep.website}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center justify-center text-xs px-4 py-1 rounded bg-[hsl(var(--color-primary))] text-white shadow-sm hover:opacity-90 transition-colors mx-auto min-w-[140px]"
                      >
                        Official Site
                      </a>
                    )}
                    {rep.profileUrl && (
                      <a
                        href={rep.profileUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center justify-center text-xs px-4 py-1 rounded border border-soft bg-surface hover:bg-panel mx-auto min-w-[140px]"
                      >
                        Clerk Profile
                      </a>
                    )}
                  </div>
                </div>
              </article>
            );
          })}
        </div>
      ) : (
        <p className="text-sm text-muted">No House delegation data available.</p>
      )}
    </div>
  );
};

export default HouseDelegationPage;
