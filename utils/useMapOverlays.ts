import { useMemo } from 'react';
import { Atlas, OverlayLayer, CityFeature, StateRecord } from '../types';
import { intersects } from './geometry';

// Extend OverlayLayer with optional ad-hoc properties used in the app
type AppOverlayLayer = OverlayLayer & {
  hidden?: boolean;
  pointLayer?: boolean;
  points?: CityFeature[];
};

interface UseMapOverlaysParams {
  atlas: Atlas;
  activeOverlays?: AppOverlayLayer[];
  transformK: number; // current zoom level (transform.k)
  diag: boolean; // diagnostic flag
}

interface UseMapOverlaysResult {
  overlayPaths: string[];
  alaskaPaths: string[];
  hawaiiPaths: string[];
  visibleCityPoints: CityFeature[];
  visibleAlaskaCityPoints: CityFeature[];
  visibleHawaiiCityPoints: CityFeature[];
  alaskaTransform: string | undefined;
  hawaiiTransform: string | undefined;
}

export function useMapOverlays(params: UseMapOverlaysParams): UseMapOverlaysResult {
  const { atlas, activeOverlays, transformK, diag } = params;

  return useMemo(() => {
    const overlayPaths: string[] = [];
    const alaskaPaths: string[] = [];
    const hawaiiPaths: string[] = [];
    const cityPoints: CityFeature[] = [];
    const alaskaCityPoints: CityFeature[] = [];
    const hawaiiCityPoints: CityFeature[] = [];

  const akState = atlas.states.find(s => s.id === 'AK');
  const hiState = atlas.states.find(s => s.id === 'HI');

    if (activeOverlays?.length) {
      const lodLow = transformK < 2; // far zoom
      const lodMid = transformK >= 2 && transformK < 4;
      for (const layer of activeOverlays) {
        for (const f of layer.features) {
          if (!f?.path || !f?.bbox) continue;
          // Choose LOD path based on zoom
          const chosenPath = lodLow ? (f.pathLow || f.pathMid || f.path) : (lodMid ? (f.pathMid || f.path) : f.path);
          if (!chosenPath) continue;
          // Draw AK and HI at their native AlbersUSA positions; do not split out insets
          overlayPaths.push(chosenPath);
        }
        const pts: CityFeature[] | undefined = layer.points;
        if (pts && Array.isArray(pts)) {
          for (const p of pts) {
            if (!p || typeof p.x !== 'number' || typeof p.y !== 'number') continue;
            // Keep all points in the same coordinate space; we'll cull/select elsewhere
            cityPoints.push(p);
          }
        }
      }
    }

    // City label selection rules
  const isHighZoom = transformK >= 4;

    function topByPopulation(points: CityFeature[], n: number): CityFeature[] {
      if (!points.length) return points;
      const havePop = points.some(p => (p.population || 0) > 0);
      if (havePop) return [...points].sort((a, b) => (b.population || 0) - (a.population || 0)).slice(0, n);
      const majorNames = [
        'New York city', 'Los Angeles city', 'Chicago city', 'Houston city', 'Phoenix city',
        'Philadelphia city', 'San Antonio city', 'San Diego city', 'Dallas city', 'San Jose city'
      ];
      const byName = new Map(points.map(p => [p.name, p]));
      const curated: CityFeature[] = [];
      for (const nm of majorNames) { const pt = byName.get(nm); if (pt) curated.push(pt); if (curated.length >= n) break; }
      if (curated.length >= n) return curated.slice(0, n);
      const grid = 6; const xs = points.map(p => p.x), ys = points.map(p => p.y);
      const minX = Math.min(...xs), maxX = Math.max(...xs), minY = Math.min(...ys), maxY = Math.max(...ys);
      const buckets: Record<string, CityFeature[]> = {};
      for (const p of points) {
        const gx = Math.min(grid - 1, Math.floor(((p.x - minX) / Math.max(1, (maxX - minX))) * grid));
        const gy = Math.min(grid - 1, Math.floor(((p.y - minY) / Math.max(1, (maxY - minY))) * grid));
        const k = `${gx},${gy}`; (buckets[k] ||= []).push(p);
      }
      const res: CityFeature[] = [];
      const per = Math.max(1, Math.floor(n / Object.keys(buckets).length));
      for (const k of Object.keys(buckets)) { res.push(...buckets[k]!.slice(0, per)); if (res.length >= n) break; }
      if (res.length < n) res.push(...points.slice(0, n - res.length));
      for (const c of curated) { if (!res.includes(c)) res.unshift(c); }
      return res.slice(0, n);
    }

    function topNPerState(all: CityFeature[], n: number): CityFeature[] {
      const selected: CityFeature[] = [];
      for (const st of atlas.states) {
        const pts = all.filter(p => p.x >= st.bbox[0] && p.x <= st.bbox[2] && p.y >= st.bbox[1] && p.y <= st.bbox[3]);
        if (!pts.length) continue;
        const havePop = pts.some(p => (p.population || 0) > 0);
        const sorted = havePop ? pts.sort((a, b) => (b.population || 0) - (a.population || 0)) : pts.sort((a, b) => (a.name || '').localeCompare(b.name || ''));
        selected.push(...sorted.slice(0, n));
      }
      return selected;
    }

    const visibleCityPoints = isHighZoom ? topNPerState(cityPoints, 8) : topByPopulation(cityPoints, 10);
    const visibleAlaskaCityPoints = isHighZoom ? topNPerState(alaskaCityPoints, 3) : topByPopulation(alaskaCityPoints, 3);
    const visibleHawaiiCityPoints = isHighZoom ? topNPerState(hawaiiCityPoints, 3) : topByPopulation(hawaiiCityPoints, 3);

    // No custom inset transforms; use native positions from the atlas projection
    const alaskaTransform = undefined;
    const hawaiiTransform = undefined;

    // Debug helper: compute difference metrics for first overlay feature vs. state geometry to inspect alignment.
    if (process.env.NODE_ENV !== 'production' && overlayPaths.length && diag) {
      try {
        const firstPath = overlayPaths[0];
        const coordRe = /[ML](-?[0-9]+(?:\.[0-9]+)?),(-?[0-9]+(?:\.[0-9]+)?)/g;
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity, m; while ((m = coordRe.exec(firstPath))) { const x = +m[1], y = +m[2]; if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
        const statesBBox = atlas.states.reduce((acc, s) => { if (s.id === 'AK' || s.id === 'HI') return acc; const [a, b, c, d] = s.bbox; if (a < acc[0]) acc[0] = a; if (b < acc[1]) acc[1] = b; if (c > acc[2]) acc[2] = c; if (d > acc[3]) acc[3] = d; return acc; }, [Infinity, Infinity, -Infinity, -Infinity] as [number, number, number, number]);
        const pad = (n: number) => Number(n.toFixed(2));
        // eslint-disable-next-line no-console
        console.debug('[overlay-debug] first overlay bbox', { minX, minY, maxX, maxY }, 'statesBBox', statesBBox);
        const agg = overlayPaths.reduce((acc, p) => {
          let miX = Infinity, miY = Infinity, maX = -Infinity, maY = -Infinity; let mm; const re = /[ML](-?[0-9]+(?:\.[0-9]+)?),(-?[0-9]+(?:\.[0-9]+)?)/g; while ((mm = re.exec(p))) { const x = +mm[1], y = +mm[2]; if (x < miX) miX = x; if (x > maX) maX = x; if (y < miY) miY = y; if (y > maY) maY = y; } if (miX !== Infinity) { if (miX < acc[0]) acc[0] = miX; if (miY < acc[1]) acc[1] = miY; if (maX > acc[2]) acc[2] = maX; if (maY > acc[3]) acc[3] = maY; } return acc; }, [Infinity, Infinity, -Infinity, -Infinity] as [number, number, number, number]);
        // eslint-disable-next-line no-console
        console.info('[diag] overlay aggregate extent', { bbox: agg.map(pad) }, 'states extent', { bbox: statesBBox.map(pad) });
        const spanStateW = statesBBox[2] - statesBBox[0];
        const spanOverW = agg[2] - agg[0];
        const spanStateH = statesBBox[3] - statesBBox[1];
        const spanOverH = agg[3] - agg[1];
        // eslint-disable-next-line no-console
        console.info('[diag] span ratios overlay/state', { widthRatio: (spanOverW / spanStateW).toFixed(4), heightRatio: (spanOverH / spanStateH).toFixed(4) });
      } catch { /* ignore */ }
    }

    return {
      overlayPaths,
      alaskaPaths,
      hawaiiPaths,
      visibleCityPoints,
      visibleAlaskaCityPoints,
      visibleHawaiiCityPoints,
      alaskaTransform,
      hawaiiTransform,
    };
  }, [atlas, activeOverlays, transformK, diag]);
}
