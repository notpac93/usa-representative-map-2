/// Geometric utilities for map rendering.
library;

typedef BBox = List<double>; // [minX, minY, maxX, maxY]
typedef Point = List<double>; // [x, y]

/// Checks if two bounding boxes intersect.
bool intersects(BBox a, BBox b) {
  return a[0] <= b[2] && a[2] >= b[0] && a[1] <= b[3] && a[3] >= b[1];
}

class ArtifactFilterParams {
  final BBox featureBBox;
  final BBox stateBBox;

  ArtifactFilterParams({required this.featureBBox, required this.stateBBox});
}

/// Applies heuristic filters to remove likely map artifacts (e.g. for Alaska).
bool isLikelyArtifact(ArtifactFilterParams params) {
  final sMinX = params.stateBBox[0];
  final sMinY = params.stateBBox[1];
  final sMaxX = params.stateBBox[2];
  final sMaxY = params.stateBBox[3];
  final sW = sMaxX - sMinX;
  final sH = sMaxY - sMinY;

  final fMinX = params.featureBBox[0];
  final fMinY = params.featureBBox[1];
  final fMaxX = params.featureBBox[2];
  final fMaxY = params.featureBBox[3];
  final fW = fMaxX - fMinX;
  final fH = fMaxY - fMinY;

  // Heuristic filters
  final isWideThin = fW > sW * 1.4 && fH < sH * 0.08;
  final isTallThin = fH > sH * 1.4 && fW < sW * 0.08;
  final isOversized = fW > sW * 1.8 || fH > sH * 1.8;

  return isWideThin || isTallThin || isOversized;
}

/// Checks if a point is inside a polygon using ray-casting.
bool isPointInPolygon(Point point, List<Point> polygon) {
  bool isInside = false;
  final x = point[0];
  final y = point[1];

  int j = polygon.length - 1;
  for (int i = 0; i < polygon.length; i++) {
    final xi = polygon[i][0];
    final yi = polygon[i][1];
    final xj = polygon[j][0];
    final yj = polygon[j][1];

    final bool intersect =
        ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
    if (intersect) {
      isInside = !isInside;
    }
    j = i;
  }

  return isInside;
}
