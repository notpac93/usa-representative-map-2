import React from 'react';
import { Atlas, StateDetail, HouseRepresentative, CityFeature } from '../types';
import StateMapView from './StateMapView';
import { useFilteredOverlays } from '../utils/useFilteredOverlays';
import OverlayPanel from './OverlayPanel';
import HouseCarousel from './HouseCarousel';
import { capitals } from '../data/capitals';
import cityCoverage, { cityCoverageMeta } from '../data/cityCoverage.generated';

interface StatePageProps {
  atlas: Atlas;
  stateId: string;
  detail?: StateDetail | null;
  onBack?: () => void;
  onOfficialSelect?: (officialId: string) => void;
  onViewHouseDelegation?: () => void;
  overlayControls?: Array<{
    key: string;
    label: string;
    active: boolean;
    toggle: () => void | Promise<void>;
  }>;
  activeOverlays?: any[];
}

type CityDirectoryEntry = {
  key: string;
  name: string;
  displayName: string;
  population: number | null;
  lat: number | null;
  lon: number | null;
  feature?: CityFeature;
  isCapital?: boolean;
};

type TieredCityFeature = CityFeature & { tier?: number; previewRank?: number };

const CITY_SUFFIX_PATTERN = /\s+(city|town|village|borough|municipality|cdp|metropolitan government \(balance\)|balance)$/i;

function formatCityDisplayName(name?: string | null): string {
  if (!name) return '';
  let trimmed = name.trim();
  let previous = '';
  while (trimmed && trimmed !== previous && CITY_SUFFIX_PATTERN.test(trimmed)) {
    previous = trimmed;
    trimmed = trimmed.replace(CITY_SUFFIX_PATTERN, '').trim();
  }
  return trimmed || name;
}

