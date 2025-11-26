import React, { useState, useMemo, useEffect } from 'react';
import { Atlas, Official } from './types';
import { stateData, loadStateDetail, createEmptyDetail } from './data/stateData';
import { loadAtlas } from './data/getAtlas';
import MapView from './components/MapView';
import ListView from './components/ListView';
import StatePage from './components/StatePage';
import OfficialPage from './components/OfficialPage';
import HouseDelegationPage from './components/HouseDelegationPage';
import { loadOverlay, overlayRegistry } from './data/overlays';
import type { OverlayLayer } from './types';
import InfoPanel, { InfoPanelTab } from './components/InfoPanel';
import { IconBrandTabler, IconInfoCircle, IconList, IconMap } from './components/Icons';
import FindLauncher from './components/FindLauncher';
import FindPage, { FindResult } from './components/FindPage';

type ViewMode = 'map' | 'list';
const App: React.FC = () => {
  const [selectedStateId, setSelectedStateId] = useState<string | null>(null);
  const [viewMode, setViewMode] = useState<ViewMode>('map');
  const [atlasData, setAtlasData] = useState<Atlas | null>(null);
  const [atlasError, setAtlasError] = useState<string | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [dynamicDetail, setDynamicDetail] = useState<any>(null);
  const [selectedOfficialId, setSelectedOfficialId] = useState<string | null>(null);
  const [overlays, setOverlays] = useState<OverlayLayer[]>([]);
  const [activeOverlayKeys, setActiveOverlayKeys] = useState<Set<string>>(new Set());
  const [showHouseDelegation, setShowHouseDelegation] = useState(false);
  const [infoPanelOpen, setInfoPanelOpen] = useState(false);
  const [infoPanelTab, setInfoPanelTab] = useState<InfoPanelTab>('settings');
  const [findContext, setFindContext] = useState<{ open: boolean; loading: boolean; query: string; result: FindResult; error: string | null }>({
    open: false,
    loading: false,
    query: '',
    result: null,
    error: null,
  });

  useEffect(() => {
    loadAtlas().then(setAtlasData).catch(err => setAtlasError(err?.message || 'Failed to load map data'));
  }, []);

  // Load persisted overlay selection
  useEffect(() => {
    try {
      const stored = localStorage.getItem('activeOverlays');
      if (stored) {
        const arr: string[] = JSON.parse(stored);
        if (Array.isArray(arr)) setActiveOverlayKeys(new Set(arr));
        // Preload those layers
        (async () => {
          for (const key of arr) {
            if (!overlays.find(o=>o.key===key)) {
              const layer = await loadOverlay(key);
              if (layer) setOverlays(prev => prev.find(p=>p.key===layer.key) ? prev : [...prev, layer]);
            }
          }
        })();
      }
    } catch {}

    // Always-load hidden base layers like water and essential city points
    (async () => {
      try {
        const waterLayer = await loadOverlay('water-bodies');
        if (waterLayer) {
          setOverlays(prev => prev.find(p => p.key === waterLayer.key) ? prev : [...prev, waterLayer]);
        }
      } catch {}
    })();

    (async () => {
      try {
        if (!overlays.find(o=>o.key==='cities')) {
          const layer = await loadOverlay('cities');
          if (layer) setOverlays(prev => prev.find(p=>p.key===layer.key) ? prev : [...prev, layer]);
        }
        setActiveOverlayKeys(prev => {
          if (prev.has('cities')) return prev;
          const next = new Set(prev); next.add('cities'); return next;
        });
      } catch {}
    })();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Persist overlay selections
  useEffect(() => {
    try {
      localStorage.setItem('activeOverlays', JSON.stringify(Array.from(activeOverlayKeys)));
    } catch {}
  }, [activeOverlayKeys]);

  const sortedStates = useMemo(() => {
    if (!atlasData) return [];
    return [...atlasData.states].sort((a, b) => a.name.localeCompare(b.name));
  }, [atlasData]);

  const matchStateIdFromQuery = (query: string): string | null => {
    const normalized = query.trim().toLowerCase();
    if (!normalized) return null;
    const candidates = atlasData?.states?.map((state) => ({ id: state.id, name: state.name }))
      ?? Object.values(stateData).map((state) => ({ id: state.id, name: state.name }));
    const exact = candidates.find((entry) => entry.id.toLowerCase() === normalized || entry.name.toLowerCase() === normalized);
    if (exact) return exact.id;
    const partial = candidates.find((entry) => entry.name.toLowerCase().includes(normalized));
    return partial ? partial.id : null;
  };

  const matchOfficialByName = (query: string): { stateId: string; official: Official } | null => {
    const normalized = query.trim().toLowerCase();
    if (!normalized) return null;
    for (const [stateId, detail] of Object.entries(stateData)) {
      const official = detail.officials?.find((o) => o.name.toLowerCase().includes(normalized));
      if (official) return { stateId, official };
    }
    if (dynamicDetail?.officials?.length && dynamicDetail.id) {
      const fallbackOfficial = dynamicDetail.officials.find((o: Official) => o.name.toLowerCase().includes(normalized));
      if (fallbackOfficial) return { stateId: dynamicDetail.id, official: fallbackOfficial };
    }
    return null;
  };

  const handleStateSelect = async (stateId: string) => {
    setSelectedStateId(stateId);
    setShowHouseDelegation(false);
    setSelectedOfficialId(null);
    setDetailLoading(true);
    const data = await loadStateDetail(stateId);
    setDynamicDetail(data);
    setDetailLoading(false);
  };

  const handleBack = () => {
    if (selectedOfficialId) {
      setSelectedOfficialId(null);
      return;
    }
    if (showHouseDelegation) {
      setShowHouseDelegation(false);
      return;
    }
    setSelectedStateId(null);
  };
  async function toggleOverlay(key: string) {
    // Load layer on demand
    if (!overlays.find(o => o.key === key)) {
      const layer = await loadOverlay(key);
      if (layer) setOverlays(prev => [...prev, layer]);
    }
    setActiveOverlayKeys(prev => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key); else next.add(key);
      return next;
    });
  }

  const activeOverlays = overlays.filter(o => o.key === 'water-bodies' || activeOverlayKeys.has(o.key));

  const handleOpenSettings = (tab: InfoPanelTab = 'settings') => {
    setInfoPanelTab(tab);
    setInfoPanelOpen(true);
  };

  const handleFindSubmit = async (query: string) => {
    const trimmed = query.trim();
    if (!trimmed) return;
    setFindContext({ open: true, loading: true, query: trimmed, result: null, error: null });

    if (/^\d{5}$/.test(trimmed)) {
      setFindContext({ open: true, loading: false, query: trimmed, result: { type: 'zip', zip: trimmed }, error: null });
      return;
    }

    let focusOfficialName: string | undefined;
    let matchedStateId = matchStateIdFromQuery(trimmed);
    if (!matchedStateId) {
      const officialMatch = matchOfficialByName(trimmed);
      if (officialMatch) {
        matchedStateId = officialMatch.stateId;
        focusOfficialName = officialMatch.official.name;
      }
    }

    if (matchedStateId) {
      try {
        let detail = stateData[matchedStateId];
        if (!detail) {
          detail = await loadStateDetail(matchedStateId);
        }
        if (!detail && atlasData) {
          const fallbackName = atlasData.states.find((s) => s.id === matchedStateId)?.name || matchedStateId;
          detail = createEmptyDetail(matchedStateId, fallbackName);
        }
        setFindContext({
          open: true,
          loading: false,
          query: trimmed,
          result: { type: 'state', stateId: matchedStateId, detail, focusOfficialName },
          error: null,
        });
      } catch (err: any) {
        setFindContext({
          open: true,
          loading: false,
          query: trimmed,
          result: null,
          error: err?.message || 'Unable to load data for that search.',
        });
      }
      return;
    }

    setFindContext({
      open: true,
      loading: false,
      query: trimmed,
      result: { type: 'city', cityName: trimmed },
      error: null,
    });
  };

  const handleCloseFind = () => {
    setFindContext((prev) => ({ ...prev, open: false, loading: false }));
  };

  const handleFindOpenState = (stateId: string) => {
    handleCloseFind();
    handleStateSelect(stateId);
  };

  const handleFindNavigate = React.useCallback((destination: string, context?: Record<string, unknown>) => {
    console.info('Find navigation placeholder:', destination, context);
  }, []);
  
  const selectedStateDetails = selectedStateId ? (dynamicDetail || stateData[selectedStateId] || (atlasData ? createEmptyDetail(selectedStateId, atlasData.states.find(s=>s.id===selectedStateId)?.name || selectedStateId) : null)) : null;

  const isStatePage = !!selectedStateId;
  return (
    <div className="antialiased bg-app min-h-screen w-full flex flex-col font-sans">
      <div
        className={`${isStatePage ? 'w-full min-h-screen' : 'w-full flex-1'} mx-auto flex flex-col shadow-2xl bg-panel max-w-6xl lg:rounded-3xl lg:my-6 border border-soft relative`}
        style={isStatePage ? undefined : { minHeight: '100dvh', height: '100dvh', overflow: 'hidden' }}
      >
        {selectedStateId && (detailLoading || selectedStateDetails) ? (
          detailLoading ? (
            <div className="flex h-full items-center justify-center text-sm text-gray-500">Loading {selectedStateId}…</div>
          ) : (
            <div className="flex flex-col flex-grow overflow-y-auto">
              {selectedOfficialId && selectedStateDetails?.officials ? (
                <OfficialPage
                  state={selectedStateDetails}
                  official={selectedStateDetails.officials.find((o: any) => o.id === selectedOfficialId)!}
                  onBack={handleBack}
                  onBackToState={() => setSelectedOfficialId(null)}
                />
              ) : showHouseDelegation ? (
                <HouseDelegationPage
                  state={selectedStateDetails}
                  onBack={() => setShowHouseDelegation(false)}
                />
              ) : (
                <StatePage
                  atlas={atlasData!}
                  stateId={selectedStateId}
                  detail={selectedStateDetails}
                  onBack={handleBack}
                  onOfficialSelect={(id) => setSelectedOfficialId(id)}
                  onViewHouseDelegation={() => setShowHouseDelegation(true)}
                  overlayControls={overlayRegistry
                    .filter(meta => meta.key !== 'regions' && meta.key !== 'cities')
                    .filter(meta => !meta.states || meta.states.includes(selectedStateId))
                    .map(meta => ({
                      key: meta.key,
                      label: meta.label,
                      active: activeOverlayKeys.has(meta.key),
                      toggle: () => toggleOverlay(meta.key)
                    }))}
                  activeOverlays={activeOverlays}
                />
              )}
            </div>
          )
        ) : (
          <>
            <header className="p-4 border-b border-soft flex justify-between items-center bg-panel flex-shrink-0">
              <div className="flex items-center space-x-2">
                <IconBrandTabler className="w-8 h-8 text-[hsl(var(--color-primary))]" />
                <h1 className="text-xl font-bold tracking-tight">USA Representative Map</h1>
              </div>
              <button
                onClick={() => handleOpenSettings('settings')}
                className="p-2 rounded-full hover:bg-primary-soft transition-colors"
                aria-label="Settings and about"
              >
                <IconInfoCircle className="w-6 h-6" />
              </button>
            </header>
            <main className="flex-grow relative overflow-hidden min-h-[420px] pb-24 sm:pb-28 lg:pb-32">
              {!atlasData && !atlasError && (
                <div className="absolute inset-0 flex items-center justify-center text-sm text-gray-500">Loading map…</div>
              )}
              {atlasError && (
                <div className="absolute inset-0 flex items-center justify-center text-sm text-red-600">{atlasError}</div>
              )}
              {atlasData && viewMode === 'map' && (
                <MapView
                  atlas={atlasData}
                  onStateSelect={handleStateSelect}
                  selectedStateId={selectedStateId}
                  activeOverlays={activeOverlays}
                  overlayControls={overlayRegistry
                    .filter(meta => !meta.hidden && meta.key !== 'regions' && meta.key !== 'cities')
                    .map(meta => ({
                      key: meta.key,
                      label: meta.label,
                      active: activeOverlayKeys.has(meta.key),
                      toggle: () => toggleOverlay(meta.key)
                    }))}
                />
              )}
              {atlasData && viewMode === 'list' && (
                <ListView states={sortedStates} onStateSelect={handleStateSelect} />
              )}
            </main>
            <footer className="border-t border-gray-200 dark:border-gray-800 px-2 pt-2 pb-4 flex justify-around bg-gray-50 dark:bg-gray-900/50 flex-shrink-0">
              <button
                onClick={() => setViewMode('map')}
                aria-label="Map View"
              >
                <IconMap className="w-5 h-5" />
                <span>Map</span>
              </button>
              <button
                onClick={() => setViewMode('list')}
                className={`flex items-center space-x-2 px-6 py-2 rounded-full font-semibold transition-colors ${viewMode === 'list' ? 'bg-[hsl(var(--color-primary))] text-white' : 'hover:bg-primary-soft'}`}
                aria-label="List View"
              >
                <IconList className="w-5 h-5" />
                <span>List</span>
              </button>
            </footer>
          </>
        )}
      </div>
      <InfoPanel
        open={infoPanelOpen}
        activeTab={infoPanelTab}
        onTabChange={tab => setInfoPanelTab(tab)}
        onClose={() => setInfoPanelOpen(false)}
      />
  <FindLauncher onSubmit={handleFindSubmit} busy={findContext.loading} placement={isStatePage ? 'state' : 'global'} />
      {findContext.open && (
        <FindPage
          query={findContext.query}
          loading={findContext.loading}
          result={findContext.result}
          error={findContext.error}
          onClose={handleCloseFind}
          onOpenState={handleFindOpenState}
          onNavigate={handleFindNavigate}
        />
      )}
    </div>
  );
};

export default App;
