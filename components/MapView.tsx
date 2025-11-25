import React, { useRef, useEffect, useState } from 'react';
import * as d3 from 'd3';
import { Atlas, OverlayLayer, CityFeature } from '../types';
import { MIN_ZOOM, MAX_ZOOM, ZOOM_STEP } from '../constants';
import { IconZoomIn, IconZoomOut } from './Icons';
import OverlayPanel from './OverlayPanel';
import { useMapOverlays } from '../utils/useMapOverlays';
import { capitals } from '../data/capitals';
import { useDebounce } from '../utils/useDebounce';
import CanvasOverlay from './CanvasOverlay';
import { intersects } from '../utils/geometry';
import { resolveLabelMetrics, CITY_LABEL_ZOOM_STOPS } from '../utils/labelScaling';
import { normalizeCityName, sanitizeCityLabel, jitterFromString } from '../utils/cityLabeling';
import { DecoratedCity, CityLabelPlacement, computeCityPlacements } from '../utils/cityPlacements';

interface OverlayControlMeta {
  key: string;
  label: string;
  active: boolean;
  toggle: () => void | Promise<void>;
}

// Extend OverlayLayer with optional ad-hoc properties used in the app
export type AppOverlayLayer = OverlayLayer & {
  hidden?: boolean;
  pointLayer?: boolean;
  points?: CityFeature[];
};

interface MapViewProps {
  atlas: Atlas;
  selectedStateId: string | null;
  onStateSelect: (stateId: string) => void;
  overlayControls?: OverlayControlMeta[];
  activeOverlays?: AppOverlayLayer[];
}

type OverlayHitEntry = {
  layerKey: string;
  layerLabel: string;
  featureId: string;
  featureName?: string;
  bbox: [number, number, number, number];
  path: string;
  path2d?: Path2D | null;
};