const StatePage: React.FC<StatePageProps> = ({ atlas, stateId, detail, onBack, onOfficialSelect, onViewHouseDelegation, overlayControls, activeOverlays }) => {
  const state = atlas.states.find(s => s.id === stateId);
  const { overlayLayers, cityPoints, activeLabels, legendLayers } = useFilteredOverlays(state, activeOverlays);
  const [showAllCities, setShowAllCities] = React.useState(false);
  const [citySearch, setCitySearch] = React.useState('');

  if (!state) return null;

  const overlayLabelSummary = activeLabels.length ? activeLabels.join(' + ') : undefined;
  const resourceItems = React.useMemo(() => {
    if (!detail) return [] as Array<{ label: string; url: string; isStateSite?: boolean }>;
    const stateSiteItems = (detail.state_sites || []).map(link => ({ ...link, isStateSite: true }));
    const otherResources = (detail.resources || []).map(r => ({ ...r }));
    const entries: Array<{ label: string; url: string; isStateSite?: boolean }> = [
      ...stateSiteItems,
      ...otherResources
    ];
    const seen = new Set<string>();
    const deduped: Array<{ label: string; url: string; isStateSite?: boolean }> = [];
    entries.forEach(item => {
      if (seen.has(item.url)) return;
      seen.add(item.url);
      deduped.push(item);
    });
    return deduped;
  }, [detail]);

  const houseRepresentatives = React.useMemo<HouseRepresentative[]>(() => {
    const reps = detail?.federal_representation?.representatives;
    if (!reps?.length) return [];
    const sortValue = (rep: HouseRepresentative) => {
      if (rep.isDelegate) return 1000 + (rep.districtNumber ?? 0);
      if (rep.isAtLarge) return -1;
      if (typeof rep.districtNumber === 'number') return rep.districtNumber;
      return 9999;
    };
    return [...reps].sort((a, b) => {
      const diff = sortValue(a) - sortValue(b);
      if (diff !== 0) return diff;
      return a.name.localeCompare(b.name);
    });
  }, [detail?.federal_representation?.representatives]);

  const previewLimit = 5;
  const hasMoreRepresentatives = houseRepresentatives.length > previewLimit;
  const cityOverlayMeta = React.useMemo(() => activeOverlays?.find(layer => layer?.key === 'cities' || (layer as any)?.pointLayer), [activeOverlays]);
  const populationFormatter = React.useMemo(() => new Intl.NumberFormat('en-US'), []);
  React.useEffect(() => {
    if (!showAllCities) {
      setCitySearch('');
    }
  }, [showAllCities]);

  React.useEffect(() => {
    if (!showAllCities) return;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setShowAllCities(false);
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [showAllCities]);
  const cityDirectory = React.useMemo(() => {
    if (!cityPoints?.length) {
      return { count: 0, entries: [] as CityDirectoryEntry[] };
    }
    const map = new Map<string, CityDirectoryEntry>();
    cityPoints.forEach((city) => {
      if (!city?.name) return;
      const key = city.id || `${city.name}-${city.lat ?? 'lat'}-${city.lon ?? 'lon'}`;
      const population = typeof city.population === 'number' ? city.population : null;
      const rawName = city.name;
      const entry: CityDirectoryEntry = {
        key,
        name: rawName,
        displayName: formatCityDisplayName(rawName),
        population,
        lat: typeof city.lat === 'number' ? city.lat : null,
        lon: typeof city.lon === 'number' ? city.lon : null,
        feature: city,
      };
      const existing = map.get(key);
      if (!existing || (population ?? 0) > (existing.population ?? 0)) {
        map.set(key, entry);
      }
    });
    const entries = Array.from(map.values()).sort((a, b) => {
      return a.displayName.localeCompare(b.displayName, 'en', { sensitivity: 'base' });
    });
    return { count: entries.length, entries };
  }, [cityPoints]);
  const hasCityData = cityDirectory.count > 0;
  const cityDatasetLabel = cityOverlayMeta?.label || 'Cities dataset';
  const capitalRawName = capitals[stateId as keyof typeof capitals] || '';
  const capitalDisplayName = React.useMemo(() => formatCityDisplayName(capitalRawName), [capitalRawName]);
  const coverageStats = cityCoverage[stateId];
  const coveragePercent = coverageStats ? Math.round((coverageStats.coverage || 0) * 1000) / 10 : null;
  const coverageThreshold = cityCoverageMeta?.minPopulation ? cityCoverageMeta.minPopulation.toLocaleString() : null;
  const missingExamples = coverageStats?.missingExamples?.slice(0, 3) || [];
  const previewEntries = React.useMemo(() => {
    if (!hasCityData) return [] as CityDirectoryEntry[];
    const entries = [...cityDirectory.entries];
    let capitalEntry: CityDirectoryEntry | null = null;
    if (capitalDisplayName) {
      const idx = entries.findIndex(entry => entry.displayName.localeCompare(capitalDisplayName, 'en', { sensitivity: 'base' }) === 0);
      if (idx !== -1) {
        capitalEntry = { ...entries.splice(idx, 1)[0], isCapital: true };
      }
    }
    const ranked = entries
      .slice()
      .sort((a, b) => (b.population ?? 0) - (a.population ?? 0))
      .map(entry => ({ ...entry, isCapital: false }));
    const result: CityDirectoryEntry[] = [];
    if (capitalEntry) result.push(capitalEntry);
    result.push(...ranked.slice(0, capitalEntry ? 9 : 10));
    return result.slice(0, 10);
  }, [capitalDisplayName, cityDirectory.entries, hasCityData]);

  const previewCityPoints = React.useMemo<TieredCityFeature[]>(() => {
    if (!previewEntries.length) return [];
    const hasCapital = previewEntries.some(entry => entry.isCapital);
    return previewEntries
      .map((entry, index) => {
        if (!entry.feature) return null;
        const nonCapitalRank = entry.isCapital ? 0 : index + 1 - (hasCapital ? 1 : 0);
        const tier = entry.isCapital ? 0 : nonCapitalRank <= 3 ? 1 : 2;
        return { ...entry.feature, tier, previewRank: nonCapitalRank } as TieredCityFeature;
      })
      .filter((entry): entry is TieredCityFeature => !!entry);
  }, [previewEntries]);

  const mapCityPoints = previewCityPoints.length ? previewCityPoints : cityPoints;

  const fullCityList = cityDirectory.entries;
  const hasSearchTerm = citySearch.trim().length >= 2;
  const filteredCities = React.useMemo(() => {
    if (!hasCityData) return [] as CityDirectoryEntry[];
    if (!hasSearchTerm) return fullCityList;
    const query = citySearch.trim().toLowerCase();
    return fullCityList.filter(entry => entry.displayName.toLowerCase().includes(query));
  }, [fullCityList, hasCityData, hasSearchTerm, citySearch]);
  const isCapitalCity = React.useCallback((entry: CityDirectoryEntry) => {
    if (!capitalDisplayName) return false;
    return entry.displayName.localeCompare(capitalDisplayName, 'en', { sensitivity: 'base' }) === 0;
  }, [capitalDisplayName]);

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 flex-grow bg-surface">
      <div className="flex items-center gap-4">
        {onBack && (
          <button
            onClick={onBack}
            className="px-3 py-1 rounded border border-soft bg-panel text-xs font-medium text-muted hover:bg-surface transition-colors"
          >
            ← Map
          </button>
        )}
  <h1 className="text-2xl font-bold tracking-tight font-sans">{state.name}</h1>
      </div>

      <section className="relative">
        {overlayControls && overlayControls.length > 0 && (
          <OverlayPanel
            controls={overlayControls.filter(ctrl => ctrl.key !== 'regions')}
            className="absolute top-3 right-3 z-20"
          />
        )}
        <StateMapView
          atlas={atlas}
          stateId={stateId}
          overlayLabel={overlayLabelSummary}
          overlayLayers={overlayLayers}
          cityPoints={mapCityPoints}
        />
        {legendLayers.length > 0 && (
          <div
            className="absolute left-2 bottom-2 z-10 backdrop-blur-sm rounded shadow p-2 flex flex-col gap-2 max-w-[200px] border border-soft"
            style={{ backgroundColor: 'hsla(var(--color-panel) / 0.9)' }}
          >
            <div className="text-[10px] font-semibold tracking-wide text-muted uppercase">
              Overlays
            </div>
            {legendLayers.map(l => (
              <div key={l.key} className="flex items-center gap-2">
                <span
                  className="inline-block w-3 h-3 rounded-sm"
                  style={{
                    background: l.fill || 'rgba(59,130,246,0.35)',
                    border: `1px solid ${l.stroke || '#2563eb'}`,
                  }}
                />
                <span className="text-[11px] leading-tight">{l.label}</span>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="rounded-2xl border border-soft bg-panel p-4 md:p-5 space-y-4">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h2 className="text-xl font-bold font-sans text-muted">Cities</h2>
            <p className="text-sm text-muted">
              {hasCityData
                ? `Pulled ${cityDirectory.count.toLocaleString()} incorporated places from ${cityDatasetLabel}. Listing the capital first, followed by the nine most populous places.`
                : `City data for ${state.name} will appear here once the dataset loads.`}
            </p>
            {coverageStats && (
              <p className="text-xs text-muted/80">
                Coverage: {coverageStats.covered.toLocaleString()} of {coverageStats.source.toLocaleString()} active
                {coverageThreshold ? ` (≥ ${coverageThreshold} pop)` : ''} places tracked
                {typeof coveragePercent === 'number' ? ` (${coveragePercent.toFixed(1)}%)` : ''}.
                {missingExamples.length
                  ? ` Missing examples: ${missingExamples.join(', ')}`
                  : ' Fully synced with the source dataset.'}
              </p>
            )}
          </div>
        </div>
        {hasCityData && (
          <div className="space-y-3">
            <div className="max-h-[360px] overflow-y-auto rounded-xl border border-dashed border-soft divide-y divide-soft bg-surface/40">
              {previewEntries.map(city => {
                const capitalBadge = city.isCapital ?? isCapitalCity(city);
                return (
                  <div key={city.key} className="flex items-center justify-between gap-4 px-3 py-2">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-semibold leading-tight">{city.displayName || city.name}</span>
                        {capitalBadge && (
                          <span className="px-2 py-0.5 rounded-full bg-muted/20 text-[10px] font-semibold uppercase tracking-wide text-muted">
                            Capital
                          </span>
                        )}
                      </div>
                    <div className="text-[11px] uppercase tracking-wide text-muted">
                      {typeof city.lat === 'number' && typeof city.lon === 'number'
                        ? `Lat ${city.lat.toFixed(3)} • Lon ${city.lon.toFixed(3)}`
                        : 'Coordinates unavailable'}
                    </div>
                    </div>
                    <div className="text-right">
                      <span className="block text-[11px] uppercase tracking-wide text-muted">Population</span>
                      <span className="text-sm font-semibold">
                        {typeof city.population === 'number' ? populationFormatter.format(city.population) : '—'}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
            <button
              type="button"
              onClick={() => setShowAllCities(true)}
              className="w-full px-4 py-2 rounded-full border border-soft text-sm font-semibold hover:border-[hsl(var(--color-primary))] hover:text-[hsl(var(--color-primary))] hover:bg-primary-soft transition-colors"
            >
              Show all cities
            </button>
          </div>
        )}
      </section>

      <div className="grid md:grid-cols-3 gap-6 auto-rows-max">
        <section className="md:col-span-2 space-y-4 order-1">
          {detail?.officials?.length && (
            <div>
              <h2 className="text-xl font-bold font-sans text-muted">Officials</h2>
              <div className="flex flex-wrap gap-3">
                {detail.officials.map(o => (
                  <button
                    key={o.id}
                    onClick={() => onOfficialSelect && onOfficialSelect(o.id)}
                    className={`group flex flex-col items-center w-28 p-2 rounded-lg border ${
                      o.placeholder ? 'border-dashed border-soft' : 'border-soft'
                    } hover:border-[hsl(var(--color-primary))] hover:shadow focus:outline-none focus:ring-2 focus:ring-[hsl(var(--color-primary))]`}
                  >
                    <div className="w-20 h-20 rounded-md bg-gradient-to-br from-gray-200 to-gray-300 dark:from-gray-700 dark:to-gray-800 mb-2 flex items-center justify-center text-[10px] text-gray-500 overflow-hidden">
                      {o.portrait_url ? (
                        <img src={o.portrait_url} alt={o.name} className="object-cover w-full h-full" />
                      ) : (
                        o.role.split(' ')[0]
                      )}
                    </div>
                    <span
                      className={`text-xs font-medium text-center leading-tight line-clamp-2 ${
                        o.placeholder ? 'italic text-gray-500' : ''
                      }`}
                    >
                      {o.name}
                    </span>
                    <span className="text-[10px] text-gray-500 dark:text-gray-400 mt-0.5">{o.role}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
          <div>
            <h2 className="text-xl font-bold font-sans text-muted">Resources</h2>
            <ul className="text-sm list-disc pl-5 space-y-1">
              {detail && resourceItems.length ? (
                resourceItems.map(item => (
                  <li key={item.url} className="flex flex-col gap-0.5">
                    <a
                      className="text-accent underline hover:opacity-80"
                      href={item.url}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      {item.label}
                    </a>
                    {item.isStateSite && (
                      <span className="text-[10px] uppercase tracking-wide text-gray-500 dark:text-gray-400">
                        Official State Site
                      </span>
                    )}
                  </li>
                ))
              ) : (
                <li>Links will appear here.</li>
              )}
            </ul>
          </div>
        </section>
        <aside className="space-y-4 order-3 md:order-2">
          <div className="p-4 rounded border border-soft bg-panel text-xs text-muted">
            <div>
              <strong>State ID:</strong> {state.id}
            </div>
            <div>
              <strong>Centroid:</strong> {state.centroid.map(v => v.toFixed(1)).join(', ')}
            </div>
          </div>
        </aside>
        <section className="space-y-3 order-2 md:order-3 md:col-span-3">
          <h2 className="text-xl font-bold font-sans text-muted">House Representation</h2>
          <ul className="text-sm list-disc pl-5 space-y-1">
            {detail ? (
              <li>
                <strong>House Districts:</strong> {detail.federal_representation.house_districts}
              </li>
            ) : (
              <li>Representation data pending.</li>
            )}
          </ul>
          {detail && (
            <HouseCarousel
              representatives={houseRepresentatives}
              previewLimit={previewLimit}
              onViewAll={hasMoreRepresentatives ? onViewHouseDelegation : undefined}
            />
          )}
        </section>
      </div>
      {showAllCities && hasCityData && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
          <div className="relative w-full max-w-3xl max-h-[90vh] overflow-hidden rounded-2xl border border-soft bg-panel shadow-xl">
            <div className="flex items-start justify-between gap-4 border-b border-soft px-5 py-4">
              <div>
                <h3 className="text-lg font-bold leading-tight">All cities in {state.name}</h3>
                <p className="text-xs text-muted">
                  {hasSearchTerm
                    ? `Showing ${filteredCities.length.toLocaleString()} match${filteredCities.length === 1 ? '' : 'es'}.`
                    : `Showing all ${cityDirectory.count.toLocaleString()} places.`}
                </p>
              </div>
              <button
                aria-label="Close city list"
                className="rounded-full p-2 text-muted hover:text-foreground hover:bg-surface"
                onClick={() => setShowAllCities(false)}
              >
                ×
              </button>
            </div>
            <div className="px-5 py-4 border-b border-soft">
              <label className="block text-xs uppercase tracking-wide text-muted mb-1" htmlFor="city-search">
                Search by name
              </label>
              <input
                id="city-search"
                type="search"
                value={citySearch}
                onChange={e => setCitySearch(e.target.value)}
                placeholder="Type at least two letters"
                className="w-full rounded-lg border border-soft bg-surface px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[hsl(var(--color-primary))]"
              />
              <p className="mt-1 text-[11px] text-muted">
                {hasSearchTerm ? 'Filtering list…' : 'Filtering begins after 2 characters.'}
              </p>
            </div>
            <div className="max-h-[55vh] overflow-y-auto divide-y divide-soft">
              {filteredCities.length ? (
                filteredCities.map(city => {
                  const capitalBadge = city.isCapital ?? isCapitalCity(city);
                  return (
                    <div key={city.key} className="flex items-center justify-between gap-4 px-5 py-3">
                      <div>
                        <div className="flex items-center gap-2">
                          <span className="font-semibold leading-tight">{city.displayName || city.name}</span>
                          {capitalBadge && (
                            <span className="px-2 py-0.5 rounded-full bg-muted/20 text-[10px] font-semibold uppercase tracking-wide text-muted">
                              Capital
                            </span>
                          )}
                        </div>
                      <div className="text-[11px] uppercase tracking-wide text-muted">
                        {typeof city.lat === 'number' && typeof city.lon === 'number'
                          ? `Lat ${city.lat.toFixed(3)} • Lon ${city.lon.toFixed(3)}`
                          : 'Coordinates unavailable'}
                      </div>
                    </div>
                    <div className="text-right">
                      <span className="block text-[11px] uppercase tracking-wide text-muted">Population</span>
                      <span className="text-sm font-semibold">
                        {typeof city.population === 'number' ? populationFormatter.format(city.population) : '—'}
                      </span>
                    </div>
                  </div>
                );
                })
              ) : (
                <div className="px-5 py-10 text-center text-sm text-muted">
                  No cities match “{citySearch}”.
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default StatePage;