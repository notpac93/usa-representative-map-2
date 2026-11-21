import 'package:flutter/material.dart';
import '../data/models.dart';

class StateLabelRenderer {
  // Hardcoded map-space offsets for small northeastern states
  static const Map<String, Offset> smallStateOffsets = {
    '44': Offset(25, 25), // Rhode Island
    '10': Offset(35, 15), // Delaware
    '34': Offset(40, 0), // New Jersey
    '09': Offset(15, 30), // Connecticut
    '25': Offset(40, -5), // Massachusetts
    '24': Offset(35, -20), // Maryland
    '33': Offset(40, -30), // New Hampshire
    '50': Offset(-35, -35), // Vermont
    '11': Offset(30, 30), // District of Columbia
  };

  // State abbreviations
  static const Map<String, String> stateAbbreviations = {
    '44': 'RI',
    '10': 'DE',
    '34': 'NJ',
    '09': 'CT',
    '25': 'MA',
    '24': 'MD',
    '33': 'NH',
    '50': 'VT',
    '11': 'DC',
  };

  static List<Rect> drawStateLabels(
    Canvas canvas,
    Atlas atlas,
    double baseScale,
    double zoomLevel,
  ) {
    final occupiedSpaces = <Rect>[];
    final effectiveScale = baseScale * zoomLevel;
    if (effectiveScale <= 0) return occupiedSpaces;
    final multiplier = 1 / effectiveScale;
    // Place larger states first. Small labels appear as zoom creates room,
    // rather than piling up over neighboring northeastern states.
    final states = [...atlas.states]
      ..sort((a, b) {
        double area(StateRecord s) =>
            (s.bbox[2] - s.bbox[0]) * (s.bbox[3] - s.bbox[1]);
        return area(b).compareTo(area(a));
      });
    for (final state in states) {
      final width = state.bbox[2] - state.bbox[0];
      final height = state.bbox[3] - state.bbox[1];
      final painter = TextPainter(
        text: TextSpan(
          text: stateAbbreviations[state.fips] ?? state.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11 * multiplier,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (width < painter.width * 1.2 || height < painter.height * 1.15)
        continue;
      final origin = Offset(
        state.centroid[0] - painter.width / 2,
        state.centroid[1] - painter.height / 2,
      );
      final rect = origin & painter.size;
      final padded = rect.inflate(3 * multiplier);
      if (occupiedSpaces.any((r) => r.overlaps(padded))) continue;
      painter.paint(canvas, origin);
      occupiedSpaces.add(padded);
    }
    return occupiedSpaces;
  }
}
