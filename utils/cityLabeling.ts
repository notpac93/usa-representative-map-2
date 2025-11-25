const CITY_SUFFIXES = [
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

const SUFFIX_REGEX = new RegExp(`\\s+(?:${CITY_SUFFIXES.join('|')})$`, 'i');

export function sanitizeCityLabel(rawName: string | undefined | null): string {
  if (!rawName) return '';
  let value = rawName.trim();
  value = value.replace(/^urban\s+/i, '');
  value = value.replace(/\burban\b/gi, ' ');
  value = value.replace(/\(balance\)$/i, '').replace(/\(city\)$/i, '');
  let next = value;
  do {
    value = next;
    next = value.replace(SUFFIX_REGEX, '');
  } while (next !== value);
  return next.replace(/\s{2,}/g, ' ').trim();
}

export function normalizeCityName(rawName: string | undefined | null): string {
  return sanitizeCityLabel(rawName).toLowerCase();
}

export function jitterFromString(value: string | undefined | null): number {
  if (!value) return 0.5;
  let hash = 0;
  for (let i = 0; i < value.length; i += 1) {
    hash = (hash * 31 + value.charCodeAt(i)) >>> 0;
  }
  return (Math.sin(hash) + 1) / 2;
}

export type CityLabelVisualStyle = {
  fontScale: number;
  markerScale: number;
  offsetScale: number;
};

export function getCityLabelVisual(detailZoomFactor: number, isHeroLabel: boolean): CityLabelVisualStyle {
  if (isHeroLabel) {
    return { fontScale: 1.08, markerScale: 1, offsetScale: 0.95 };
  }
  const uniformScale = 0.9 * detailZoomFactor;
  return { fontScale: uniformScale, markerScale: 0.8, offsetScale: 0.8 };
}

export function formatCityLabelText(name: string | undefined, isHeroLabel: boolean, preferredSize: number) {
  const cleanName = sanitizeCityLabel(name || '');
  if (!cleanName) {
    return { text: '', fontSize: preferredSize };
  }
  const maxChars = isHeroLabel ? 20 : 16;
  const shrinkFactor = cleanName.length > maxChars ? maxChars / cleanName.length : 1;
  const emphasis = isHeroLabel ? 1.05 : 0.9;
  const adjustedSize = Math.max(isHeroLabel ? 7.2 : 5.8, preferredSize * shrinkFactor * emphasis);
  return { text: cleanName, fontSize: adjustedSize };
}
