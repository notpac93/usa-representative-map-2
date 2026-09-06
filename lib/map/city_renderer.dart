import 'package:flutter/material.dart';
import '../data/models.dart';
import 'atlas_path_cache.dart';

class CityRenderer {
  /// Renders cities with occlusion logic.
  /// [baseScale] is the layout scale applied to fit the map to the screen.
  /// [zoomLevel] is the InteractiveViewer's zoom level.
  static void drawCities(
    Canvas canvas,
    List<CityFeature> cities,
    double baseScale,
    double zoomLevel, {
    bool isNationalMap = false,
    AtlasPathCache? pathCache,
    List<Rect>? existingOccupiedSpaces,
  }) {
    if (cities.isEmpty) return;

    // The effective scale that converts map coordinates to screen pixels.
    final double effectiveScale = baseScale * zoomLevel;

    // We calculate bounds in map-space to test occlusion.
    // To keep text visually the same size on screen, its map-space size must shrink as zoom increases.
    final double mapSpaceMultiplier = 1.0 / effectiveScale;

    final List<Rect> occupiedSpaces = existingOccupiedSpaces != null
        ? List.from(existingOccupiedSpaces)
        : [];

    // Styling constants (visual pixel sizes)
    const double capitalDotRadius = 4.0;
    const double majorDotRadius = 3.0;
    const double minorDotRadius = 2.0;
    const double baseFontSize = 10.0;

    final capitalPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;
    final capitalStrokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * mapSpaceMultiplier;

    final majorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final majorStrokePaint = Paint()
      ..color = Colors.blueGrey[900]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * mapSpaceMultiplier;

    final minorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final minorStrokePaint = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 * mapSpaceMultiplier;

    for (final city in cities) {
      final int pop = city.population ?? 0;
      final bool isMajor = pop > 500000;
      final bool isMedium = pop > 50000 && !isMajor;
      final bool isMinor = pop > 0 && !isMajor && !isMedium;
      final bool isMicro = pop == 0;

      // On national map, only show Capitals and Major cities
      if (isNationalMap && !city.isCapital && !isMajor) {
        continue;
      }

      // Visibility rules based on scale
      if (!city.isCapital && !isMajor) {
        if (isMicro && effectiveScale < 6.0) continue;
        if (isMinor && effectiveScale < 4.0) continue;
        if (isMedium && effectiveScale < 2.0) continue;
      }

      final Paint dotPaint = city.isCapital
          ? capitalPaint
          : (isMajor ? majorPaint : minorPaint);
      final Paint strokePaint = city.isCapital
          ? capitalStrokePaint
          : (isMajor ? majorStrokePaint : minorStrokePaint);

      final double visualRadius = city.isCapital
          ? capitalDotRadius
          : (isMajor ? majorDotRadius : minorDotRadius);
      final double mapSpaceRadius = visualRadius * mapSpaceMultiplier;

      // Prepare Text
      final FontWeight weight = city.isCapital
          ? FontWeight.bold
          : (isMajor ? FontWeight.w600 : FontWeight.normal);
      final double fontSize = baseFontSize * mapSpaceMultiplier;

      // APPROXIMATE BOUNDING BOX (to avoid 32,000 TextPainter.layout calls per frame)
      final double approxTextWidth =
          city.name.length *
          fontSize *
          0.55; // 0.55 is a good average char width ratio for Inter
      final double approxTextHeight = fontSize * 1.2;

      final Offset center = Offset(city.x, city.y);
      final double padding = 2.0 * mapSpaceMultiplier;
      final Rect dotRect = Rect.fromCircle(
        center: center,
        radius: mapSpaceRadius,
      );

      // Try 4 positions: bottom, top, right, left
      final Rect bottomRect = Rect.fromLTWH(
        center.dx - (approxTextWidth / 2),
        center.dy + mapSpaceRadius + padding,
        approxTextWidth,
        approxTextHeight,
      );
      final Rect topRect = Rect.fromLTWH(
        center.dx - (approxTextWidth / 2),
        center.dy - mapSpaceRadius - padding - approxTextHeight,
        approxTextWidth,
        approxTextHeight,
      );
      final Rect rightRect = Rect.fromLTWH(
        center.dx + mapSpaceRadius + padding,
        center.dy - (approxTextHeight / 2),
        approxTextWidth,
        approxTextHeight,
      );
      final Rect leftRect = Rect.fromLTWH(
        center.dx - mapSpaceRadius - padding - approxTextWidth,
        center.dy - (approxTextHeight / 2),
        approxTextWidth,
        approxTextHeight,
      );

      final List<Rect> candidateRects = [
        bottomRect,
        topRect,
        rightRect,
        leftRect,
      ];

      Path? statePath;
      if (pathCache != null && city.stateId != null) {
        statePath = pathCache.getPath(city.stateId!);
      }

      Rect? chosenApproxRect;

      for (final rect in candidateRects) {
        final double margin = 4.0 * mapSpaceMultiplier;
        final Rect combinedRect = dotRect.expandToInclude(rect).inflate(margin);

        bool occluded = false;
        for (final occupied in occupiedSpaces) {
          if (combinedRect.overlaps(occupied)) {
            occluded = true;
            break;
          }
        }

        if (occluded) continue;

        if (statePath != null) {
          // Check if corners are inside the state boundary
          bool inside =
              statePath.contains(rect.topLeft) &&
              statePath.contains(rect.topRight) &&
              statePath.contains(rect.bottomLeft) &&
              statePath.contains(rect.bottomRight);
          if (!inside) {
            // Keep first non-occluded position as a fallback if no perfect fit is found
            chosenApproxRect ??= rect;
            continue;
          }
        }

        chosenApproxRect = rect;
        break; // found perfect position
      }

      if (chosenApproxRect == null) {
        continue; // Skip rendering this city
      }

      // If we survived occlusion, NOW we layout the text and draw
      final textSpan = TextSpan(
        text: city.name,
        style: TextStyle(
          color: Colors.black87,
          fontSize: fontSize,
          fontWeight: weight,
          shadows: [
            Shadow(
              color: Colors.white.withValues(alpha: 0.8),
              blurRadius: 2.0 * mapSpaceMultiplier,
              offset: const Offset(0, 0),
            ),
          ],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Recalculate actual rect for drawing
      final double textWidth = textPainter.width;

      // Determine offset based on which approx rect was chosen
      Offset textOffset;
      if (chosenApproxRect == bottomRect) {
        textOffset = Offset(
          center.dx - (textWidth / 2),
          center.dy + mapSpaceRadius + padding,
        );
      } else if (chosenApproxRect == topRect) {
        textOffset = Offset(
          center.dx - (textWidth / 2),
          center.dy - mapSpaceRadius - padding - textPainter.height,
        );
      } else if (chosenApproxRect == rightRect) {
        textOffset = Offset(
          center.dx + mapSpaceRadius + padding,
          center.dy - (textPainter.height / 2),
        );
      } else {
        // leftRect
        textOffset = Offset(
          center.dx - mapSpaceRadius - padding - textWidth,
          center.dy - (textPainter.height / 2),
        );
      }

      // Draw
      canvas.drawCircle(center, mapSpaceRadius, dotPaint);
      canvas.drawCircle(center, mapSpaceRadius, strokePaint);
      textPainter.paint(canvas, textOffset);

      final double finalMargin = 4.0 * mapSpaceMultiplier;
      final Rect finalCombinedRect = dotRect
          .expandToInclude(chosenApproxRect)
          .inflate(finalMargin);
      occupiedSpaces.add(finalCombinedRect);

      // Stop drawing if we have enough cities to fill the screen
      if (occupiedSpaces.length > 2000) break;
    }
  }
}
