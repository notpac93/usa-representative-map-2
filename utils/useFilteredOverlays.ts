import { useMemo } from 'react';
import { StateRecord, OverlayLayer, CityFeature } from '../types';
import { intersects, isLikelyArtifact, isPointInPolygon } from './geometry';

const STATE_FIPS_LOOKUP: Record<string, string> = {
  AL: '01', AK: '02', AZ: '04', AR: '05', CA: '06', CO: '08', CT: '09', DC: '11',
  DE: '10', FL: '12', GA: '13', HI: '15', ID: '16', IL: '17', IN: '18', IA: '19',
  KS: '20', KY: '21', LA: '22', ME: '23', MD: '24', MA: '25', MI: '26', MN: '27',
  MS: '28', MO: '29', MT: '30', NE: '31', NV: '32', NH: '33', NJ: '34', NM: '35',
  NY: '36', NC: '37', ND: '38', OH: '39', OK: '40', OR: '41', PA: '42', RI: '44',
  SC: '45', SD: '46', TN: '47', TX: '48', UT: '49', VT: '50', VA: '51', WA: '53',
  WV: '54', WI: '55', WY: '56', PR: '72', GU: '66', VI: '78', AS: '60', MP: '69'
};

type AppOverlayLayer = OverlayLayer & {
  hidden?: boolean;
  pointLayer?: boolean;
  points?: CityFeature[];
};

interface FilteredOverlaysResult {
  overlayPaths: string[];
  cityPoints: CityFeature[];
  activeLabels: string[];
  legendLayers: AppOverlayLayer[];
}

export function useFilteredOverlays(
  state: StateRecord | undefined,
  activeOverlays: AppOverlayLayer[] | undefined
): FilteredOverlaysResult {
  return useMemo(() => {
    const result: FilteredOverlaysResult = {
      overlayPaths: [],
      cityPoints: [],
      activeLabels: [],
      legendLayers: [],
    };

    if (!state || !activeOverlays?.length) {
      return result;
    }

    const stateBBox = state.bbox;
    const stateFips = STATE_FIPS_LOOKUP[state.id];
    const applyArtifactFilter = state.id === 'AK';

    for (const layer of activeOverlays) {
      const feats = layer.features || [];
      const pointArray = layer.points;
      let hasVisibleFeatures = false;

      for (const feature of feats) {
        if (!feature?.path || !feature?.bbox || !Array.isArray(feature.bbox) || feature.bbox.length !== 4) continue;
        if (!intersects(stateBBox as any, feature.bbox as any)) continue;
        if (applyArtifactFilter && isLikelyArtifact({ featureBBox: feature.bbox as any, stateBBox: stateBBox as any })) continue;

        result.overlayPaths.push(feature.path);
        hasVisibleFeatures = true;
      }

      if (pointArray?.length) {
        for (const point of pointArray) {
          if (!point || typeof point.x !== 'number' || typeof point.y !== 'number') continue;
          if (!isPointWithinProjectedBounds(point, stateBBox)) continue;

          const insideGeometry = isPointInsideStateGeometry(point, state);
          const matchesStateByFips = doesPointMatchStateFips(point, stateFips);

          if (insideGeometry || matchesStateByFips) {
            result.cityPoints.push({
              id: point.id || point.name,
              name: point.name,
              x: point.x,
              y: point.y,
              population: point.population,
              lat: point.lat,
              lon: point.lon,
            });
            hasVisibleFeatures = true;
          }
        }
      }

      if (hasVisibleFeatures && !layer.hidden && !layer.pointLayer) {
        result.activeLabels.push(layer.label || layer.key);
        result.legendLayers.push({
          key: layer.key,
          label: layer.label,
          fill: layer.fill,
          stroke: layer.stroke,
          category: layer.category,
          features: [],
        });
      }
    }

    return result;
  }, [state, activeOverlays]);
}

function isPointWithinProjectedBounds(point: CityFeature, bbox: [number, number, number, number]): boolean {
  const [minX, minY, maxX, maxY] = bbox;
  return point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY;
}

function doesPointMatchStateFips(point: CityFeature, stateFips?: string): boolean {
  if (!stateFips || typeof point.id !== 'string') {
    return false;
  }
  const match = point.id.match(/^(\d{2})/);
  return !!match && match[1] === stateFips;
}

function isPointInsideStateGeometry(point: CityFeature, state: StateRecord): boolean {
  if (!state.geometry) {
    return true;
  }
  if (typeof point.lon !== 'number' || typeof point.lat !== 'number') {
    return false;
  }

  const cityPoint: [number, number] = [point.lon, point.lat];
  const geometry = state.geometry;

  if (geometry.type === 'Polygon') {
    return geometry.coordinates.some((ring: [number, number][]) =>
      isPointInPolygon(cityPoint, ring as [number, number][])
    );
  }

  return geometry.coordinates.some((polygon: [number, number][][]) =>
    polygon.some((ring: [number, number][]) => isPointInPolygon(cityPoint, ring as [number, number][]))
  );
}
