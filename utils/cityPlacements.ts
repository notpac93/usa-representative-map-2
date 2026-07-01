import { CityFeature } from '../types';
import { getCityLabelVisual, formatCityLabelText } from './cityLabeling';

export type DecoratedCity = CityFeature & {
  normalizedName: string;
  displayName: string;
  isCapital: boolean;
  isMarquee?: boolean;
  isPriority?: boolean;
  tier?: number;
  previewRank?: number;
  labelImpact: number;
  placementJitter: number;
  score?: number;
  stateId?: string | null;
  withinViewport?: boolean;
};

export type CityLabelPlacement = {
  city: DecoratedCity;
  markerRadius: number;
  textStrokeWidth: number;
  text: string;
  fontSize: number;
  labelX: number;
  labelY: number;
  textAnchor: 'start' | 'middle' | 'end';
};

export type TransformLike = { x: number; y: number; k: number };

export type ComputeCityPlacementsOptions = {
  normalizedZoom: number;
  transform: TransformLike;
  viewWidth: number;
  viewHeight: number;
  baseMarkerRadius: number;
  baseFontSize: number;
  baseOffsetX: number;
  baseOffsetY: number;
  strokeWidth: number;
  detailZoomFactor: number;
  labelPaddingScale: number;
  preferCentered?: boolean;
  maxLabels?: number;
};

type LabelBBox = { x1: number; y1: number; x2: number; y2: number };

