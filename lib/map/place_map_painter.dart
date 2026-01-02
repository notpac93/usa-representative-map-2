import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../data/models.dart';
import '../utils/map_transform.dart';

class PlaceMapPainter extends CustomPainter {
  final List<PlaceFeature> places;
  final List<PlaceFeature> backgroundPlaces; // New field
  final String? highlightedPlaceId;
  final MapTransform transform;
  final Path? clipPath; // Constraint (County boundary)

  PlaceMapPainter({
    required this.places,
    this.backgroundPlaces = const [], // Default empty
    this.highlightedPlaceId,
    required this.transform,
    this.clipPath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (places.isEmpty && backgroundPlaces.isEmpty) return;

    canvas.save();

    final scale = transform.scale;
    final offX = transform.offset.dx;
    final offY = transform.offset.dy;
    final minX = transform.bbox[0];
    final minY = transform.bbox[1];

    canvas.translate(offX, offY);
    canvas.scale(scale, scale);
    canvas.translate(-minX, -minY);

    // Apply clip if provided (in data space)
    if (clipPath != null) {
      canvas.clipPath(clipPath!);
    }

    // Draw Background (Non-City) Places First
    final Paint bgFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.grey[500]!;

    for (final bgPlace in backgroundPlaces) {
      if (bgPlace.path.isEmpty) continue;
      final path = parseSvgPathData(bgPlace.path);
      path.close(); // Ensure polygons are closed for filling
      canvas.drawPath(path, bgFillPaint);
    }

    // Interactive city style (Very Light Silver/White)
    final Paint cityFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.grey[200]!;

    // Style: Thicker, more prominent lines
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.blueGrey.withOpacity(0.9)
      ..strokeWidth = 1.2 / scale;

    final Paint highlightFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue.withOpacity(0.4);

    final Paint highlightBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.blue
      ..strokeWidth = 2.0 / scale;

    // Draw Interactive Cities
    for (final place in places) {
      if (place.path.isEmpty) continue;

      final Path path = parseSvgPathData(place.path);
      path.close(); // Ensure polygons are closed for filling

      if (place.id == highlightedPlaceId) {
        canvas.drawPath(path, highlightFillPaint);
        canvas.drawPath(path, highlightBorderPaint);
      } else {
        canvas.drawPath(path, cityFillPaint);
        canvas.drawPath(path, borderPaint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PlaceMapPainter oldDelegate) {
    return oldDelegate.places != places ||
        oldDelegate.highlightedPlaceId != highlightedPlaceId ||
        oldDelegate.transform != transform ||
        oldDelegate.clipPath != clipPath;
  }
}
