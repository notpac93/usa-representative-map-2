type BBox = [number, number, number, number];

/**
 * Checks if two bounding boxes intersect.
 * @param a The first bounding box.
 * @param b The second bounding box.
 * @returns True if the boxes intersect, false otherwise.
 */
export function intersects(a: BBox, b: BBox): boolean {
  return a[0] <= b[2] && a[2] >= b[0] && a[1] <= b[3] && a[3] >= b[1];
}

interface ArtifactFilterParams {
  featureBBox: BBox;
  stateBBox: BBox;
}

/**
 * Applies heuristic filters to remove likely map artifacts, especially for Alaska.
 * These artifacts often appear as long, thin shapes along the edges of the map projection.
 * @param params Parameters including the feature and state bounding boxes.
 * @returns True if the feature is likely an artifact, false otherwise.
 */
export function isLikelyArtifact(params: ArtifactFilterParams): boolean {
  const { featureBBox, stateBBox } = params;
  const [sMinX, sMinY, sMaxX, sMaxY] = stateBBox;
  const sW = sMaxX - sMinX;
  const sH = sMaxY - sMinY;

  const [fMinX, fMinY, fMaxX, fMaxY] = featureBBox;
  const fW = fMaxX - fMinX;
  const fH = fMaxY - fMinY;

  // Heuristic artifact filters (purple bar / frame eliminators):
  const isWideThin = fW > sW * 1.4 && fH < sH * 0.08;
  const isTallThin = fH > sH * 1.4 && fW < sW * 0.08;
  const isOversized = fW > sW * 1.8 || fH > sH * 1.8;

  return isWideThin || isTallThin || isOversized;
}

/**
 * Checks if a point is inside a polygon using the ray-casting algorithm.
 * @param point The point to check, as [x, y].
 * @param polygon The polygon, as an array of points [[x1, y1], [x2, y2], ...].
 * @returns True if the point is inside the polygon, false otherwise.
 */
export function isPointInPolygon(point: [number, number], polygon: [number, number][]): boolean {
  let isInside = false;
  const [x, y] = point;

  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const [xi, yi] = polygon[i];
    const [xj, yj] = polygon[j];

    const intersect = ((yi > y) !== (yj > y))
        && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
    if (intersect) {
      isInside = !isInside;
    }
  }

  return isInside;
}
