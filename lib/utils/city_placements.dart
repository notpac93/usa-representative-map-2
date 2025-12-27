import 'dart:math' as math;
import '../data/models.dart';
import 'city_labeling.dart';

class DecoratedCity {
  final CityFeature feature;
  final String normalizedName;
  final String displayName;
  final bool isCapital;
  final bool isMarquee;
  final bool isPriority;
  final double placementJitter;
  final double x;
  final double y;

  DecoratedCity({
    required this.feature,
    required this.normalizedName,
    required this.displayName,
    this.isCapital = false,
    this.isMarquee = false,
    this.isPriority = false,
    this.placementJitter = 0.5,
  }) : x = feature.x,
       y = feature.y;
}

enum TextAnchor { start, middle, end }

class CityLabelPlacement {
  final DecoratedCity city;
  final double markerRadius;
  final double textStrokeWidth;
  final String text;
  final double fontSize;
  final double labelX;
  final double labelY;
  final TextAnchor textAnchor;
  final List<double> bbox;

  CityLabelPlacement({
    required this.city,
    required this.markerRadius,
    required this.textStrokeWidth,
    required this.text,
    required this.fontSize,
    required this.labelX,
    required this.labelY,
    required this.textAnchor,
    required this.bbox,
  });
}

class ComputePlacementOptions {
  final double normalizedZoom;
  final List<double>
  transform; // [x, y, k] (mimicking D3 transform but simplified)
  final double viewWidth;
  final double viewHeight;
  final double baseMarkerRadius;
  final double baseFontSize;
  final double baseOffsetX;
  final double baseOffsetY;
  final double strokeWidth;
  final double detailZoomFactor;
  final double labelPaddingScale;
  final bool preferCentered;
  final int? maxLabels;

  ComputePlacementOptions({
    required this.normalizedZoom,
    required this.transform,
    required this.viewWidth,
    required this.viewHeight,
    required this.baseMarkerRadius,
    required this.baseFontSize,
    required this.baseOffsetX,
    required this.baseOffsetY,
    required this.strokeWidth,
    required this.detailZoomFactor,
    required this.labelPaddingScale,
    this.preferCentered = false,
    this.maxLabels,
  });
}

class _Candidate {
  final double dx;
  final double dy;
  final TextAnchor anchor;
  _Candidate(this.dx, this.dy, this.anchor);
}