const MapView: React.FC<MapViewProps> = ({
  atlas,
  onStateSelect,
  selectedStateId,
  overlayControls,
  activeOverlays,
}) => {
  const diag = typeof window !== 'undefined' && /[?&]diag=1/.test(window.location.search);
  const capitalNameSet = React.useMemo(() => new Set(Object.values(capitals).map((name) => name.toLowerCase())), []);
  const marqueeCityNames = React.useMemo(
    () =>
      new Set(
        [
          'los angeles',
          'new york',
          'chicago',
          'miami',
          'dallas',
          'seattle',
          'denver',
          'atlanta',
          'honolulu',
        ]
      ),
    []
  );
  const WELL_KNOWN_POP_THRESHOLD = 200000;
  const marqueeCityCatalog = React.useMemo(
    () => ({
      'los angeles': { id: 'marquee-los-angeles', label: 'Los Angeles', stateId: 'CA', lat: 34.0549, lon: -118.2426, population: 3896329 },
      'new york': { id: 'marquee-new-york', label: 'New York', stateId: 'NY', lat: 40.7128, lon: -74.006, population: 8804190 },
      'chicago': { id: 'marquee-chicago', label: 'Chicago', stateId: 'IL', lat: 41.8781, lon: -87.6298, population: 2746388 },
      'miami': { id: 'marquee-miami', label: 'Miami', stateId: 'FL', lat: 25.7617, lon: -80.1918, population: 442241 },
      'dallas': { id: 'marquee-dallas', label: 'Dallas', stateId: 'TX', lat: 32.7767, lon: -96.797, population: 1304379 },
      'seattle': { id: 'marquee-seattle', label: 'Seattle', stateId: 'WA', lat: 47.6062, lon: -122.3321, population: 733919 },
      'denver': { id: 'marquee-denver', label: 'Denver', stateId: 'CO', lat: 39.7392, lon: -104.9903, population: 711463 },
      'atlanta': { id: 'marquee-atlanta', label: 'Atlanta', stateId: 'GA', lat: 33.749, lon: -84.388, population: 498715 },
      'honolulu': { id: 'marquee-honolulu', label: 'Honolulu', stateId: 'HI', lat: 21.3069, lon: -157.8583, population: 345510 },
    }),
    []
  );
  const overlayShortLabels = React.useMemo(
    () => ({
      counties: 'County',
      'congressional-districts': 'District',
      'urban-areas': 'Urban Area',
      regions: 'Region',
    }),
    []
  );
  const formatOverlayLabel = React.useCallback((entry: OverlayHitEntry) => {
    const shortLabel = overlayShortLabels[entry.layerKey] || entry.layerLabel;
    if (!entry.featureName) return shortLabel;
    const normalizedFeature = entry.featureName.toLowerCase();
    if (normalizedFeature.includes(shortLabel.toLowerCase())) {
      return entry.featureName;
    }
    return `${entry.featureName} (${shortLabel})`;
  }, [overlayShortLabels]);

  // Refs & state
  const svgRef = useRef<SVGSVGElement>(null);
  const gRef = useRef<SVGGElement>(null);
  const zoomRef = useRef<d3.ZoomBehavior<SVGSVGElement, unknown> | null>(null);
  const [transform, setTransform] = useState(d3.zoomIdentity);
  const debouncedTransform = useDebounce(transform, 35);
  const selectionZoom = Math.max(MIN_ZOOM, debouncedTransform.k || MIN_ZOOM);
  const selectionLabelMetrics = React.useMemo(
    () => resolveLabelMetrics(selectionZoom, CITY_LABEL_ZOOM_STOPS),
    [selectionZoom]
  );
  const [hoveredStateId, setHoveredStateId] = useState<string | null>(null);
  const [pointer, setPointer] = useState<{ x: number; y: number } | null>(null);
  const [pointerSvg, setPointerSvg] = useState<{ x: number; y: number } | null>(null);
  const [pointerAtlas, setPointerAtlas] = useState<{ x: number; y: number } | null>(null);
  const [overlayHoverDetails, setOverlayHoverDetails] = useState<OverlayHitEntry[]>([]);
  const overlayHitCtxRef = useRef<CanvasRenderingContext2D | null>(null);
  const liveRegionRef = useRef<HTMLDivElement>(null);

  // Derived overlay + point data via hook
  const {
    overlayPaths,
    alaskaPaths,
    hawaiiPaths,
    visibleCityPoints,
    visibleAlaskaCityPoints,
    visibleHawaiiCityPoints,
    alaskaTransform,
    hawaiiTransform,
  } = useMapOverlays({ atlas, activeOverlays, transformK: debouncedTransform.k, diag });

  const atlasProjection = React.useMemo(() => {
    const proj = d3.geoAlbersUsa();
    if (atlas.projectionParams?.scale && atlas.projectionParams?.translate) {
      proj.scale(atlas.projectionParams.scale).translate(atlas.projectionParams.translate as [number, number]);
    } else {
      proj.fitExtent([[0, 0], [atlas.width, atlas.height]], { type: 'Sphere' } as any);
    }
    return proj;
  }, [atlas.height, atlas.width, atlas.projectionParams]);

  useEffect(() => {
    if (typeof document === 'undefined') return;
    const canvas = document.createElement('canvas');
    overlayHitCtxRef.current = canvas.getContext('2d');
    return () => {
      overlayHitCtxRef.current = null;
    };
  }, []);

  // Parse inset transforms like "scale(1.5) translate(tx,ty)"
  function parseInset(tf: string | undefined): { scale: number; tx: number; ty: number } | null {
    if (!tf) return null;
    const m1 = tf.match(/scale\(([-0-9.]+)\)/);
    const m2 = tf.match(/translate\(([-0-9.]+),\s*([-0-9.]+)\)/);
    if (!m1 || !m2) return null;
    return { scale: Number(m1[1]), tx: Number(m2[1]), ty: Number(m2[2]) };
  }
  const akInset = parseInset(alaskaTransform);
  const hiInset = parseInset(hawaiiTransform);

  const stateBBoxes = React.useMemo(() => atlas.states.map((state) => ({ id: state.id, bbox: state.bbox })), [atlas.states]);

  const nationalVisibleCities = React.useMemo<DecoratedCity[]>(() => {
    const cityLayer = activeOverlays?.find((o) => o.key === 'cities' && o.points);
    if (!cityLayer?.points) return [];

    const normZoom = Math.max(MIN_ZOOM, debouncedTransform.k || MIN_ZOOM);
    const tier = normZoom < 1.5 ? 'nation' : normZoom < 3.2 ? 'region' : 'local';
    const tierConfig = tier === 'nation'
      ? { target: 64, perStateCap: 3, perCellCap: 2, minScreenDistance: 118, capitalBoost: 2.9 }
      : tier === 'region'
        ? { target: 180, perStateCap: 6, perCellCap: 3, minScreenDistance: 58, capitalBoost: 2.2 }
        : { target: 320, perStateCap: 10, perCellCap: 6, minScreenDistance: 28, capitalBoost: 1.5 };

    const viewMinX = -debouncedTransform.x / normZoom;
    const viewMinY = -debouncedTransform.y / normZoom;
    const viewWidth = atlas.width / normZoom;
    const viewHeight = atlas.height / normZoom;
    const viewBounds = {
      minX: viewMinX - 30,
      maxX: viewMinX + viewWidth + 30,
      minY: viewMinY - 30,
      maxY: viewMinY + viewHeight + 30,
    };

    const findStateId = (x: number, y: number) => {
      for (const entry of stateBBoxes) {
        const [minX, minY, maxX, maxY] = entry.bbox;
        if (x >= minX && x <= maxX && y >= minY && y <= maxY) {
          return entry.id;
        }
      }
      return null;
    };

    const gridCols = normZoom > 2.8 ? 14 : 10;
    const gridRows = normZoom > 2.8 ? 8 : 6;
    const cellWidth = atlas.width / gridCols;
    const cellHeight = atlas.height / gridRows;
    const toCellKey = (x: number, y: number) => {
      const col = Math.min(gridCols - 1, Math.max(0, Math.floor(x / cellWidth)));
      const row = Math.min(gridRows - 1, Math.max(0, Math.floor(y / cellHeight)));
      return `${col}-${row}`;
    };

    const decorated = cityLayer.points
      .map((pt) => {
        if (typeof pt.x !== 'number' || typeof pt.y !== 'number') return null;
        const displayName = sanitizeCityLabel(pt.name || '');
        const normalizedName = normalizeCityName(pt.name || '');
        if (!displayName || !normalizedName) return null;
        const stateId = findStateId(pt.x, pt.y);
        const isCapital = capitalNameSet.has(normalizedName);
        const isMarquee = marqueeCityNames.has(normalizedName);
        const placementJitter = jitterFromString(normalizedName || pt.id || `${pt.x}-${pt.y}`);
        const populationValue = pt.population || 0;
        const meetsWellKnownCriteria = isMarquee || isCapital || populationValue >= WELL_KNOWN_POP_THRESHOLD;
        if (!meetsWellKnownCriteria) return null;
        const withinViewport = pt.x >= viewBounds.minX && pt.x <= viewBounds.maxX && pt.y >= viewBounds.minY && pt.y <= viewBounds.maxY;
        if (!withinViewport && !isMarquee) return null;
        const populationScore = populationValue ? Math.log10(Math.max(1, populationValue)) : 0;
        const jitterScore = (placementJitter - 0.5) * 0.2;
        const score = populationScore + jitterScore + (isCapital ? tierConfig.capitalBoost : 0) + (isMarquee ? 2.4 : 0);
        const labelImpact = Math.min(120, 18 + (normalizedName.length || 0) * 1.7 + (isCapital ? 8 : 0) + (isMarquee ? 10 : 0));
        return {
          ...pt,
          normalizedName,
          displayName,
          isCapital,
          isMarquee,
          labelImpact,
          score,
          stateId,
          withinViewport,
          placementJitter,
        } as DecoratedCity;
      })
      .filter((city): city is DecoratedCity => !!city)
      .sort((a, b) => b.score - a.score);

  const accepted: DecoratedCity[] = [];
  const perStateCounts = new Map<string, number>();
  const perCellCounts = new Map<string, number>();
  const minDistanceAtlas = tierConfig.minScreenDistance / normZoom;
  const spacingTightness = selectionLabelMetrics.spacing;

    const considerCandidate = (city: DecoratedCity, mode: 'default' | 'relaxed' | 'force' = 'default') => {
      const relaxed = mode !== 'default';
      const force = mode === 'force';
      const stateKey = city.stateId || '??';
      const stateCap = tierConfig.perStateCap + (city.isMarquee ? 1 : 0);
      if (!relaxed && (perStateCounts.get(stateKey) || 0) >= stateCap) return false;

      const cellKey = toCellKey(city.x, city.y);
      const cellCap = tierConfig.perCellCap + (city.isMarquee ? 1 : 0);
      if (!relaxed && (perCellCounts.get(cellKey) || 0) >= cellCap) return false;

      if (!relaxed && tier === 'nation' && !city.withinViewport && !city.isMarquee) return false;

  const jitterFactor = 0.85 + city.placementJitter * 0.35;
  const spacingBase = (minDistanceAtlas + city.labelImpact / 5.4) * jitterFactor * spacingTightness;
      const spacingMultiplier = force ? 0.45 : relaxed ? 0.75 : 1;
      const spacing = spacingBase * spacingMultiplier;
      let blocked = false;
      for (const placed of accepted) {
        const dx = placed.x - city.x;
        const dy = placed.y - city.y;
        const required = spacing + placed.labelImpact / (force ? 10 : 6.4);
        if (Math.hypot(dx, dy) < required) {
          blocked = true;
          if (!force) break;
        }
      }
      if (blocked && !force) return false;

      accepted.push(city);
      perStateCounts.set(stateKey, (perStateCounts.get(stateKey) || 0) + 1);
      perCellCounts.set(cellKey, (perCellCounts.get(cellKey) || 0) + 1);
      return true;
    };

    for (const city of decorated) {
      if (accepted.length >= tierConfig.target) break;
      considerCandidate(city, 'default');
    }

    if (accepted.length < tierConfig.target) {
      for (const city of decorated) {
        if (accepted.length >= tierConfig.target) break;
        if (accepted.includes(city)) continue;
        considerCandidate(city, 'relaxed');
      }
    }

    const normalizedAccepted = new Set(accepted.map((c) => c.normalizedName));
    marqueeCityNames.forEach((name) => {
      if (normalizedAccepted.has(name)) return;
      const fallback = (marqueeCityCatalog as Record<string, typeof marqueeCityCatalog[keyof typeof marqueeCityCatalog]>)[name];
      if (!fallback || !atlasProjection) return;
      const projected = atlasProjection([fallback.lon, fallback.lat]);
      if (!projected) return;
      const [x, y] = projected;
      if (!Number.isFinite(x) || !Number.isFinite(y)) return;
      const fallbackCity: DecoratedCity = {
        id: fallback.id,
        name: fallback.label,
        x,
        y,
        lon: fallback.lon,
        lat: fallback.lat,
        population: fallback.population,
        normalizedName: name,
        displayName: fallback.label,
        isCapital: capitalNameSet.has(name),
        isMarquee: true,
        labelImpact: 36,
        score: 1000,
        stateId: fallback.stateId,
        withinViewport: x >= viewBounds.minX && x <= viewBounds.maxX && y >= viewBounds.minY && y <= viewBounds.maxY,
        placementJitter: jitterFromString(name),
      };
      if (considerCandidate(fallbackCity, 'force')) {
        normalizedAccepted.add(name);
      }
    });

    const result: DecoratedCity[] = [];
    const seen = new Set<string>();
    for (const city of accepted) {
      const key = city.id || `${city.normalizedName}-${Math.round(city.x)}-${Math.round(city.y)}`;
      if (seen.has(key)) continue;
      seen.add(key);
      result.push(city);
    }

    return result;
  }, [activeOverlays, atlas.height, atlas.width, atlasProjection, capitalNameSet, debouncedTransform, marqueeCityCatalog, marqueeCityNames, stateBBoxes, selectionLabelMetrics.spacing]);

  const overlayHitEntries = React.useMemo(() => {
    if (!activeOverlays?.length) return [];
    const supportsPath2D = typeof Path2D !== 'undefined';
    const entries: OverlayHitEntry[] = [];
    activeOverlays.forEach((layer) => {
      if ((layer as any).pointLayer) return;
      const layerLabel = layer.label || layer.key;
      layer.features?.forEach((feature) => {
        if (!feature?.path || !feature?.bbox) return;
        entries.push({
          layerKey: layer.key,
          layerLabel,
          featureId: feature.id,
          featureName: feature.name,
          bbox: feature.bbox,
          path: feature.path,
          path2d: supportsPath2D ? new Path2D(feature.path) : null,
        });
      });
    });
    return entries;
  }, [activeOverlays]);

  const overlayHitsByState = React.useMemo(() => {
    const mapping = new Map<string, OverlayHitEntry[]>();
    if (!overlayHitEntries.length) return mapping;
    overlayHitEntries.forEach((entry) => {
      atlas.states.forEach((state) => {
        if (!intersects(state.bbox, entry.bbox)) return;
        if (!mapping.has(state.id)) mapping.set(state.id, []);
        mapping.get(state.id)!.push(entry);
      });
    });
    return mapping;
  }, [atlas.states, overlayHitEntries]);

  useEffect(() => {
    const ctx = overlayHitCtxRef.current;
    if (!pointerAtlas || !ctx || !overlayHitEntries.length) {
      setOverlayHoverDetails([]);
      return;
    }
    const candidates = hoveredStateId ? overlayHitsByState.get(hoveredStateId) || [] : overlayHitEntries;
    if (!candidates.length) {
      setOverlayHoverDetails([]);
      return;
    }
    const tolerance = 0.5;
    const hits: OverlayHitEntry[] = [];
    for (const entry of candidates) {
      if (!entry.path2d) continue;
      const [minX, minY, maxX, maxY] = entry.bbox;
      if (pointerAtlas.x < minX - tolerance || pointerAtlas.x > maxX + tolerance || pointerAtlas.y < minY - tolerance || pointerAtlas.y > maxY + tolerance) {
        continue;
      }
      if (ctx.isPointInPath(entry.path2d, pointerAtlas.x, pointerAtlas.y)) {
        hits.push(entry);
        if (hits.length >= 4) break;
      }
    }
    setOverlayHoverDetails(hits);
  }, [hoveredStateId, overlayHitEntries, overlayHitsByState, pointerAtlas]);

  const hoveredStateName = hoveredStateId ? atlas.states.find((s) => s.id === hoveredStateId)?.name : null;
  const overlaySummary = overlayHoverDetails.length ? overlayHoverDetails.map(formatOverlayLabel).join(' • ') : '';

  // Initialize zoom/pan (throttled with rAF to reduce state churn)
  useEffect(() => {
    if (!svgRef.current) return;
    const svgSel = d3.select(svgRef.current);
    const rafId = { current: 0 as number | null };
    const zoom = d3
      .zoom<SVGSVGElement, unknown>()
      .filter((event) => {
        const type = (event as any)?.type;
        if (type === 'wheel') {
          return (event as WheelEvent).ctrlKey;
        }
        if (type === 'dblclick') return false;
        return true;
      })
      .scaleExtent([MIN_ZOOM, MAX_ZOOM])
      .translateExtent([[0, 0], [atlas.width, atlas.height]])
      .on('zoom', (event) => {
        if (rafId.current) cancelAnimationFrame(rafId.current as number);
        rafId.current = requestAnimationFrame(() => {
          setTransform(event.transform);
        });
      });
    zoomRef.current = zoom;
    svgSel.call(zoom);

    // Centered initial transform
    const initial = d3.zoomIdentity
      .translate(atlas.width / 2, atlas.height / 2)
      .scale(MIN_ZOOM)
      .translate(-atlas.width / 2, -atlas.height / 2);
    svgSel.call(zoom.transform, initial);
    setTransform(initial);

    return () => {
      svgSel.on('.zoom', null);
      if (rafId.current) cancelAnimationFrame(rafId.current as number);
    };
  }, [atlas.width, atlas.height]);

  // Anchor for zooming toward cursor position
  function currentAnchor(): [number, number] {
    if (pointerSvg) return [pointerSvg.x, pointerSvg.y];
    return [atlas.width / 2, atlas.height / 2];
  }

  const handleZoomIn = () => {
    if (!svgRef.current || !zoomRef.current) return;
    d3.select(svgRef.current)
      .transition()
      .duration(220)
      .call(zoomRef.current.scaleBy as any, ZOOM_STEP, currentAnchor());
  };

  const handleZoomOut = () => {
    if (!svgRef.current || !zoomRef.current) return;
    d3.select(svgRef.current)
      .transition()
      .duration(220)
      .call(zoomRef.current.scaleBy as any, 1 / ZOOM_STEP, currentAnchor());
  };

  const stateFillColor = React.useCallback((stateId: string) => {
    if (diag) {
      if (stateId === selectedStateId) return 'hsla(var(--color-primary) / 0.4)';
      if (hoveredStateId === stateId) return 'hsla(var(--color-primary) / 0.2)';
      return 'transparent';
    }
    if (stateId === selectedStateId) return 'hsl(var(--color-primary))';
    if (hoveredStateId === stateId) return 'hsla(var(--color-primary) / 0.3)';
    return 'hsl(var(--color-border))';
  }, [diag, hoveredStateId, selectedStateId]);

  const stateStrokeColor = diag ? 'hsla(var(--color-text-muted) / 0.6)' : 'hsla(var(--color-background) / 0.9)';
  const normalizedZoom = Math.max(MIN_ZOOM, debouncedTransform.k || MIN_ZOOM);
  const smoothZoomRef = React.useRef(Math.max(MIN_ZOOM, transform.k || MIN_ZOOM));
  const styleZoom = React.useMemo(() => {
    const target = Math.max(MIN_ZOOM, transform.k || MIN_ZOOM);
    const previous = smoothZoomRef.current;
    const eased = previous + (target - previous) * 0.35;
    const next = Number.isFinite(eased) ? eased : target;
    smoothZoomRef.current = next;
    return next;
  }, [transform.k]);
  const renderLabelMetrics = React.useMemo(
    () => resolveLabelMetrics(styleZoom, CITY_LABEL_ZOOM_STOPS),
    [styleZoom]
  );
  const baseCityMarkerRadius = renderLabelMetrics.marker;
  const baseCityLabelFontSize = renderLabelMetrics.font;
  const cityLabelStrokeWidth = renderLabelMetrics.stroke;
  const baseCityLabelOffsetX = renderLabelMetrics.offsetX;
  const baseCityLabelOffsetY = renderLabelMetrics.offsetY;
  const detailZoomFactor = renderLabelMetrics.detail;
  const labelSpacingScale = renderLabelMetrics.spacing;
  const labelPaddingScale = renderLabelMetrics.padding;

  const cityLabelPlacements = React.useMemo<CityLabelPlacement[]>(() => {
    if (!nationalVisibleCities.length) return [];
    return computeCityPlacements(nationalVisibleCities, {
      normalizedZoom,
      transform: debouncedTransform,
      viewWidth: atlas.width,
      viewHeight: atlas.height,
  baseMarkerRadius: baseCityMarkerRadius,
      baseFontSize: baseCityLabelFontSize,
      baseOffsetX: baseCityLabelOffsetX,
      baseOffsetY: baseCityLabelOffsetY,
      strokeWidth: cityLabelStrokeWidth,
      detailZoomFactor,
      labelPaddingScale,
    });
  }, [nationalVisibleCities, normalizedZoom, debouncedTransform, atlas.width, atlas.height, baseCityLabelFontSize, baseCityMarkerRadius, baseCityLabelOffsetX, baseCityLabelOffsetY, cityLabelStrokeWidth, detailZoomFactor, labelPaddingScale]);

  return (
    <div className="w-full h-full bg-panel relative cursor-grab active:cursor-grabbing select-none">
      <svg
        ref={svgRef}
        viewBox={`0 0 ${atlas.width} ${atlas.height}`}
        className="w-full h-full"
        onMouseMove={(e) => {
          const rect = (e.currentTarget as SVGSVGElement).getBoundingClientRect();
          const clientX = e.clientX;
          const clientY = e.clientY;
          setPointer({ x: clientX, y: clientY });
          const svgX = ((clientX - rect.left) / rect.width) * atlas.width;
          const svgY = ((clientY - rect.top) / rect.height) * atlas.height;
          setPointerSvg({ x: svgX, y: svgY });
          const inverted = transform.invert ? transform.invert([svgX, svgY]) : [svgX, svgY];
          setPointerAtlas({ x: inverted[0], y: inverted[1] });
        }}
        onMouseLeave={() => {
          setPointer(null);
          setPointerSvg(null);
          setPointerAtlas(null);
        }}
      >
        <g ref={gRef} transform={transform.toString()}>
          {/* Base state shapes */}
          {atlas.states.map((state) => {
            return (
              <path
                key={state.id}
                d={state.path}
                role="button"
                tabIndex={0}
                aria-label={state.name}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    onStateSelect(state.id);
                  }
                }}
                className="non-scaling-stroke transition-all duration-150 ease-out cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-[hsl(var(--color-primary))] focus-visible:ring-offset-2 focus-visible:ring-offset-transparent"
                style={{ fill: stateFillColor(state.id), stroke: stateStrokeColor }}
                strokeWidth={diag ? 0.4 : 0.75}
                onClick={() => onStateSelect(state.id)}
                onMouseEnter={(e) => {
                  setHoveredStateId(state.id);
                  setPointer({ x: e.clientX, y: e.clientY });
                  if (liveRegionRef.current) liveRegionRef.current.textContent = state.name;
                }}
                onMouseMove={(e) => {
                  if (hoveredStateId === state.id) setPointer({ x: e.clientX, y: e.clientY });
                }}
                onMouseLeave={() => {
                  if (hoveredStateId === state.id) setHoveredStateId(null);
                  setPointer(null);
                }}
                onFocus={() => {
                  setHoveredStateId(state.id);
                  if (liveRegionRef.current) liveRegionRef.current.textContent = state.name;
                }}
                onBlur={() => {
                  if (hoveredStateId === state.id) setHoveredStateId(null);
                }}
              />
            );
          })}

          {(overlayPaths.length + alaskaPaths.length + hawaiiPaths.length + visibleCityPoints.length + visibleAlaskaCityPoints.length + visibleHawaiiCityPoints.length) > 0 && (
            <>
              {/* Continental overlays are drawn via Canvas for speed */}
              {false && overlayPaths.length > 0 && (
                <g className="pointer-events-none" />
              )}
              {false && alaskaPaths.length > 0 && alaskaTransform && (
                <g className="pointer-events-none" transform={alaskaTransform} />
              )}
              {false && hawaiiPaths.length > 0 && hawaiiTransform && (
                <g className="pointer-events-none" transform={hawaiiTransform} />
              )}
              {cityLabelPlacements.length > 0 && (
                <g className="pointer-events-none z-10">
                  {cityLabelPlacements.map((placement, i) => (
                    <g key={`pt-${placement.city.id || i}`}>
                      <circle
                        cx={placement.city.x}
                        cy={placement.city.y}
                        r={placement.markerRadius}
                        style={{
                          fill: 'hsl(var(--color-text))',
                          stroke: 'hsla(var(--color-surface) / 0.95)',
                          strokeWidth: placement.textStrokeWidth,
                          vectorEffect: 'non-scaling-stroke',
                        }}
                      />
                      <text
                        x={placement.labelX}
                        y={placement.labelY}
                        fontSize={placement.fontSize}
                        textAnchor={placement.textAnchor}
                        style={{
                          fill: 'hsl(var(--color-text))',
                          stroke: 'hsla(var(--color-surface) / 0.98)',
                          strokeWidth: placement.textStrokeWidth,
                          paintOrder: 'stroke fill',
                          vectorEffect: 'non-scaling-stroke',
                          fontFamily: 'var(--font-family-sans)',
                          fontWeight: 600,
                          letterSpacing: 0.15,
                          textRendering: 'geometricPrecision',
                        }}
                      >
                        {placement.text}
                      </text>
                    </g>
                  ))}
                </g>
              )}
              
            </>
          )}

          {atlas.states
            .filter((s) => ['RI', 'DE', 'VT', 'DC', 'CT'].includes(s.id))
            .map((state) => {
              const r = 12;
              const [cx, cy] = state.centroid;
              return (
                <circle
                  key={state.id + '-hit'}
                  cx={cx}
                  cy={cy}
                  r={r}
                  className="fill-transparent stroke-transparent cursor-pointer"
                  onClick={() => onStateSelect(state.id)}
                  onMouseEnter={(e) => {
                    setHoveredStateId(state.id);
                    setPointer({ x: e.clientX, y: e.clientY });
                    if (liveRegionRef.current) liveRegionRef.current.textContent = state.name;
                  }}
                  onMouseMove={(e) => {
                    if (hoveredStateId === state.id) setPointer({ x: e.clientX, y: e.clientY });
                  }}
                  onMouseLeave={() => {
                    if (hoveredStateId === state.id) setHoveredStateId(null);
                    setPointer(null);
                  }}
                />
              );
            })}
        </g>
      </svg>

      {/* Canvas overlay layer to render continental overlayPaths efficiently */}
      {overlayPaths.length > 0 && (
        <CanvasOverlay
          width={atlas.width}
          height={atlas.height}
          paths={overlayPaths}
          transform={transform}
          stroke={diag ? 'hsla(var(--color-accent) / 0.75)' : 'hsl(var(--color-primary))'}
          strokeWidth={diag ? 0.4 : 0.5}
        />
      )}

      {/* Canvas overlay layers for AK and HI insets */}
      {alaskaPaths.length > 0 && akInset && (
        <CanvasOverlay
          width={atlas.width}
          height={atlas.height}
          paths={alaskaPaths}
          transform={transform}
          insetScale={akInset.scale}
          insetTx={akInset.tx}
          insetTy={akInset.ty}
          stroke={'hsl(var(--color-primary))'}
          strokeWidth={0.5}
        />
      )}
      {hawaiiPaths.length > 0 && hiInset && (
        <CanvasOverlay
          width={atlas.width}
          height={atlas.height}
          paths={hawaiiPaths}
          transform={transform}
          insetScale={hiInset.scale}
          insetTx={hiInset.tx}
          insetTy={hiInset.ty}
          stroke={'hsl(var(--color-primary))'}
          strokeWidth={0.5}
        />
      )}

      {hoveredStateName && pointer && (
        <div
          role="tooltip"
          className="pointer-events-none absolute z-20 px-2 py-1 rounded text-white text-xs font-medium shadow-lg backdrop-blur-sm"
          style={{ left: pointer.x + 6, top: pointer.y - 18, maxWidth: 220, backgroundColor: 'hsla(var(--color-primary) / 0.9)' }}
        >
          <span className="font-semibold">{hoveredStateName}</span>
          {overlaySummary && (
            <span className="block text-[11px] font-normal leading-snug mt-0.5 text-white/90">
              {overlaySummary}
            </span>
          )}
        </div>
      )}
      <div aria-live="polite" aria-atomic="true" ref={liveRegionRef} className="sr-only" />

      <div className="absolute right-4 bottom-4 flex flex-col space-y-2">
        <button
          onClick={handleZoomIn}
          className="backdrop-blur-sm shadow-lg rounded-full p-3 transition-colors border border-soft"
          style={{ backgroundColor: 'hsla(var(--color-panel) / 0.9)' }}
          aria-label="Zoom In"
        >
          <IconZoomIn className="w-6 h-6 text-primary" />
        </button>
        <button
          onClick={handleZoomOut}
          className="backdrop-blur-sm shadow-lg rounded-full p-3 transition-colors border border-soft"
          style={{ backgroundColor: 'hsla(var(--color-panel) / 0.9)' }}
          aria-label="Zoom Out"
        >
          <IconZoomOut className="w-6 h-6 text-primary" />
        </button>
      </div>

      {overlayControls && overlayControls.length > 0 && (
        <OverlayPanel controls={overlayControls} className="absolute top-4 right-4 z-30" />
      )}

      {/* National bottom-left legend removed per request */}
    </div>
  );
};

export default React.memo(MapView);