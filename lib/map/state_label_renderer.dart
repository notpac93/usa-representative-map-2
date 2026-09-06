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
    final List<Rect> occupiedSpaces = [];
    final double effectiveScale = baseScale * zoomLevel;
    final double mapSpaceMultiplier = 1.0 / effectiveScale;

    final double fontSize = 14.0 * mapSpaceMultiplier;
    final double smallFontSize = 12.0 * mapSpaceMultiplier;

    final linePaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1.0 * mapSpaceMultiplier
      ..style = PaintingStyle.stroke;

    for (final state in atlas.states) {
      final Offset centroid = Offset(state.centroid[0], state.centroid[1]);

      // Calculate approximate state size in map space
      final double width = state.bbox[2] - state.bbox[0];
      final double height = state.bbox[3] - state.bbox[1];

      // Format text
      final textSpan = TextSpan(
        text: state.name,
        style: TextStyle(
          color: Colors.black87,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.white.withValues(alpha: 0.9),
              blurRadius: 3.0 * mapSpaceMultiplier,
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

      // Does the text fit comfortably inside the state bounding box?
      // We check if the state's width and height (with some margin) is larger than the text
      bool fits =
          (width * 0.7 > textPainter.width) &&
          (height * 0.7 > textPainter.height);

      if (fits || !smallStateOffsets.containsKey(state.fips)) {
        // Draw centered
        // If it doesn't fit but it's not a small state, we still draw it centered (might overlap borders slightly but usually fine)
        final Offset textOffset = Offset(
          centroid.dx - (textPainter.width / 2),
          centroid.dy - (textPainter.height / 2),
        );
        textPainter.paint(canvas, textOffset);

        final Rect textRect = Rect.fromLTWH(
          textOffset.dx,
          textOffset.dy,
          textPainter.width,
          textPainter.height,
        );
        occupiedSpaces.add(
          textRect.inflate(10.0 * mapSpaceMultiplier),
        ); // Generous margin around state name
      } else {
        // It's a small state and doesn't fit: draw with an offset line
        final Offset offsetMapSpace = smallStateOffsets[state.fips]!;

        // Scale the hardcoded offset slightly based on zoom so it doesn't fly away too far when zoomed in
        // but keeps enough distance when zoomed out
        final double offsetScale = (1.0 / zoomLevel).clamp(0.5, 2.0);

        final Offset labelPos = Offset(
          centroid.dx + (offsetMapSpace.dx * offsetScale),
          centroid.dy + (offsetMapSpace.dy * offsetScale),
        );

        // Draw line
        canvas.drawLine(centroid, labelPos, linePaint);

        // Draw abbreviation
        final abbrSpan = TextSpan(
          text: stateAbbreviations[state.fips] ?? state.name,
          style: TextStyle(
            color: Colors.black87,
            fontSize: smallFontSize,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.white.withValues(alpha: 0.9),
                blurRadius: 3.0 * mapSpaceMultiplier,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        );

        final abbrPainter = TextPainter(
          text: abbrSpan,
          textDirection: TextDirection.ltr,
        );
        abbrPainter.layout();

        // Adjust text offset so the line points nicely to the text
        Offset finalLabelOffset;
        if (offsetMapSpace.dx > 0) {
          // Label is to the right, line points to left-middle of text
          finalLabelOffset = Offset(
            labelPos.dx + (2 * mapSpaceMultiplier),
            labelPos.dy - (abbrPainter.height / 2),
          );
        } else {
          // Label is to the left, line points to right-middle of text
          finalLabelOffset = Offset(
            labelPos.dx - abbrPainter.width - (2 * mapSpaceMultiplier),
            labelPos.dy - (abbrPainter.height / 2),
          );
        }

        abbrPainter.paint(canvas, finalLabelOffset);

        final Rect textRect = Rect.fromLTWH(
          finalLabelOffset.dx,
          finalLabelOffset.dy,
          abbrPainter.width,
          abbrPainter.height,
        );
        occupiedSpaces.add(textRect.inflate(6.0 * mapSpaceMultiplier));
      }
    }

    return occupiedSpaces;
  }
}