List<CityLabelPlacement> computeCityPlacements(
  List<DecoratedCity> cities,
  ComputePlacementOptions options,
) {
  if (cities.isEmpty) return [];

  final placements = <CityLabelPlacement>[];
  final placedBoxes = <List<double>>[];
  final normZoom = math.max(0.0001, options.normalizedZoom);
  final tx = options.transform[0];
  final ty = options.transform[1];
  // Inverse view transform to find center in map coords
  final vx = -tx / normZoom;
  final vy = -ty / normZoom;
  final vw = options.viewWidth / normZoom;
  final vh = options.viewHeight / normZoom;
  final viewCenterX = vx + vw / 2;
  final viewCenterY = vy + vh / 2;

  final collisionPadding =
      math.max(1.5, 4.5 / math.max(1, normZoom)) * options.labelPaddingScale;

  double intersectionArea(List<double> a, List<double> b) {
    final xOverlap = math.max(0, math.min(a[2], b[2]) - math.max(a[0], b[0]));
    final yOverlap = math.max(0, math.min(a[3], b[3]) - math.max(a[1], b[1]));
    return (xOverlap * yOverlap).toDouble();
  }

  double totalOverlap(List<double> box) {
    double sum = 0;
    for (var existing in placedBoxes) {
      sum += intersectionArea(box, existing);
    }
    return sum;
  }

  // Pre-configured candidates relative to markers
  final candidatesConfig = <String, _Candidate>{
    'right': _Candidate(1.0, 1.0, TextAnchor.start), // Scaled dynamically below
    'rightUp': _Candidate(0.9, 2.2, TextAnchor.start),
    'rightDown': _Candidate(0.9, -0.4, TextAnchor.start),
    'left': _Candidate(-1.0, 1.0, TextAnchor.end),
    'leftUp': _Candidate(-0.9, 2.2, TextAnchor.end),
    'leftDown': _Candidate(-0.9, -0.4, TextAnchor.end),
    'centerAbove': _Candidate(0.0, 3.0, TextAnchor.middle),
    'centerBelow': _Candidate(0.0, -2.0, TextAnchor.middle),
  };

  for (final city in cities) {
    if (options.maxLabels != null && placements.length >= options.maxLabels!) {
      break;
    }

    final visual = getCityLabelVisual(
      options.detailZoomFactor,
      city.isMarquee || city.isCapital,
    );
    final emphasis = city.isCapital ? 1.12 : (city.isPriority ? 1.02 : 0.94);
    final preferredFontSize =
        options.baseFontSize * visual.fontScale * emphasis;
    final formatted = formatCityLabelText(
      city.displayName,
      city.isMarquee || city.isCapital,
      preferredFontSize,
    );

    if (formatted.text.isEmpty) continue;

    final markerRadius =
        options.baseMarkerRadius *
        visual.markerScale *
        math.max(0.85, 0.95 + city.placementJitter * 0.12);
    // Approx text dimensions (since we don't have canvas context yet, we estimate)
    // React logic: length * fontSize * 0.58
    final textWidth =
        math.max(2, formatted.text.length) * formatted.fontSize * 0.58;
    final textHeight = formatted.fontSize;

    final jitterOffset = 0.85 + city.placementJitter * 0.3;
    final offsetX =
        (options.baseOffsetX * visual.offsetScale + markerRadius * 0.85) *
        jitterOffset;
    final offsetY =
        (options.baseOffsetY * visual.offsetScale + markerRadius * 0.1) *
        (0.92 + (0.5 - city.placementJitter) * 0.2);

    // Direction to center
    final dirX = city.x - viewCenterX;
    final dirY = city.y - viewCenterY;
    final horizontalFirst = dirX.abs() >= dirY.abs();

    // Determine preference order
    final horizontalOrder = dirX >= 0
        ? [
            'right',
            'rightUp',
            'rightDown',
            'centerAbove',
            'centerBelow',
            'left',
            'leftUp',
            'leftDown',
          ]
        : [
            'left',
            'leftUp',
            'leftDown',
            'centerAbove',
            'centerBelow',
            'right',
            'rightUp',
            'rightDown',
          ];
    final verticalOrder = dirY >= 0
        ? [
            'centerBelow',
            'rightDown',
            'leftDown',
            'right',
            'left',
            'centerAbove',
            'rightUp',
            'leftUp',
          ]
        : [
            'centerAbove',
            'rightUp',
            'leftUp',
            'right',
            'left',
            'centerBelow',
            'rightDown',
            'leftDown',
          ];

    var candidateKeys = <String>{
      if (options.preferCentered) ...[
        'centerAbove',
        'centerBelow',
        ...horizontalOrder,
      ],
      ...(horizontalFirst ? horizontalOrder : verticalOrder),
      'centerAbove',
      'centerBelow',
    }.toList(); // Use Set to dedupe, then List

    // Rotation jitter
    if (!options.preferCentered && candidateKeys.length > 2) {
      final rotation = (city.placementJitter * candidateKeys.length).floor();
      candidateKeys = [
        ...candidateKeys.sublist(rotation),
        ...candidateKeys.sublist(0, rotation),
      ];
    }

    // Evaluate candidates
    final initialKey = candidateKeys[0];
    final initialConf = candidatesConfig[initialKey]!;

    // Helper to calculate geometry for a candidate
    _PlacementResult calculatePlacement(_Candidate conf) {
      // Adjust dx/dy based on dynamic offsets
      double dx = conf.dx;
      double dy = conf.dy;
      // In original:
      // right: dx = marker + offsetX
      // rightUp: dx = marker + offsetX*0.9
      // center: dx = 0

      // We replicate the switch logic or just simplify using signs
      if (conf.anchor == TextAnchor.middle) {
        dx = 0;
        // dy logic: above = offsetY*3, below = -offsetY*2
        dy = (conf.dy > 0 ? offsetY * 3 : -offsetY * 2);
      } else {
        final signX = conf.dx > 0 ? 1 : -1;
        // relative to textY (up is positive in math, but SVG y is down)
        // React code: textY - candidate.dy.
        // candidate.rightUp.dy = offsetY * 2.2.
        // candidate.rightDown.dy = -offsetY * 0.4. (Negative means BELOW the point in math, so textY - (-val) = textY + val = down)

        final absDx = (conf.dx.abs() == 1.0)
            ? (markerRadius + offsetX)
            : (markerRadius + offsetX * 0.9);
        dx = signX * absDx;

        // Re-map signs from config to actual offset
        // Config: rightUp dy=2.2 (Up).
        // Config: rightDown dy=-0.4 (Down).
        dy = (conf.dy.abs() > 2)
            ? (conf.dy > 0 ? offsetY * 3 : -offsetY * 3)
            : (conf.dy.abs() > 1)
            ? (conf.dy > 0 ? offsetY * 2.2 : -offsetY * 2.2)
            : (conf.dy.abs() == 1
                  ? (conf.dy > 0 ? offsetY : -offsetY)
                  : (conf.dy > 0 ? offsetY * 0.4 : -offsetY * 0.4));
      }

      final textX = city.x + dx;
      final textY = city.y - dy; // SVG Y grows down

      // BBox
      double left = textX;
      if (conf.anchor == TextAnchor.end) {
        left = textX - textWidth;
      } else if (conf.anchor == TextAnchor.middle) {
        left = textX - textWidth / 2;
      }

      final right = left + textWidth;
      final top = textY - textHeight; // Font baseline
      final bottom = textY; // Baseline

      final bbox = [
        left - collisionPadding,
        top - collisionPadding,
        right + collisionPadding,
        bottom + collisionPadding,
      ];
      return _PlacementResult(textX, textY, conf.anchor, bbox);
    }

    var chosenPl = calculatePlacement(initialConf);
    var minOverlap = totalOverlap(chosenPl.bbox);

    // Iterate if overlap
    if (minOverlap > 0) {
      for (var key in candidateKeys) {
        if (key == initialKey) continue;
        final conf = candidatesConfig[key]!;
        final pl = calculatePlacement(conf);
        final ov = totalOverlap(pl.bbox);
        if (ov == 0) {
          chosenPl = pl;
          minOverlap = 0;
          break;
        }
        if (ov < minOverlap) {
          minOverlap = ov;
          chosenPl = pl;
        }
      }
    }

    placedBoxes.push(chosenPl.bbox);
    placements.add(
      CityLabelPlacement(
        city: city,
        markerRadius: markerRadius,
        textStrokeWidth: options.strokeWidth,
        text: formatted.text,
        fontSize: formatted.fontSize,
        labelX: chosenPl.x,
        labelY: chosenPl.y,
        textAnchor: chosenPl.anchor,
        bbox: chosenPl.bbox,
      ),
    );
  }
  return placements;
}

class _PlacementResult {
  final double x;
  final double y;
  final TextAnchor anchor;
  final List<double> bbox;
  _PlacementResult(this.x, this.y, this.anchor, this.bbox);
}

extension ListPush on List<List<double>> {
  void push(List<double> item) => add(item);
}
