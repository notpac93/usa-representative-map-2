import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Atlas, CityFeature } from '../types';
import * as d3 from 'd3';
import { MIN_ZOOM, MAX_ZOOM, ZOOM_STEP } from '../constants';
import { IconZoomIn, IconZoomOut } from './Icons';
import { capitals } from '../data/capitals';
import { resolveLabelMetrics, CITY_LABEL_ZOOM_STOPS } from '../utils/labelScaling';
import { normalizeCityName, sanitizeCityLabel, jitterFromString } from '../utils/cityLabeling';
import { computeCityPlacements, DecoratedCity, CityLabelPlacement } from '../utils/cityPlacements';

const ZOOM_TIER_VISIBILITY = [0, 1.35, 2.25] as const;

interface StateMapViewProps {
  atlas: Atlas;
  stateId: string;
  overlayPaths?: string[];
  overlayLabel?: string;
  showOverlay?: boolean;
  cityPoints?: CityFeature[];
}

const StateMapView: React.FC<StateMapViewProps> = ({ atlas, stateId, overlayPaths, overlayLabel, showOverlay, cityPoints }) => {
  const state = atlas.states.find(s => s.id === stateId);
  const padding = 24;

  const { viewWidth, viewHeight, translateX, translateY } = useMemo(() => {
    if (!state) return { viewWidth: 0, viewHeight: 0, translateX: 0, translateY: 0 };
    const [minX, minY, maxX, maxY] = state.bbox;
    const width = maxX - minX;
    const height = maxY - minY;
    return {
      viewWidth: width + padding * 2,
      viewHeight: height + padding * 2,
      translateX: -minX + padding,
      translateY: -minY + padding,
    };
  }, [state]);
  const capitalRawName = capitals[stateId as keyof typeof capitals] || '';
  const normalizedCapitalName = useMemo(() => normalizeCityName(capitalRawName), [capitalRawName]);

  const svgRef = useRef<SVGSVGElement | null>(null);
  const zoomLayerRef = useRef<SVGGElement | null>(null);
  const zoomBehaviorRef = useRef<d3.ZoomBehavior<SVGSVGElement, unknown> | null>(null);
  const [zoomTransform, setZoomTransform] = useState(d3.zoomIdentity);
  const [pointerSvg, setPointerSvg] = useState<{ x: number, y: number } | null>(null);
  const normalizedZoom = Math.max(MIN_ZOOM, zoomTransform.k || MIN_ZOOM);
  const smoothZoomRef = useRef(Math.max(MIN_ZOOM, zoomTransform.k || MIN_ZOOM));
  const styleZoom = useMemo(() => {
    const target = Math.max(MIN_ZOOM, zoomTransform.k || MIN_ZOOM);
    const previous = smoothZoomRef.current;
    const eased = previous + (target - previous) * 0.35;
    const next = Number.isFinite(eased) ? eased : target;
    smoothZoomRef.current = next;
    return next;
  }, [zoomTransform.k]);
  const zoomLabelMetrics = useMemo(
    () => resolveLabelMetrics(styleZoom, CITY_LABEL_ZOOM_STOPS),
    [styleZoom]
  );

  const scaledLabelMetrics = zoomLabelMetrics;

  const stateLabelTier = useMemo(() => {
    if (styleZoom < 1.35) return { key: 'overview', target: 4, spacing: 1.2 };
    if (styleZoom < 2.1) return { key: 'regional', target: 7, spacing: 1.05 };
    if (styleZoom < 3.4) return { key: 'metro', target: 11, spacing: 0.92 };
    if (styleZoom < 5.5) return { key: 'detail', target: 14, spacing: 0.82 };
    return { key: 'hyper', target: 18, spacing: 0.72 };
  }, [styleZoom]);

  useEffect(() => {
    if (!svgRef.current || !zoomLayerRef.current || !state) return;
    const svg = d3.select(svgRef.current);
    const zoom = d3.zoom<SVGSVGElement, unknown>()
      .filter((event) => {
        const type = (event as any)?.type;
        if (type === 'wheel') {
          return (event as WheelEvent).ctrlKey;
        }
        if (type === 'dblclick') return false;
        return true;
      })
      .scaleExtent([MIN_ZOOM, MAX_ZOOM])
      .translateExtent([[-1e7, -1e7], [1e7, 1e7]])
      .on('zoom', (event) => setZoomTransform(event.transform));
    zoomBehaviorRef.current = zoom;
    svg.call(zoom as any);
    const initial = d3.zoomIdentity.translate(translateX, translateY);
    svg.call(zoom.transform as any, initial);
    setZoomTransform(initial);
    return () => { svg.on('.zoom', null); };
  }, [state, translateX, translateY]);

  const visibleCityPoints = useMemo<DecoratedCity[]>(() => {
    if (!cityPoints?.length) return [];

    const decorated = cityPoints.reduce<DecoratedCity[]>((acc, pt, index) => {
      const displayName = sanitizeCityLabel(pt.name || '');
      const normalizedName = normalizeCityName(pt.name || '');
      if (!displayName || !normalizedName) return acc;
      const tieredMeta = pt as CityFeature & { tier?: number; previewRank?: number };
      const derivedTier = typeof tieredMeta.tier === 'number' ? tieredMeta.tier : 2;
      const previewRank = typeof tieredMeta.previewRank === 'number' ? tieredMeta.previewRank : index + 1;
      const isCapital = !!normalizedCapitalName && normalizedName === normalizedCapitalName;
      const tier = isCapital ? 0 : derivedTier;
      const isPriority = tier === 1;
      const populationScore = pt.population ? Math.log10(pt.population) : 3.2;
      const labelImpact = Math.min(80, 18 + displayName.length * 1.8 + (isCapital ? 10 : 0) - (tier === 2 ? 2 : 0));
      const decoratedCity: DecoratedCity = {
        ...pt,
        normalizedName,
        displayName,
        isCapital,
        isPriority,
        tier,
        previewRank,
        labelImpact,
        score: populationScore + (isCapital ? 3.1 : 0) + (isPriority ? 0.8 : 0) - tier * 0.15,
        placementJitter: jitterFromString(normalizedName || pt.id || `${pt.x}-${pt.y}`),
      };
      acc.push(decoratedCity);
      return acc;
    }, []);

    return decorated.sort((a, b) => (b.score || 0) - (a.score || 0));
  }, [cityPoints, normalizedCapitalName]);

  const zoomEligibleCities = useMemo(() => {
    return visibleCityPoints.filter((city) => {
      const tier = typeof city.tier === 'number' ? city.tier : (city.isCapital ? 0 : 2);
      const threshold = ZOOM_TIER_VISIBILITY[Math.min(tier, ZOOM_TIER_VISIBILITY.length - 1)] ?? ZOOM_TIER_VISIBILITY[ZOOM_TIER_VISIBILITY.length - 1];
      return styleZoom + 0.005 >= threshold;
    });
  }, [visibleCityPoints, styleZoom]);

  if (!state) return <div className="text-sm text-muted">State geometry not found.</div>;

  function currentAnchor(): [number, number] {
    if (pointerSvg) return [pointerSvg.x, pointerSvg.y];
    return [viewWidth / 2, viewHeight / 2];
  }

  const baseCityMarkerRadius = scaledLabelMetrics.marker;
  const baseCityLabelFontSize = scaledLabelMetrics.font;
  const cityLabelStrokeWidth = scaledLabelMetrics.stroke;
  const baseCityLabelOffsetX = scaledLabelMetrics.offsetX;
  const baseCityLabelOffsetY = scaledLabelMetrics.offsetY;
  const detailZoomFactor = scaledLabelMetrics.detail;
  const labelPaddingScale = scaledLabelMetrics.padding;

  const labelTransform = useMemo(() => ({
    x: zoomTransform.x - translateX,
    y: zoomTransform.y - translateY,
    k: zoomTransform.k || 1,
  }), [zoomTransform, translateX, translateY]);

  const MAX_STATE_LABELS = Math.min(stateLabelTier.target, Math.max(zoomEligibleCities.length, 3));
  const stateCityLabelPlacements = useMemo<CityLabelPlacement[]>(() => {
    if (!zoomEligibleCities.length) return [];
    return computeCityPlacements(zoomEligibleCities, {
      normalizedZoom,
      transform: labelTransform,
      viewWidth,
      viewHeight,
      baseMarkerRadius: baseCityMarkerRadius,
      baseFontSize: baseCityLabelFontSize,
      baseOffsetX: baseCityLabelOffsetX,
      baseOffsetY: baseCityLabelOffsetY,
      strokeWidth: cityLabelStrokeWidth,
      detailZoomFactor,
      labelPaddingScale: labelPaddingScale * stateLabelTier.spacing,
      preferCentered: true,
      maxLabels: MAX_STATE_LABELS,
    });
  }, [zoomEligibleCities, normalizedZoom, labelTransform, viewWidth, viewHeight, baseCityMarkerRadius, baseCityLabelFontSize, baseCityLabelOffsetX, baseCityLabelOffsetY, cityLabelStrokeWidth, detailZoomFactor, labelPaddingScale, stateLabelTier.spacing, MAX_STATE_LABELS]);

  function handleZoomIn() {
    if (!svgRef.current || !zoomBehaviorRef.current) return;
    d3.select(svgRef.current).transition().duration(200).call(zoomBehaviorRef.current.scaleBy as any, ZOOM_STEP, currentAnchor());
  }
  function handleZoomOut() {
    if (!svgRef.current || !zoomBehaviorRef.current) return;
    d3.select(svgRef.current).transition().duration(200).call(zoomBehaviorRef.current.scaleBy as any, 1 / ZOOM_STEP, currentAnchor());
  }

  return (
    <div className="w-full flex flex-col items-center relative">
      <div className="relative w-full max-w-xl md:max-w-2xl">
        <svg
          viewBox={`0 0 ${viewWidth} ${viewHeight}`}
          className="w-full h-auto drop-shadow rounded"
          style={{ backgroundColor: 'hsl(var(--color-panel))' }}
          role="img"
          aria-label={state.name}
          ref={svgRef}
          onMouseMove={(e) => {
            const rect = (e.currentTarget as SVGSVGElement).getBoundingClientRect();
            const svgX = (e.clientX - rect.left) / rect.width * viewWidth;
            const svgY = (e.clientY - rect.top) / rect.height * viewHeight;
            setPointerSvg({ x: svgX, y: svgY });
          }}
          onMouseLeave={() => setPointerSvg(null)}
        >
          <g ref={zoomLayerRef} transform={zoomTransform.toString()}>
            <path
              d={state.path}
              style={{ fill: 'hsl(var(--color-border))', stroke: 'hsl(var(--color-background))', strokeWidth: 0.75 }}
            />
            {showOverlay && overlayPaths?.length ? (
              <>
                <defs>
                  <clipPath id={`state-clip-${state.id}`}>
                    <path d={state.path} />
                  </clipPath>
                </defs>
                <g className="pointer-events-none" clipPath={`url(#state-clip-${state.id})`}>
                  {overlayPaths.map((p, i) => (
                    <path
                      key={i}
                      d={p}
                      style={{ fill: 'none', stroke: 'hsl(var(--color-primary))', vectorEffect: 'non-scaling-stroke', strokeWidth: 0.4, strokeLinecap: 'round' }}
                    />
                  ))}
                </g>
              </>
            ) : null}
            {stateCityLabelPlacements.length > 0 && (
              <g className="pointer-events-none z-10">
                {stateCityLabelPlacements.map((placement, idx) => {
                  const tier = typeof placement.city.tier === 'number' ? placement.city.tier : (placement.city.isCapital ? 0 : 2);
                  const isCapital = placement.city.isCapital;
                  const fontScale = isCapital ? 1.12 : tier === 1 ? 0.9 : 0.82;
                  const strokeAlpha = isCapital ? 0.95 : 0.88;
                  const fillColor = isCapital ? 'hsl(var(--color-foreground))' : 'hsla(var(--color-foreground) / 0.8)';
                  const fontWeight = isCapital ? 700 : 500;
                  const letterSpacing = isCapital ? 0.2 : 0.05;
                  return (
                    <g key={`city-group-${placement.city.id || placement.city.name || idx}`}>
                      <text
                        x={placement.labelX}
                        y={placement.labelY}
                        fontSize={placement.fontSize * fontScale}
                        textAnchor={placement.textAnchor}
                        dominantBaseline="middle"
                        style={{
                          fill: fillColor,
                          stroke: `hsla(var(--color-panel) / ${strokeAlpha})`,
                          strokeWidth: placement.textStrokeWidth,
                          paintOrder: 'stroke fill',
                          vectorEffect: 'non-scaling-stroke',
                          fontFamily: 'var(--font-family-sans)',
                          fontWeight,
                          letterSpacing,
                          textRendering: 'geometricPrecision',
                        }}
                      >
                        {placement.text}
                      </text>
                    </g>
                  );
                })}
              </g>
            )}
          </g>
        </svg>
        <div className="absolute right-4 bottom-4 flex flex-col space-y-2">
          <button onClick={handleZoomIn} className="backdrop-blur-sm shadow-lg rounded-full p-3 transition-colors border border-soft" style={{ backgroundColor: 'hsla(var(--color-panel) / 0.95)' }} aria-label="Zoom In">
            <IconZoomIn className="w-6 h-6 text-[hsl(var(--color-primary))]" />
          </button>
          <button onClick={handleZoomOut} className="backdrop-blur-sm shadow-lg rounded-full p-3 transition-colors border border-soft" style={{ backgroundColor: 'hsla(var(--color-panel) / 0.95)' }} aria-label="Zoom Out">
            <IconZoomOut className="w-6 h-6 text-[hsl(var(--color-primary))]" />
          </button>
        </div>
      </div>
      {overlayLabel && (
        <div className="mt-1 text-[10px] uppercase tracking-wide text-muted">{overlayLabel}{showOverlay ? '' : ' (hidden)'}
        </div>)}
    </div>
  );
};

export default React.memo(StateMapView);