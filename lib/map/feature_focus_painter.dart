import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../data/models.dart';
import '../utils/map_transform.dart';

class FeatureFocusPainter extends CustomPainter {
  final OverlayFeature feature;
  final MapTransform transform;

  FeatureFocusPainter({required this.feature, required this.transform});

  @override
  void paint(Canvas canvas, Size size) {
    if (feature.path.isEmpty) return;

    final Paint fillPaint = Paint()
      ..color =
          Colors.grey[300]! // Light background for the county
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.blueGrey[600]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / transform.scale;

    canvas.save();

    // Apply transform
    canvas.translate(transform.offset.dx, transform.offset.dy);
    canvas.scale(
      transform.scale,
      transform.scale,
    ); // Normal scale (Y-flip handled by MapTransform logic?)
    // Wait, MapTransform assumes standard coordinate space.
    // StateMapPainter uses pathCache which has pre-parsed paths.
    // Here we parse locally.
    // The Atlas data (and thus OverlayFeature paths) are usually in a projected space (already flipped/scaled to fit USA).
    // So we just translate/scale to zoom in. No extra Y-flip needed usually.

    canvas.translate(-transform.bbox[0], -transform.bbox[1]);

    final Path path = parseSvgPathData(feature.path);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FeatureFocusPainter oldDelegate) {
    return oldDelegate.feature != feature || oldDelegate.transform != transform;
  }
}
