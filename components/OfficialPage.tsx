import React from 'react';
import { Official, StateDetail } from '../types';

interface OfficialPageProps {
  state: StateDetail;
  official: Official;
  onBack: () => void;
  onBackToState?: () => void;
}

const OfficialPage: React.FC<OfficialPageProps> = ({ state, official, onBack, onBackToState }) => {
  const isGovernor = official.id === 'governor' || /governor/i.test(official.role);
  const mergedLinks = [...(official.links || [])];
  if (isGovernor && state.governor_sites?.length) {
    state.governor_sites.forEach(link => {
      if (!mergedLinks.some(existing => existing.url === link.url)) {
        mergedLinks.push(link);
      }
    });
  }

  return (
    <div className="flex flex-col gap-4 p-4 md:p-6 flex-grow bg-surface">
      <div className="flex items-center gap-2">
        <button onClick={onBack} className="px-3 py-1 rounded border border-soft bg-panel text-xs font-medium text-muted hover:bg-surface">← {state.name}</button>
        {onBackToState && (
          <button onClick={onBackToState} className="px-3 py-1 rounded bg-[hsl(var(--color-primary))] text-white text-xs font-medium hover:opacity-90">State Page</button>
        )}
        <h1 className="text-xl font-semibold ml-2">{official.role}</h1>
      </div>
      <div className="flex flex-col gap-6">
        <div className="flex gap-4 items-start">
          <div className="relative w-28 h-28 rounded-md bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-800 overflow-hidden flex items-center justify-center text-xs text-gray-600 dark:text-gray-400 select-none">
            {official.portrait_url ? (
              <img src={official.portrait_url} alt={official.name} className="object-cover w-full h-full" />
            ) : (
              <span className="text-lg font-semibold">
                {official.name.split(/\s+/).slice(0,2).map(s=>s[0]).join('').toUpperCase()}
              </span>
            )}
          </div>
          <div className="flex-1 space-y-2">
            <h2 className="text-lg font-medium leading-tight">{official.name}{official.party && <span className="ml-2 text-sm font-normal text-muted">({official.party})</span>}{official.placeholder && <span className="ml-2 text-[10px] px-2 py-0.5 rounded bg-yellow-100 text-yellow-800 dark:bg-yellow-900/40 dark:text-yellow-300">placeholder</span>}</h2>
            {mergedLinks.length > 0 && (
              <div className="flex flex-wrap gap-2">
                {mergedLinks.map(l => (
                  <a key={l.url} href={l.url} target="_blank" rel="noopener noreferrer" className="text-xs px-2 py-1 rounded bg-primary-soft text-primary hover:opacity-80">{l.label}</a>
                ))}
              </div>
            )}
          </div>
        </div>
        <div className="grid md:grid-cols-2 gap-6">
          <section>
            <h3 className="text-sm font-semibold mb-2 uppercase tracking-wide">Important Facts</h3>
            <ul className="text-sm list-disc pl-5 space-y-1">
              {official.facts?.length ? official.facts.map((f, i) => <li key={i}>{f}</li>) : <li>No facts listed.</li>}
            </ul>
          </section>
          <section>
            <h3 className="text-sm font-semibold mb-2 uppercase tracking-wide">Promises / Issues</h3>
            <ul className="text-sm list-disc pl-5 space-y-1">
              {official.promises?.length ? official.promises.map((p, i) => <li key={i}>{p}</li>) : <li>No items listed.</li>}
            </ul>
          </section>
        </div>
      </div>
    </div>
  );
};

export default OfficialPage;
