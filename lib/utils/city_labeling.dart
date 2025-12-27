import 'dart:math' as math;

/// Suffixes to remove from city names for cleaner display.
const List<String> _citySuffixes = [
  'city',
  'city and county',
  'city and borough',
  'city and parish',
  'metropolitan government (balance)',
  'metropolitan government',
  'consolidated government',
  'consolidated city-county',
  'consolidated city and county',
  'urban county',
  'cdp',
  'census designated place',
];

/// Regex for suffix removal.
final RegExp _suffixRegex = RegExp(
  '\\s+(?:${_citySuffixes.join('|')})\$',
  caseSensitive: false,
);
final RegExp _urbanRegex = RegExp('^urban\\s+', caseSensitive: false);
final RegExp _urbanInlineRegex = RegExp('\\burban\\b', caseSensitive: false);
final RegExp _balanceRegex = RegExp('\\(balance\\)\$', caseSensitive: false);
final RegExp _cityParenRegex = RegExp('\\(city\\)\$', caseSensitive: false);
final RegExp _multiSpaceRegex = RegExp('\\s{2,}');

/// Sanitizes a raw city name by removing administrative suffixes.
String sanitizeCityLabel(String? rawName) {
  if (rawName == null || rawName.isEmpty) return '';
  String value = rawName.trim();
  value = value.replaceAll(_urbanRegex, '');
  value = value.replaceAll(_urbanInlineRegex, ' ');
  value = value.replaceAll(_balanceRegex, '').replaceAll(_cityParenRegex, '');

  String next = value;
  do {
    value = next;
    next = value.replaceAll(_suffixRegex, '');
  } while (next != value);

  return next.replaceAll(_multiSpaceRegex, ' ').trim();
}

/// Normalizes city name for comparison (lowercase).
String normalizeCityName(String? rawName) {
  return sanitizeCityLabel(rawName).toLowerCase();
}

/// Generates a deterministic jitter value (0.0 - 1.0) from a string.
double jitterFromString(String? value) {
  if (value == null) return 0.5;
  int hash = 0;
  for (int i = 0; i < value.length; i++) {
    hash = (hash * 31 + value.codeUnitAt(i)) & 0xFFFFFFFF;
  }
  return (math.sin(hash) + 1) / 2;
}

class CityLabelVisualStyle {
  final double fontScale;
  final double markerScale;
  final double offsetScale;

  CityLabelVisualStyle({
    required this.fontScale,
    required this.markerScale,
    required this.offsetScale,
  });
}

/// Determines visual styling scales based on zoom and importance.
CityLabelVisualStyle getCityLabelVisual(
  double detailZoomFactor,
  bool isHeroLabel,
) {
  if (isHeroLabel) {
    return CityLabelVisualStyle(
      fontScale: 1.08,
      markerScale: 1.0,
      offsetScale: 0.95,
    );
  }
  final uniformScale = 0.9 * detailZoomFactor;
  return CityLabelVisualStyle(
    fontScale: uniformScale,
    markerScale: 0.8,
    offsetScale: 0.8,
  );
}

class FormattedCityLabel {
  final String text;
  final double fontSize;

  FormattedCityLabel(this.text, this.fontSize);
}

/// Formats text and adjusts font size based on length.
FormattedCityLabel formatCityLabelText(
  String? name,
  bool isHeroLabel,
  double preferredSize,
) {
  final cleanName = sanitizeCityLabel(name);
  if (cleanName.isEmpty) {
    return FormattedCityLabel('', preferredSize);
  }
  final maxChars = isHeroLabel ? 20 : 16;
  final shrinkFactor = cleanName.length > maxChars
      ? maxChars / cleanName.length
      : 1.0;
  final emphasis = isHeroLabel ? 1.05 : 0.9;
  final adjustedSize = preferredSize * shrinkFactor * emphasis;
  return FormattedCityLabel(cleanName, adjustedSize);
}
