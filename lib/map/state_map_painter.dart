import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models.dart';
import 'national_map_painter.dart'; // For AtlasPathCache
import '../utils/city_placements.dart';
import '../utils/city_labeling.dart';

class StateMapPainter extends CustomPainter {
  final StateRecord stateRecord;
  final Atlas atlas;
  final AtlasPathCache pathCache;
  final double zoomLevel;
  final List<CityFeature> cities; // Pre-filtered cities for the state
  final List<OverlayFeature>? counties;
  final List<OverlayFeature>? cd116;
  final List<OverlayFeature>? urbanAreas;
  final List<OverlayFeature>? zcta;
  final List<OverlayFeature>? lakes;
  final bool showCounties;
  final bool showDistricts;
  final bool showUrban;
  final bool showZcta;
  final bool showLakes;

  final Paint _stateFillPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  final Paint _stateStrokePaint = Paint()
    ..color = Colors.blueGrey[400]!
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _cityMarkerPaint = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.fill;

  // Overlay Paints
  final Paint _countyPaint = Paint()
    ..color = Colors.grey.withOpacity(0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;
  final Paint _districtPaint = Paint()
    ..color = Colors.purple.withOpacity(0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _urbanPaint = Paint()
    ..color = Colors.orange.withOpacity(0.2)
    ..style = PaintingStyle.fill;
  final Paint _zctaPaint = Paint()
    ..color = Colors.green.withOpacity(0.3)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;
  final Paint _lakesPaint = Paint()
    ..color =
        const Color(0xFFA3CCFF) // Light blue
    ..style = PaintingStyle.fill;

  StateMapPainter({
    required this.stateRecord,
    required this.atlas,
    required this.pathCache,
    required this.zoomLevel,
    required this.cities,
    this.counties,
    this.cd116,
    this.urbanAreas,
    this.zcta,
    this.lakes,
    this.showCounties = false,
    this.showDistricts = false,
    this.showUrban = false,
    this.showZcta = false,
    this.showLakes = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // State Bounding Box logic (from React StateMapView.tsx)
    // We want to zoom into the state's bbox.
    final bbox = stateRecord.bbox; // [minX, minY, maxX, maxY]
    final bboxWidth = bbox[2] - bbox[0];
    final bboxHeight = bbox[3] - bbox[1];

    // Scale to fit canvas
    final scaleX = size.width / bboxWidth;
    final scaleY = size.height / bboxHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY; // fit contain

    // Center logic
    final offsetX = (size.width - (bboxWidth * scale)) / 2;
    final offsetY = (size.height - (bboxHeight * scale)) / 2;

    // Apply Transform: Translate to center, Scale, then Translate negative bbox min
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);
    canvas.translate(-bbox[0], -bbox[1]);

    // Draw the State Path
    final path = pathCache.getPath(stateRecord.id);
    if (path != null) {
      canvas.drawPath(path, _stateFillPaint);
      canvas.drawPath(path, _stateStrokePaint);

      // *** CLIPPING FIX ***
      canvas.save();
      canvas.clipPath(path);

      // Draw Overlays
      if (showLakes && lakes != null) {
        _drawOverlay(canvas, lakes!, _lakesPaint);
      }
      if (showUrban && urbanAreas != null) {
        _drawOverlay(canvas, urbanAreas!, _urbanPaint);
      }
      if (showZcta && zcta != null) {
        _drawOverlay(canvas, zcta!, _zctaPaint);
      }
      if (showCounties && counties != null) {
        _drawOverlay(canvas, counties!, _countyPaint);
      }
      if (showDistricts && cd116 != null) {
        _drawOverlay(canvas, cd116!, _districtPaint);
      }

      canvas.restore();
    }

    // Draw Cities (Labels & Markers)
    // We need to calculate Placements using the ported logic.
    // NOTE: In a real app, calculate this OUTSIDE paint if expensive.
    _drawCities(canvas, scale, size);
  }

  void _drawOverlay(Canvas canvas, List<OverlayFeature> features, Paint paint) {
    // Filter features that intersect with the state bbox
    final sBox = stateRecord.bbox;
    for (var f in features) {
      // BBox Intersection Check
      // f.bbox = [minX, minY, maxX, maxY]
      // sBox   = [minX, minY, maxX, maxY]
      final intersects =
          !(f.bbox[0] > sBox[2] ||
              f.bbox[2] < sBox[0] ||
              f.bbox[1] > sBox[3] ||
              f.bbox[3] < sBox[1]);

      if (intersects) {
        // Retrieve or parse path
        var path = pathCache.getPathById(f.id);
        if (path == null) {
          pathCache.cachePath(f.id, f.path);
          path = pathCache.getPathById(f.id);
        }
        if (path != null) {
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  void _drawCities(Canvas canvas, double scale, Size size) {
    // 1. Decorate Cities
    // 1. Decorate Cities
    // Simple heuristic: Top 3 cities by population get marquee status (bold/larger).
    // (Assuming cities are passed unsorted or we want to enforce it).
    final sortedCities = List<CityFeature>.from(cities);
    sortedCities.sort(
      (a, b) => (b.population ?? 0).compareTo(a.population ?? 0),
    );

    final decoratedCities = sortedCities.asMap().entries.map((entry) {
      final index = entry.key;
      final c = entry.value;
      final isMarquee = index < 3; // Top 3 are "marquee"
      final isCapital = false; // TODO: Load capital data if needed

      return DecoratedCity(
        feature: c,
        normalizedName: normalizeCityName(c.name),
        displayName: c.name,
        isMarquee: isMarquee,
        isCapital: isCapital,
        placementJitter: jitterFromString(c.name),
      );
    }).toList();

    // 2. Setup Options
    // Base scale is relative to the STATE view.
    // In React app, we used `totalZoom` which was styleZoom * baseMapScale.
    // Here, `scale` IS essentially that multiplier relative to Atlas units?
    // Atlas units are generic.
    // `scale` transforms generic 500-sized atlas coords to Screen Logic Pixels.
    // If bboxWidth is 50, and screen is 300, scale is 6.

    final options = ComputePlacementOptions(
      normalizedZoom:
          scale / 5.0, // Arbitrary normalization factor similar to D3
      transform: [
        0,
        0,
        1.0,
      ], // We are already transformed via canvas, so logic assumes 0,0 origin relative to state
      viewWidth: size.width,
      viewHeight: size.height,
      baseMarkerRadius:
          2.0 /
          scale, // Scale down radius in Atlas Units so it stays constant on screen
      baseFontSize: 13.0 / scale, // Target 13px screen size
      baseOffsetX: 6.0 / scale,
      baseOffsetY: 6.0 / scale,
      strokeWidth: 2.0 / scale,
      detailZoomFactor: 1.0,
      labelPaddingScale: 1.0,
    );

    // 3. Compute
    final placements = computeCityPlacements(decoratedCities, options);

    for (var placement in placements) {
      canvas.drawCircle(
        Offset(placement.city.x, placement.city.y),
        2.5 / scale,
        _cityMarkerPaint,
      );

      final textSpan = TextSpan(
        text: placement.text,
        style: GoogleFonts.inter(
          color: Colors.black,
          fontSize: placement.fontSize,
          fontWeight: FontWeight.w500,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      // Use computed label position
      textPainter.paint(
        canvas,
        Offset(placement.labelX, placement.labelY - placement.fontSize),
      ); // Adjust for baseline? Flutter draws at top-left.
      // placement.labelY is baseline in React logic? The code said `bottom`.
      // Flutter TextPainter paints top-left.
      // We might need to adjust Y by height.
      // The placement logic return `labelY` as TOP? No, `textY` was bottom?
      // `top = textY - textHeight`.
      // `placement.labelY` = `chosenPlacement.y` = `textY` (bottom).
      // So we should paint at `labelY - textHeight`.
    }
  }

  @override
  bool shouldRepaint(covariant StateMapPainter oldDelegate) {
    return oldDelegate.stateRecord.id != stateRecord.id ||
        oldDelegate.showCounties != showCounties ||
        oldDelegate.showDistricts != showDistricts ||
        oldDelegate.showUrban != showUrban ||
        oldDelegate.showZcta != showZcta ||
        oldDelegate.showLakes != showLakes;
  }
}
