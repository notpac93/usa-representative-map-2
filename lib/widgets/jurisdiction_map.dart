import 'package:flutter/material.dart';

class JurisdictionMap extends StatelessWidget {
  final Path? targetPath;
  final Path? contextPath;
  final Rect bounds;

  const JurisdictionMap({
    super.key,
    this.targetPath,
    this.contextPath,
    required this.bounds,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _JurisdictionMapPainter(
        targetPath: targetPath,
        contextPath: contextPath,
        bounds: bounds,
      ),
      size: Size.infinite,
    );
  }
}

class _JurisdictionMapPainter extends CustomPainter {
  final Path? targetPath;
  final Path? contextPath;
  final Rect bounds;

  _JurisdictionMapPainter({
    this.targetPath,
    this.contextPath,
    required this.bounds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bounds.isEmpty) return;

    // Calculate scale to fit bounds into size
    final double scaleX = size.width / bounds.width;
    final double scaleY = size.height / bounds.height;
    final double scale =
        (scaleX < scaleY ? scaleX : scaleY) * 0.9; // 90% fit for padding

    // Center the map
    final double offsetX =
        (size.width - (bounds.width * scale)) / 2 - (bounds.left * scale);
    final double offsetY =
        (size.height - (bounds.height * scale)) / 2 - (bounds.top * scale);

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    final Paint contextPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;

    final Paint targetPaint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / scale; // Constant visual width

    // Draw context (State)
    if (contextPath != null) {
      canvas.drawPath(contextPath!, contextPaint);
      canvas.drawPath(contextPath!, borderPaint);
    }

    // Draw target (District/City)
    if (targetPath != null) {
      canvas.drawPath(targetPath!, targetPaint);
      // Optional: Draw border for target
      canvas.drawPath(
        targetPath!,
        Paint()
          ..color = Colors.blue.shade800
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / scale,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
