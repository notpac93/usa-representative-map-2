import 'package:flutter/material.dart';

import '../data/models.dart';
import '../utils/map_transform.dart';
import 'atlas_path_cache.dart';

/// Shared map artwork for the national screen and the US States landing tile.
class NationalMap extends StatelessWidget {
  const NationalMap({
    super.key,
    required this.atlas,
    required this.pathCache,
    this.selectedStateId,
    this.onStateSelected,
  });

  final Atlas atlas;
  final AtlasPathCache pathCache;
  final String? selectedStateId;
  final ValueChanged<String>? onStateSelected;

  @override
  Widget build(BuildContext context) {
    final canvas = LayoutBuilder(
      builder: (context, constraints) {
        final transform = MapTransform.calculateFit([
          0,
          0,
          atlas.width,
          atlas.height,
        ], constraints.biggest);
        final artwork = CustomPaint(
          size: constraints.biggest,
          painter: _NationalMapPainter(
            atlas,
            pathCache,
            transform,
            selectedStateId,
          ),
        );
        final selectState = onStateSelected;
        if (selectState == null) return artwork;
        return GestureDetector(
          onTapUp: (tap) {
            final point = transform.screenToData(tap.localPosition);
            for (final state in atlas.states) {
              if (pathCache.getPath(state.id)?.contains(point) ?? false) {
                selectState(state.id);
                return;
              }
            }
          },
          child: artwork,
        );
      },
    );

    return AspectRatio(
      aspectRatio: atlas.width / atlas.height,
      child: onStateSelected == null
          ? canvas
          : Semantics(
              label:
                  'United States map. All states are available in the state picker.',
              child: InteractiveViewer(maxScale: 8, child: canvas),
            ),
    );
  }
}

class _NationalMapPainter extends CustomPainter {
  const _NationalMapPainter(
    this.atlas,
    this.pathCache,
    this.transform,
    this.selectedStateId,
  );

  static const _labeledStates = {
    'AK',
    'HI',
    'CA',
    'WA',
    'MT',
    'CO',
    'TX',
    'MN',
    'MI',
    'NY',
    'FL',
    'GA',
    'ME',
  };
  static const _smallPreviewLabels = {'AK', 'CA', 'TX', 'NY', 'FL'};

  final Atlas atlas;
  final AtlasPathCache pathCache;
  final MapTransform transform;
  final String? selectedStateId;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(transform.offset.dx, transform.offset.dy);
    canvas.scale(transform.scale);

    final fill = Paint()..color = const Color(0xFFC5D7E9);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / transform.scale
      ..color = const Color(0xFFF6F8FC);

    for (final state in atlas.states) {
      final path = pathCache.getPath(state.id);
      if (path == null || state.id == selectedStateId) continue;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    }
    final selectedPath = pathCache.getPath(selectedStateId ?? '');
    if (selectedPath != null) {
      canvas.drawPath(selectedPath, fill..color = const Color(0xFF264A72));
      canvas.drawPath(selectedPath, edge..color = const Color(0xFFE9A6B6));
    }

    final labels = size.width < 260 ? _smallPreviewLabels : _labeledStates;
    final labelSize = size.width < 260 ? 9.0 : 13.0;
    for (final state in atlas.states) {
      if (!labels.contains(state.id) || state.centroid.length != 2) continue;
      final label = TextPainter(
        text: TextSpan(
          text: state.id,
          style: TextStyle(
            color: state.id == selectedStateId
                ? Colors.white
                : const Color(0xFF152A43),
            fontSize: labelSize / transform.scale,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(
          state.centroid[0] - label.width / 2,
          state.centroid[1] - label.height / 2,
        ),
      );
      label.dispose();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_NationalMapPainter oldDelegate) =>
      atlas != oldDelegate.atlas ||
      pathCache != oldDelegate.pathCache ||
      selectedStateId != oldDelegate.selectedStateId ||
      transform.scale != oldDelegate.transform.scale ||
      transform.offset != oldDelegate.transform.offset;
}
