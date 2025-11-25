import React from 'react';
import { StateDetail } from '../types';
import HouseCarousel from './HouseCarousel';
import { IconX } from './Icons';

export type FindResult =
  | { type: 'state'; stateId: string; detail?: StateDetail | null; focusOfficialName?: string }
  | { type: 'city'; cityName: string }
  | { type: 'zip'; zip: string }
  | { type: 'official'; officialId: string }
  | null;

interface FindPageProps {
  query: string;
  loading?: boolean;
  result: FindResult;
  error?: string | null;
  onClose: () => void;
  onOpenState?: (stateId: string) => void;
  onNavigate?: (destination: string, context?: Record<string, unknown>) => void;
}

const FindPage: React.FC<FindPageProps> = ({ query, loading = false, result, error, onClose, onOpenState, onNavigate }) => {
  const stateResult = result && result.type === 'state' ? result : null;
  const nonStateResult = result && result.type !== 'state' ? result : null;
  const [navHint, setNavHint] = React.useState<string | null>(null);
  const handleNavigate = React.useCallback((destination: string, context?: Record<string, unknown>) => {
    if (destination === 'open-state' && stateResult) {
      onOpenState?.(stateResult.stateId);
      return;
    }
    if (onNavigate) {
      onNavigate(destination, context);
    } else {
      setNavHint(`Navigation coming soon for “${destination.replace(/^[^:]+:/, '')}”.`);
    }
  }, [onNavigate, onOpenState, stateResult]);
  React.useEffect(() => {
    setNavHint(null);
  }, [query, result]);
  const futureComingSoonCards = [
    { key: 'local-leadership', title: 'Local Leadership', description: 'Mayors, council members, and city-level contacts will appear here.' },
    { key: 'community-services', title: 'Community Services', description: 'Polling locations, civic resources, and office hours coming soon.' },
    { key: 'regional-layers', title: 'Regional Layers', description: 'School districts, commissions, and authorities planned for a future release.' },
  ];
  const queryType = stateResult ? 'state' : (nonStateResult?.type ?? (result ? result.type : 'generic'));

  const summaryCards = React.useMemo(() => {
    const cards: Array<{ key: string; title: string; headline: string; body: string; variant?: 'default' | 'dashed' | 'accent'; priority?: number; context?: Record<string, unknown>; }> = [];
    const baseDescriptor = (() => {
      switch (queryType) {
        case 'zip':
          return {
            title: 'ZIP focus',
            headline: `ZIP ${nonStateResult && nonStateResult.type === 'zip' ? nonStateResult.zip : query}`,
            body: 'Tap to unlock county + municipal feeds once available.',
            context: { type: 'zip', value: nonStateResult && nonStateResult.type === 'zip' ? nonStateResult.zip : query },
            variant: 'accent' as const,
          };
        case 'city':
          return {
            title: 'City spotlight',
            headline: nonStateResult && nonStateResult.type === 'city' ? nonStateResult.cityName : query,
            body: 'We’re charting mayors, councils, and agencies next.',
            context: { type: 'city', value: nonStateResult && nonStateResult.type === 'city' ? nonStateResult.cityName : query },
            variant: 'accent' as const,
          };
        case 'official':
          return {
            title: 'Official lookup',
            headline: 'Leadership profile mode',
            body: 'Tap to jump into future biography + legislation briefs.',
            context: { type: 'official', value: query },
            variant: 'accent' as const,
          };
        case 'state':
          return {
            title: 'State',
            headline: stateResult?.detail?.name || stateResult?.stateId || query,
            body: 'Tap to open the dedicated state experience.',
            context: { type: 'state', stateId: stateResult?.stateId },
            variant: 'accent' as const,
          };
        default:
          return {
            title: 'Search',
            headline: query,
            body: 'Zip, city, state, or official names are supported over time.',
            context: { type: 'generic', value: query },
            variant: 'default' as const,
          };
      }
    })();

    cards.push({ key: 'query', ...baseDescriptor, priority: 10 });
    cards.push({
      key: 'status',
      title: 'Status',
      headline: loading
        ? 'Searching…'
        : stateResult
          ? `Recognized as ${stateResult.detail?.name || stateResult.stateId}`
          : 'Prototype data set',
      body: stateResult ? 'Tap for the canonical state page.' : 'Tap to learn how data flows here.',
      variant: stateResult ? 'accent' : 'dashed',
      context: stateResult ? { type: 'state', stateId: stateResult.stateId } : { type: 'status-info' },
      priority: 8,
    });
    cards.push({
      key: 'next',
      title: 'Next up',
      headline: 'Local leadership',
      body: 'Local leaders, agencies, and ballot data will land here soon.',
      variant: 'default',
      context: { type: 'roadmap' },
      priority: 5,
    });
    return cards.sort((a, b) => (b.priority || 0) - (a.priority || 0));
  }, [query, queryType, stateResult, nonStateResult, loading]);

  const leadershipSpotlight = React.useMemo(() => {
    if (!stateResult?.detail) return null;
    const governor = stateResult.detail.officials?.find((o) => /governor/i.test(o.role));
    const senators = stateResult.detail.federal_representation?.senators || [];
    const districtLeaders = (stateResult.detail.federal_representation?.representatives || []).slice(0, 3);
    return { governor, senators, districtLeaders };
  }, [stateResult]);

  return (
    <div className="fixed inset-0 z-40 bg-black/30 backdrop-blur-sm flex justify-center items-stretch p-4">
      <div className="w-full max-w-5xl bg-panel rounded-2xl shadow-2xl border border-soft flex flex-col overflow-hidden">
        <header className="flex items-center justify-between px-6 py-4 border-b border-soft bg-surface">
          <div>
            <p className="text-xs uppercase tracking-[0.3em] text-muted">Prototype</p>
            <h1 className="text-2xl font-bold tracking-tight">Find Center</h1>
            <p className="text-sm text-muted">Surfacing what we know for “{query}”.</p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-2 rounded-full hover:bg-primary-soft focus:outline-none"
            aria-label="Close find view"
          >
            <IconX className="w-6 h-6" />
          </button>
        </header>

        <div className="flex-grow overflow-y-auto px-6 py-6 space-y-6 bg-surface">
          <section className="grid gap-4 md:grid-cols-3">
            {summaryCards.map((card) => (
              <button
                key={card.key}
                type="button"
                onClick={() => handleNavigate(card.key === 'status' && stateResult ? 'open-state' : `summary:${card.key}`, card.context)}
                className={`text-left p-4 rounded-xl border ${card.variant === 'dashed' ? 'border-dashed border-soft' : 'border-soft'} bg-panel hover:shadow-md focus:outline-none focus-visible:ring-2 focus-visible:ring-[hsl(var(--color-primary))] transition-shadow`}
                style={card.variant === 'accent' ? { borderColor: 'hsl(var(--color-primary))', backgroundColor: 'hsla(var(--color-primary) / 0.08)' } : undefined}
              >
                <p className="text-xs uppercase tracking-wide text-muted mb-1">{card.title}</p>
                <p className="text-lg font-semibold break-words">{card.headline}</p>
                <p className="text-xs text-muted mt-2">{card.body}</p>
              </button>
            ))}
          </section>
          {navHint && (
            <div className="text-xs text-muted italic">
              {navHint}
            </div>
          )}

          {error && (
            <div className="p-4 rounded-xl border border-red-200 bg-red-50 text-sm text-red-700">
              {error}
            </div>
          )}

          {nonStateResult && (
            <section>
              <button
                type="button"
                onClick={() => handleNavigate('blueprint', { type: nonStateResult.type })}
                className="w-full text-left p-4 rounded-xl border border-dashed border-soft bg-panel space-y-2 hover:shadow-md focus:outline-none focus-visible:ring-2 focus-visible:ring-[hsl(var(--color-primary))]"
              >
                <h2 className="text-lg font-semibold">Blueprint mode</h2>
                {nonStateResult.type === 'zip' && (
                  <p className="text-sm text-muted">
                    Zip code <strong>{nonStateResult.zip}</strong> will soon unlock county, district, and local service cards.
                  </p>
                )}
                {nonStateResult.type === 'city' && (
                  <p className="text-sm text-muted">
                    City intelligence for <strong>{nonStateResult.cityName}</strong> is on the roadmap. Expect mayoral contacts and local agencies here.
                  </p>
                )}
                {nonStateResult.type === 'official' && (
                  <p className="text-sm text-muted">
                    Official lookups will deep-link into biography, voting record, and committees.
                  </p>
                )}
                {!['zip', 'city', 'official'].includes(nonStateResult.type) && (
                  <p className="text-sm text-muted">We’re building towards a universal civic search experience.</p>
                )}
                <span className="text-[11px] uppercase tracking-wide text-muted">Under construction</span>
              </button>
            </section>
          )}

          {stateResult && stateResult.detail && (
            <section className="space-y-4">
              <div className="flex flex-wrap items-center gap-3">
                <span className="px-3 py-1 rounded-full text-xs font-semibold bg-primary-soft text-primary uppercase tracking-wide">
                  State match
                </span>
                <h2 className="text-2xl font-bold">{stateResult.detail.name}</h2>
                <button
                  type="button"
                  onClick={() => onOpenState?.(stateResult.stateId)}
                  className="ml-auto text-sm font-semibold px-4 py-1.5 rounded-full border border-soft hover:bg-panel"
                >
                  Open state page
                </button>
              </div>
              <div className="grid gap-4 md:grid-cols-2">
                <div className="p-4 rounded-xl border border-soft bg-panel">
                  <p className="text-xs uppercase tracking-wide text-muted mb-1">Legislature</p>
                  <p className="text-sm font-semibold">
                    {stateResult.detail.government.legislature.upper_chamber_name}
                  </p>
                  <p className="text-xs text-muted">
                    {stateResult.detail.government.legislature.lower_chamber_name}
                  </p>
                </div>
              </div>
              {leadershipSpotlight && (
                <button
                  type="button"
                  onClick={() => handleNavigate('leadership', { stateId: stateResult.stateId })}
                  className="w-full text-left p-4 rounded-xl border border-soft bg-panel hover:shadow-md focus:outline-none focus-visible:ring-2 focus-visible:ring-[hsl(var(--color-primary))] transition-shadow"
                >
                  <p className="text-xs uppercase tracking-wide text-muted mb-1">Leadership & Legislation</p>
                  <div className="grid gap-4 md:grid-cols-3 text-sm">
                    <div>
                      <p className="font-semibold">Governor</p>
                      <p className="text-muted">
                        {leadershipSpotlight.governor?.name || 'To be announced'}
                      </p>
                      {leadershipSpotlight.governor?.party && (
                        <p className="text-muted text-xs">{leadershipSpotlight.governor.party}</p>
                      )}
                    </div>
                    <div>
                      <p className="font-semibold">Senators</p>
                      <p className="text-muted">
                        {leadershipSpotlight.senators.length
                          ? leadershipSpotlight.senators.map((s) => s.name).join(', ')
                          : 'Data syncing soon'}
                      </p>
                    </div>
                    <div>
                      <p className="font-semibold">District Leaders</p>
                      <p className="text-muted">
                        {leadershipSpotlight.districtLeaders.length
                          ? leadershipSpotlight.districtLeaders.map((r) => r.name).join(', ')
                          : 'Queued for rollout'}
                      </p>
                    </div>
                  </div>
                  <p className="text-xs text-muted mt-3">Focus view will dive into governing agenda + legislation per office.</p>
                </button>
              )}
              {stateResult.focusOfficialName && (
                <div className="space-y-1">
                  <p className="text-sm text-muted">
                    Highlighting statewide data while we build a dedicated profile for <strong>{stateResult.focusOfficialName}</strong>.
                  </p>
                </div>
              )}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="text-xl font-semibold">House Representatives</h3>
                  <span className="text-xs text-muted">
                    {stateResult.detail.federal_representation?.house_districts || '—'} districts
                  </span>
                </div>
                <HouseCarousel representatives={stateResult.detail.federal_representation?.representatives || []} />
              </div>
            </section>
          )}

          <section className="space-y-3">
            <h3 className="text-xl font-semibold">Local Leadership</h3>
            <div className="grid gap-4 md:grid-cols-3">
              {futureComingSoonCards.map((card) => (
                <button
                  key={card.key}
                  type="button"
                  onClick={() => handleNavigate(`local:${card.key}`)}
                  className="p-4 rounded-xl border border-dashed border-soft bg-panel h-full flex flex-col text-left hover:shadow-md focus:outline-none focus-visible:ring-2 focus-visible:ring-[hsl(var(--color-primary))]"
                >
                  <h4 className="text-sm font-semibold mb-2">{card.title}</h4>
                  <p className="text-sm text-muted flex-grow">{card.description}</p>
                  <span className="text-[11px] uppercase tracking-wide text-muted mt-4">Coming soon</span>
                </button>
              ))}
            </div>
          </section>
        </div>
      </div>
    </div>
  );
};

export default FindPage;
