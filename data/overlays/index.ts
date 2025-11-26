import type { OverlayLayer, CityLayer } from '../../types';

// Registry for overlays. Dynamically import generated overlay modules here.
// For first iteration we will support a single Urban Areas overlay derived from raw census data.

export interface OverlayMeta {
  key: string;
  label: string;
  loader: () => Promise<OverlayLayer>;
  states?: string[]; // if specified, restrict to these state IDs
  fill?: string;
  stroke?: string;
  strokeWidth?: number;
  lineCap?: 'butt' | 'round' | 'square';
  category?: string; // group legend
  hidden?: boolean;
  renderOrder?: number;
  legend?: Array<{ label: string; stroke?: string; fill?: string; shape?: 'line' | 'rect' | 'circle' }>;
}

export const overlayRegistry: OverlayMeta[] = [
  {
    key: 'water-bodies',
    label: 'Water & Lakes',
    category: 'Base',
    fill: 'rgba(148, 163, 184, 0.28)',
    stroke: 'rgba(100, 116, 139, 0.55)',
    strokeWidth: 0.45,
    lineCap: 'round',
    hidden: true,
    renderOrder: -20,
    loader: async () => {
      const mod: any = await import('./water.generated.ts').catch(() => ({}));
      return (mod.waterBodiesLayer || mod.default || Object.values(mod)[0]);
    },
  },
  {
    key: 'interstates',
    label: 'Interstate Highways',
    category: 'Transportation',
    stroke: 'rgba(251, 146, 60, 0.85)',
    strokeWidth: 0.75,
    lineCap: 'round',
    fill: 'transparent',
    renderOrder: 20,
    loader: async () => {
      const mod: any = await import('./interstates.generated.ts').catch(()=>({}));
      return (mod.interstatesLayer || mod.default || Object.values(mod)[0]);
    },
    legend: [
      {
        label: 'Primary interstate',
        stroke: '#f97316',
        shape: 'line'
      }
    ]
  },
  {
    key: 'cities',
    label: 'Cities (2025)',
    category: 'Places',
    fill: 'rgba(234,179,8,0.25)',
    stroke: '#eab308',
    loader: async () => {
      const mod: any = await import('./cities.generated.ts').catch(()=>({}));
      const layer: CityLayer = (mod.citiesLayer || mod.default || Object.values(mod)[0]);
      // We coerce to OverlayLayer shape with stub features; carry point data on a non-typed property for consumers.
      const overlayLike: any = { key: layer.key, label: layer.label, features: [], source: layer.source, stroke: layer.stroke, fill: layer.fill, projectionParams: layer.projectionParams, category: 'Places', hidden: true };
      overlayLike.pointLayer = true;
      overlayLike.points = layer.features; // array of {x,y}
      return overlayLike as OverlayLayer;
    }
  },
  {
    key: 'urban-areas',
    label: 'Urban Areas',
    category: 'Urbanization',
    fill: 'rgba(59,130,246,0.35)',
    stroke: '#2563eb',
    loader: async () => {
      const mod: any = await import('./urbanAreas.generated.ts');
      return (mod.urbanAreasLayer || mod.default || Object.values(mod)[0]);
    },
    states: undefined
  },
  {
    key: 'regions',
    label: 'US Regions',
    category: 'Reference',
    fill: 'rgba(168,85,247,0.25)',
    stroke: '#a855f7',
    loader: async () => {
      const mod: any = await import('./regions.generated.ts').catch(()=>({}));
      return (mod.regionsLayer || mod.default || Object.values(mod)[0]);
    }
  },
  {
    key: 'counties',
    label: 'Counties',
    category: 'Boundaries',
    fill: 'rgba(34,197,94,0.18)',
    stroke: '#22c55e',
    loader: async () => {
      const mod: any = await import('./counties.generated.ts').catch(()=>({}));
      return (mod.countiesLayer || mod.default || Object.values(mod)[0]);
    }
  },
  {
    key: 'tribal-lands',
    label: 'Tribal Lands',
    category: 'Communities',
    fill: 'rgba(16,185,129,0.25)',
    stroke: '#0f766e',
    loader: async () => {
      const mod: any = await import('./tribalLands.generated.ts').catch(()=>({}));
      return (mod.tribalLandsLayer || mod.default || Object.values(mod)[0]);
    }
  },
  {
    key: 'zcta',
    label: 'ZIP Code Tabulation Areas',
    category: 'Communities',
    fill: 'rgba(248,113,113,0.2)',
    stroke: '#f87171',
    loader: async () => {
      const mod: any = await import('./zcta.generated.ts').catch(()=>({}));
      return (mod.zctaLayer || mod.default || Object.values(mod)[0]);
    }
  }
];

export async function loadOverlay(key: string): Promise<OverlayLayer | null> {
  const meta = overlayRegistry.find(o => o.key === key);
  if (!meta) return null;
  try {
    const layer = await meta.loader();
    // Attach style metadata if not present
    if (layer) {
      layer.fill = layer.fill || meta.fill;
      layer.stroke = layer.stroke || meta.stroke;
      layer.strokeWidth = layer.strokeWidth ?? meta.strokeWidth;
      layer.lineCap = layer.lineCap || meta.lineCap;
      layer.category = layer.category || meta.category;
      layer.hidden = layer.hidden ?? meta.hidden;
      layer.renderOrder = layer.renderOrder ?? meta.renderOrder;
      if (meta.legend && !layer.legend) {
        layer.legend = meta.legend;
      }
    }
    return layer;
  } catch (e) {
    console.warn('Failed loading overlay', key, e);
    return null;
  }
}

export async function loadAllOverlays(): Promise<OverlayLayer[]> {
  const results: OverlayLayer[] = [];
  for (const meta of overlayRegistry) {
    try { const layer = await meta.loader(); if (layer) results.push(layer); } catch { /* ignore */ }
  }
  return results;
}
