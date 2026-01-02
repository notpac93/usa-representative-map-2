import 'dart:ui';

class MapTransform {
  final double scale;
  final Offset offset;
  final List<double> bbox;

  MapTransform({required this.scale, required this.offset, required this.bbox});

  /// Calculates the scale and offset to fit the [bbox] into [viewSize] (contain).
  static MapTransform calculateFit(List<double> bbox, Size viewSize) {
    if (viewSize.isEmpty) {
      return MapTransform(scale: 1.0, offset: Offset.zero, bbox: bbox);
    }

    final bboxWidth = bbox[2] - bbox[0];
    final bboxHeight = bbox[3] - bbox[1];

    if (bboxWidth <= 0 || bboxHeight <= 0) {
      return MapTransform(scale: 1.0, offset: Offset.zero, bbox: bbox);
    }

    final scaleX = viewSize.width / bboxWidth;
    final scaleY = viewSize.height / bboxHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY; // fit contain

    final offsetX = (viewSize.width - (bboxWidth * scale)) / 2;
    final offsetY = (viewSize.height - (bboxHeight * scale)) / 2;

    return MapTransform(
      scale: scale,
      offset: Offset(offsetX, offsetY),
      bbox: bbox,
    );
  }

  /// Converts a screen point (relative to the view/canvas) to data coordinates.
  Offset screenToData(Offset screenPoint) {
    // Inverse of:
    // canvas.translate(offsetX, offsetY);
    // canvas.scale(scale);
    // canvas.translate(-bbox[0], -bbox[1]);
    //
    // x_screen = (x_data - bbox[0]) * scale + offsetX
    // x_data = (x_screen - offsetX) / scale + bbox[0]

    final x = (screenPoint.dx - offset.dx) / scale + bbox[0];
    final y = (screenPoint.dy - offset.dy) / scale + bbox[1];
    return Offset(x, y);
  }
}
