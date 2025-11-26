import { useMemo } from 'react';
import { Atlas, OverlayLayer, CityFeature } from '../types';

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

type OverlayRenderGroup = {
  key: string;
  label: string;
  paths: string[];
  stroke?: string;
  fill?: string;
  strokeWidth?: number;
  lineCap?: 'butt' | 'round' | 'square';
  renderOrder?: number;
};

interface UseMapOverlaysResult {
  overlayGroups: OverlayRenderGroup[];
}

export function useMapOverlays(params: UseMapOverlaysParams): UseMapOverlaysResult {
  const { atlas, activeOverlays, transformK, diag } = params;

  return useMemo(() => {
    const overlayGroups: OverlayRenderGroup[] = [];

    if (activeOverlays?.length) {
      const lodLow = transformK < 2; // far zoom
      const lodMid = transformK >= 2 && transformK < 4;
      for (const layer of activeOverlays) {
        if ((layer as any).pointLayer) continue;
        const layerPaths: string[] = [];
        for (const f of layer.features) {
          if (!f?.path || !f?.bbox) continue;
          const chosenPath = lodLow
            ? (f.pathLow || f.pathMid || f.path)
            : (lodMid ? (f.pathMid || f.path) : f.path);
          if (!chosenPath) continue;
          layerPaths.push(chosenPath);
        }
        if (layerPaths.length) {
          overlayGroups.push({
            key: layer.key,
            label: layer.label || layer.key,
            paths: layerPaths,
            stroke: layer.stroke,
            fill: layer.fill,
            strokeWidth: layer.strokeWidth,
            lineCap: layer.lineCap,
            renderOrder: layer.renderOrder ?? 0,
          });
        }
      }
    }

    overlayGroups.sort((a, b) => (a.renderOrder ?? 0) - (b.renderOrder ?? 0));

    // Debug helper: compute difference metrics for first overlay feature vs. state geometry to inspect alignment.
    const allPaths = overlayGroups.flatMap(group => group.paths);
    if (process.env.NODE_ENV !== 'production' && allPaths.length && diag) {
      try {
        const firstPath = allPaths[0];
        const coordRe = /[ML](-?[0-9]+(?:\.[0-9]+)?),(-?[0-9]+(?:\.[0-9]+)?)/g;
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity, m; while ((m = coordRe.exec(firstPath))) { const x = +m[1], y = +m[2]; if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
        const statesBBox = atlas.states.reduce((acc, s) => { if (s.id === 'AK' || s.id === 'HI') return acc; const [a, b, c, d] = s.bbox; if (a < acc[0]) acc[0] = a; if (b < acc[1]) acc[1] = b; if (c > acc[2]) acc[2] = c; if (d > acc[3]) acc[3] = d; return acc; }, [Infinity, Infinity, -Infinity, -Infinity] as [number, number, number, number]);
        const pad = (n: number) => Number(n.toFixed(2));
        // eslint-disable-next-line no-console
        console.debug('[overlay-debug] first overlay bbox', { minX, minY, maxX, maxY }, 'statesBBox', statesBBox);
        const agg = allPaths.reduce((acc, p) => {
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
      overlayGroups,
    };
  }, [atlas, activeOverlays, transformK, diag]);
}
