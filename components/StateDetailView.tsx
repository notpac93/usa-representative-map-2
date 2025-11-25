
import React from 'react';
import { StateDetail } from '../types';
import { IconArrowLeft, IconExternalLink } from './Icons';

interface StateDetailViewProps {
  state: StateDetail;
  onBack: () => void;
}

const DetailCard: React.FC<{ title: string; children: React.ReactNode }> = ({ title, children }) => (
  <div className="rounded-xl p-4 md:p-6" style={{ backgroundColor: 'hsl(var(--color-panel))' }}>
    <h3 className="text-lg font-bold mb-3">{title}</h3>
    <div className="space-y-3 text-muted">{children}</div>
  </div>
);

const StateDetailView: React.FC<StateDetailViewProps> = ({ state, onBack }) => {
  return (
    <div className="w-full h-full flex flex-col bg-panel">
      <header className="p-4 border-b border-soft flex items-center flex-shrink-0 sticky top-0 bg-panel/90 backdrop-blur-sm z-10">
        <button onClick={onBack} className="p-2 rounded-full hover:bg-primary-soft transition-colors mr-2" aria-label="Back to map">
          <IconArrowLeft className="w-6 h-6" />
        </button>
        <h2 className="text-2xl font-bold tracking-tight">{state.name}</h2>
      </header>
      <div className="flex-grow overflow-y-auto p-4 md:p-6">
        <div className="space-y-6">
          <DetailCard title="Government">
            <p><strong>Upper Chamber:</strong> {state.government.legislature.upper_chamber_name}</p>
            <p><strong>Lower Chamber:</strong> {state.government.legislature.lower_chamber_name}</p>
            <div className="pt-2">
              {state.government.branches.map(branch => (
                <div key={branch.name}>
                    <p className="font-semibold">{branch.name}: <span className="font-normal">{branch.details}</span></p>
                </div>
              ))}
            </div>
          </DetailCard>

          <DetailCard title="Federal Representation">
            <p><strong>U.S. Senators:</strong> {state.federal_representation.senators.length}</p>
            <ul className="list-disc list-inside">
              {state.federal_representation.senators.map(senator => (
                <li key={senator.name}>{senator.name} ({senator.party})</li>
              ))}
            </ul>
            <p><strong>U.S. House Districts:</strong> {state.federal_representation.house_districts}</p>
          </DetailCard>

          <DetailCard title="Resources">
            {state.resources.map(resource => (
              <a
                key={resource.label}
                href={resource.url}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center justify-between text-accent hover:opacity-80 bg-accent-soft p-3 rounded-lg"
              >
                <span>{resource.label}</span>
                <IconExternalLink className="w-4 h-4 ml-2" />
              </a>
            ))}
          </DetailCard>

          <DetailCard title="Data Sources">
            <ul className="list-disc list-inside text-sm">
                {state.sources.map(source => (
                  <li key={source.label}>
                    <a href={source.url} target="_blank" rel="noopener noreferrer" className="text-accent hover:opacity-80">{source.label}</a>
                  </li>
                ))}
            </ul>
          </DetailCard>
        </div>
      </div>
    </div>
  );
};

export default StateDetailView;