export function computeCityPlacements(
  cities: DecoratedCity[],
  options: ComputeCityPlacementsOptions,
): CityLabelPlacement[] {
  const {
    normalizedZoom,
    transform,
    viewWidth,
    viewHeight,
    baseMarkerRadius,
    baseFontSize,
    baseOffsetX,
    baseOffsetY,
    strokeWidth,
    detailZoomFactor,
    labelPaddingScale,
    preferCentered,
    maxLabels,
  } = options;

  if (!cities.length) return [];

  const placements: CityLabelPlacement[] = [];
  const placedBoxes: LabelBBox[] = [];
  const normZoom = Math.max(0.0001, normalizedZoom);
  const [vx, vy] = [-transform.x / normZoom, -transform.y / normZoom];
  const [vw, vh] = [viewWidth / normZoom, viewHeight / normZoom];
  const viewCenter = { x: vx + vw / 2, y: vy + vh / 2 };
  const collisionPadding = Math.max(1.2, 3 / Math.max(1, normZoom)) * labelPaddingScale;

  const intersectionArea = (a: LabelBBox, b: LabelBBox) => {
    const xOverlap = Math.max(0, Math.min(a.x2, b.x2) - Math.max(a.x1, b.x1));
    const yOverlap = Math.max(0, Math.min(a.y2, b.y2) - Math.max(a.y1, b.y1));
    return xOverlap * yOverlap;
  };

  const totalOverlap = (box: LabelBBox) => placedBoxes.reduce((sum, existing) => sum + intersectionArea(box, existing), 0);

  const createPlacement = (
    city: DecoratedCity,
    candidate: { dx: number; dy: number; anchor: 'start' | 'end' | 'middle' },
    textWidth: number,
    textHeight: number,
  ) => {
    const textX = city.x + candidate.dx;
    const textY = city.y - candidate.dy;
    let left = textX;
    if (candidate.anchor === 'end') left = textX - textWidth;
    else if (candidate.anchor === 'middle') left = textX - textWidth / 2;
    const right = left + textWidth;
    const top = textY - textHeight;
    const bottom = textY;
    const bbox: LabelBBox = {
      x1: left - collisionPadding,
      y1: top - collisionPadding,
      x2: right + collisionPadding,
      y2: bottom + collisionPadding,
    };
    return { x: textX, y: textY, anchor: candidate.anchor, bbox };
  };

  cities.forEach((city) => {
    if (typeof maxLabels === 'number' && placements.length >= maxLabels) return;
    const visual = getCityLabelVisual(detailZoomFactor, city.isMarquee || city.isCapital);
    const emphasis = city.isCapital ? 1.12 : city.isPriority ? 1.02 : 0.94;
    const preferredFontSize = baseFontSize * visual.fontScale * emphasis;
    const { text, fontSize } = formatCityLabelText(city.displayName, !!(city.isMarquee || city.isCapital), preferredFontSize);
    if (!text) return;

    const markerRadius = baseMarkerRadius * visual.markerScale * Math.max(0.85, 0.95 + city.placementJitter * 0.12);
    const textWidth = Math.max(2, text.length) * fontSize * 0.58;
    const textHeight = fontSize;
    const jitterOffset = 0.85 + city.placementJitter * 0.3;
    const offsetX = (baseOffsetX * visual.offsetScale + markerRadius * 0.85) * jitterOffset;
    const offsetY = (baseOffsetY * visual.offsetScale + markerRadius * 0.1) * (0.92 + (0.5 - city.placementJitter) * 0.2);

    const dirX = city.x - viewCenter.x;
    const dirY = city.y - viewCenter.y;
    const horizontalFirst = Math.abs(dirX) >= Math.abs(dirY);

    const nearestNeighbor = (() => {
      let closest: CityLabelPlacement | null = null;
      let minDist = Infinity;
      for (let i = placements.length - 1; i >= 0; i -= 1) {
        const placed = placements[i];
        const dx = placed.city.x - city.x;
        const dy = placed.city.y - city.y;
        const dist = Math.hypot(dx, dy);
        if (dist < minDist) {
          minDist = dist;
          closest = placed;
        }
      }
      return minDist <= 140 ? closest : null;
    })();

    const neighborPreferredDirection: 'left' | 'right' | null = nearestNeighbor
      ? (nearestNeighbor.labelX >= nearestNeighbor.city.x ? 'left' : 'right')
      : null;

    const candidatesConfig = {
      right: { dx: markerRadius + offsetX, dy: offsetY, anchor: 'start' as const },
      rightUp: { dx: markerRadius + offsetX * 0.9, dy: offsetY * 2.2, anchor: 'start' as const },
      rightDown: { dx: markerRadius + offsetX * 0.9, dy: -offsetY * 0.4, anchor: 'start' as const },
      left: { dx: -(markerRadius + offsetX), dy: offsetY, anchor: 'end' as const },
      leftUp: { dx: -(markerRadius + offsetX * 0.9), dy: offsetY * 2.2, anchor: 'end' as const },
      leftDown: { dx: -(markerRadius + offsetX * 0.9), dy: -offsetY * 0.4, anchor: 'end' as const },
      centerAbove: { dx: 0, dy: offsetY * 3, anchor: 'middle' as const },
      centerBelow: { dx: 0, dy: -offsetY * 2, anchor: 'middle' as const },
    } satisfies Record<string, { dx: number; dy: number; anchor: 'start' | 'end' | 'middle' }>;

    const horizontalOrder = dirX >= 0
      ? ['right', 'rightUp', 'rightDown', 'centerAbove', 'centerBelow', 'left', 'leftUp', 'leftDown']
      : ['left', 'leftUp', 'leftDown', 'centerAbove', 'centerBelow', 'right', 'rightUp', 'rightDown'];
    const verticalOrder = dirY >= 0
      ? ['centerBelow', 'rightDown', 'leftDown', 'right', 'left', 'centerAbove', 'rightUp', 'leftUp']
      : ['centerAbove', 'rightUp', 'leftUp', 'right', 'left', 'centerBelow', 'rightDown', 'leftDown'];

    let candidateKeys = Array.from(new Set([
      ...(preferCentered ? ['centerAbove', 'centerBelow', ...horizontalOrder] : []),
      ...(horizontalFirst ? horizontalOrder : verticalOrder),
      'centerAbove',
      'centerBelow',
    ])) as Array<keyof typeof candidatesConfig>;

    if (!preferCentered && candidateKeys.length > 2) {
      const rotation = Math.floor(city.placementJitter * candidateKeys.length);
      candidateKeys = [...candidateKeys.slice(rotation), ...candidateKeys.slice(0, rotation)];
    }

    if (neighborPreferredDirection) {
      const favoredKeys = neighborPreferredDirection === 'right'
        ? (['right', 'rightUp', 'rightDown'] as Array<keyof typeof candidatesConfig>)
        : (['left', 'leftUp', 'leftDown'] as Array<keyof typeof candidatesConfig>);
      const prioritized = favoredKeys.filter((key) => candidateKeys.includes(key));
      const remaining = candidateKeys.filter((key) => !favoredKeys.includes(key));
      candidateKeys = [...prioritized, ...remaining];
    }

    const initialCandidate = candidatesConfig[candidateKeys[0]];
    if (!initialCandidate) return;
    let chosenPlacement = createPlacement(city, initialCandidate, textWidth, textHeight);
    let minOverlap = totalOverlap(chosenPlacement.bbox);

    for (let i = 0; i < candidateKeys.length; i += 1) {
      const candidate = candidatesConfig[candidateKeys[i]];
      if (!candidate) continue;
      const placement = createPlacement(city, candidate, textWidth, textHeight);
      const overlap = totalOverlap(placement.bbox);
      if (overlap === 0) {
        chosenPlacement = placement;
        minOverlap = 0;
        break;
      }
      if (overlap < minOverlap) {
        minOverlap = overlap;
        chosenPlacement = placement;
      }
    }

    placedBoxes.push(chosenPlacement.bbox);
    placements.push({
      city,
      markerRadius,
      textStrokeWidth: strokeWidth,
      text,
      fontSize,
      labelX: chosenPlacement.x,
      labelY: chosenPlacement.y,
      textAnchor: chosenPlacement.anchor,
    });
  });

  return placements;
}
