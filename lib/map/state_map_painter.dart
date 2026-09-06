import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_drawing/path_drawing.dart';
import '../data/models.dart';
import 'atlas_path_cache.dart';
import 'city_renderer.dart';
import '../utils/map_transform.dart';

class StateMapPainter extends CustomPainter {
  final StateRecord stateRecord;
  final Atlas atlas;
  final AtlasPathCache pathCache;
  final double zoomLevel;
  final List<CityFeature> cities; // Pre-filtered cities for the state
  final List<PlaceFeature>? places; // City outlines
  final List<OverlayFeature>? counties;
  final List<OverlayFeature>? cd116;
  final List<OverlayFeature>? urbanAreas;
  final List<OverlayFeature>? zcta;
  final List<OverlayFeature>? lakes;
  final List<OverlayFeature>? judicial;
  final bool showCounties;
  final bool showDistricts;
  final bool showUrban;
  final bool showZcta;
  final bool showLakes;
  final bool showJudicial;
  final List<OverlayFeature>? selectedFeatures; // New selected list

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
  final Paint _judicialPaint = Paint()
    ..color = Colors.brown
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _highlightPaint =
      Paint() // Gold highlight
        ..color = const Color(0xFFFFD700).withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

  final Paint _intersectionFillPaint = Paint()
    ..color = const Color(0xFFFFD700)
        .withOpacity(0.5) // Semi-transparent Gold
    ..style = PaintingStyle.fill;

  StateMapPainter({
    required this.stateRecord,
    required this.atlas,
    required this.pathCache,
    required this.zoomLevel,
    required this.cities,
    required this.places,
    this.counties,
    this.cd116,
    this.urbanAreas,
    this.zcta,
    this.lakes,
    this.judicial,
    this.showCounties = false,
    this.showDistricts = false,
    this.showUrban = false,
    this.showZcta = false,
    this.showLakes = false,
    this.showJudicial = false,
    this.selectedFeatures,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // State Bounding Box logic via Helper
    final transform = MapTransform.calculateFit(stateRecord.bbox, size);

    // Apply Transform: Translate to center, Scale, then Translate negative bbox min
    canvas.translate(transform.offset.dx, transform.offset.dy);
    canvas.scale(transform.scale);
    canvas.translate(-transform.bbox[0], -transform.bbox[1]);

    // Expose scale for city drawing
    final scale = transform.scale;

    // Draw the State Path
    final path = pathCache.getPath(stateRecord.id);
    if (path != null) {
      canvas.drawPath(path, _stateFillPaint);
      canvas.drawPath(path, _stateStrokePaint);

      // *** CLIPPING FIX ***
      canvas.save();
      canvas.clipPath(path);

      // *** INVARIANT STROKE WIDTH FIX ***
      // Calculate effective scale = Base Map Scale * User Zoom
      // Target stroke width (e.g. 0.5px) should be divided by effective scale
      // so that when magnified, it appears as 0.5px.
      // NOTE: `scale` is the Base Map Scale. `zoomLevel` is user zoom.
      // Wait, `canvas.scale(scale)` is already applied.
      // So drawing with strokeWidth=1.0 will appear as `scale` pixels thick.
      // To get 1.0px on screen, we need `1.0 / scale`.
      // The `InteractiveViewer` applies an ADDITIONAL scale of `zoomLevel`.
      // So the final on-screen thickness is `width * scale * zoomLevel`.
      // To maintain constant visual thickness T, we need:
      // width = T / (scale * zoomLevel).

      final invariantScale = scale * zoomLevel;

      _countyPaint.strokeWidth = 0.5 / invariantScale;
      _districtPaint.strokeWidth = 1.5 / invariantScale;
      _zctaPaint.strokeWidth = 0.5 / invariantScale;
      _judicialPaint.strokeWidth = 1.0 / invariantScale;
      _highlightPaint.strokeWidth = 4.0 / invariantScale; // Thicker highlight
      // Urban and Lakes are fills, so no stroke width needed.

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
      if (showJudicial && judicial != null) {
        _drawOverlay(canvas, judicial!, _judicialPaint);
      }
      if (showCounties && counties != null) {
        _drawOverlay(canvas, counties!, _countyPaint);
      }
      if (showDistricts && cd116 != null) {
        _drawOverlay(canvas, cd116!, _districtPaint);
      }

      // Draw City Outlines (Places) with fade-in on zoom
      if (places != null && places!.isNotEmpty && zoomLevel > 1.5) {
        double opacity = (zoomLevel - 1.5) / 1.5;
        if (opacity > 0.4) opacity = 0.4; // Max opacity 0.4

        final Paint placeFill = Paint()
          ..color = Colors.blueGrey.withValues(alpha: opacity * 0.15)
          ..style = PaintingStyle.fill;
        final Paint placeStroke = Paint()
          ..color = Colors.blueGrey.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 / invariantScale;

        for (var p in places!) {
          var path = pathCache.getPathById(p.id);
          if (path == null) {
            pathCache.cachePath(p.id, p.path);
            path = pathCache.getPathById(p.id);
          }
          if (path != null) {
            canvas.drawPath(path, placeFill);
            canvas.drawPath(path, placeStroke);
          }
        }
      }

      // Draw Highlights (Venn Diagram Style)
      if (selectedFeatures != null && selectedFeatures!.isNotEmpty) {
        // 1. Compute Intersection Path

        Path? intersectionPath;
        for (var f in selectedFeatures!) {
          var path = pathCache.getPathById(f.id);
          if (path == null) {
            try {
              path = parseSvgPathData(f.path);
              pathCache.cachePath(f.id, f.path);
            } catch (_) {
              continue;
            }
          }

          if (intersectionPath == null) {
            intersectionPath = path;
          } else {
            intersectionPath = Path.combine(
              PathOperation.intersect,
              intersectionPath,
              path,
            );
          }
        }

        // 2. Draw Fill (Bottom)
        if (intersectionPath != null) {
          canvas.drawPath(intersectionPath, _intersectionFillPaint);
        }

        // 3. Draw Full Outlines (Top)
        for (var f in selectedFeatures!) {
          var path = pathCache.getPathById(f.id);
          // Should be cached from step 1, but safe check
          if (path == null) {
            try {
              path = parseSvgPathData(f.path);
            } catch (_) {}
          }
          if (path != null) {
            canvas.drawPath(path, _highlightPaint);
          }
        }
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
    CityRenderer.drawCities(
      canvas,
      cities,
      scale,
      zoomLevel,
      pathCache: pathCache,
    );
  }

  @override
  bool shouldRepaint(covariant StateMapPainter oldDelegate) {
    return oldDelegate.stateRecord.id != stateRecord.id ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.showCounties != showCounties ||
        oldDelegate.showDistricts != showDistricts ||
        oldDelegate.showUrban != showUrban ||
        oldDelegate.showZcta != showZcta ||
        oldDelegate.showLakes != showLakes ||
        oldDelegate.showJudicial != showJudicial ||
        oldDelegate.selectedFeatures !=
            selectedFeatures; // Identity check usually fine for list replacement
  }
}
