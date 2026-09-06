import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../data/models.dart';
import 'city_renderer.dart';
import 'state_label_renderer.dart';
import 'atlas_path_cache.dart';

class NationalMapPainter extends CustomPainter {
  final Atlas atlas;
  final AtlasPathCache pathCache;
  final String? selectedStateId;
  final String? hoveredStateId;
  final TransformationController? transformController;
  final List<CityFeature> cities;

  // Paints (created once or passed in would be better, but lazy init here is fine for now)
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5
    ..color = Colors.white;

  NationalMapPainter({
    required this.atlas,
    required this.pathCache,
    this.selectedStateId,
    this.hoveredStateId,
    this.transformController,
    this.cities = const [],
  }) : super(repaint: transformController) {
    // Ensure cache is populated
    pathCache.parseAndCache(atlas);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // D3 Projection alignment:
    // The SVG paths are pre-projected to fit within atlas.width x atlas.height (e.g. 960x600).
    // We must scale the canvas to fit these paths into the widget Size.

    final scaleX = size.width / atlas.width;
    final scaleY = size.height / atlas.height;
    final scale = scaleX < scaleY ? scaleX : scaleY; // fit contain

    // Center the map
    final offsetX = (size.width - (atlas.width * scale)) / 2;
    final offsetY = (size.height - (atlas.height * scale)) / 2;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    for (var state in atlas.states) {
      final path = pathCache.getPath(state.id);
      if (path == null) continue;

      // Styling
      bool isSelected = state.id == selectedStateId;
      bool isHovered = state.id == hoveredStateId;

      if (isSelected) {
        _fillPaint.color = Colors.blueGrey[800]!;
      } else if (isHovered) {
        _fillPaint.color = Colors.blueGrey[300]!;
      } else {
        _fillPaint.color = Colors.grey[200]!;
      }

      canvas.drawPath(path, _fillPaint);
      canvas.drawPath(path, _strokePaint);
    }

    // Determine dynamic zoom level from InteractiveViewer
    double currentZoom = 1.0;
    if (transformController != null) {
      currentZoom = transformController!.value.getMaxScaleOnAxis();
    }

    // Draw state labels first, which returns the occupied bounds of the state names
    final List<Rect> stateLabelBounds = StateLabelRenderer.drawStateLabels(
      canvas,
      atlas,
      scale,
      currentZoom,
    );

    // Draw cities using the shared renderer, passing state label bounds
    CityRenderer.drawCities(
      canvas,
      cities,
      scale,
      currentZoom,
      isNationalMap: true,
      pathCache: pathCache,
      existingOccupiedSpaces: stateLabelBounds,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant NationalMapPainter oldDelegate) {
    return oldDelegate.selectedStateId != selectedStateId ||
        oldDelegate.hoveredStateId != hoveredStateId ||
        oldDelegate.cities != cities;
  }
}
