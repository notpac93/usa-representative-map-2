export type LabelZoomStop = {
  zoom: number;
  font: number;
  marker: number;
  stroke: number;
  offsetX: number;
  offsetY: number;
  detail: number;
  spacing: number;
  padding: number;
};

export type LabelMetrics = Omit<LabelZoomStop, 'zoom'>;

export const CITY_LABEL_ZOOM_STOPS: LabelZoomStop[] = [
  { zoom: 1, font: 13.2, marker: 2.6, stroke: 0.9, offsetX: 3.8, offsetY: 2.5, detail: 1, spacing: 1.05, padding: 1.05 },
  { zoom: 2, font: 10.8, marker: 2.1, stroke: 0.75, offsetX: 3.1, offsetY: 2, detail: 0.92, spacing: 0.92, padding: 0.95 },
  { zoom: 3.5, font: 8.4, marker: 1.6, stroke: 0.62, offsetX: 2.4, offsetY: 1.6, detail: 0.82, spacing: 0.82, padding: 0.85 },
  { zoom: 6, font: 6.2, marker: 1.1, stroke: 0.5, offsetX: 1.6, offsetY: 1.2, detail: 0.68, spacing: 0.72, padding: 0.75 },
];

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

const interpolate = (a: number, b: number, t: number) => a + (b - a) * t;

function stripZoom(stop: LabelZoomStop): LabelMetrics {
  const { zoom: _zoom, ...rest } = stop;
  return rest;
}

export function resolveLabelMetrics(zoom: number, stops: LabelZoomStop[]): LabelMetrics {
  if (!stops.length) {
    return {
      font: 10,
      marker: 2,
      stroke: 0.7,
      offsetX: 3,
      offsetY: 2,
      detail: 1,
      spacing: 1,
      padding: 1,
    };
  }

  if (zoom <= stops[0].zoom) {
    return stripZoom(stops[0]);
  }

  for (let i = 1; i < stops.length; i += 1) {
    const current = stops[i];
    if (zoom <= current.zoom) {
      const previous = stops[i - 1];
      const t = clamp((zoom - previous.zoom) / Math.max(1e-6, current.zoom - previous.zoom), 0, 1);
      return {
        font: interpolate(previous.font, current.font, t),
        marker: interpolate(previous.marker, current.marker, t),
        stroke: interpolate(previous.stroke, current.stroke, t),
        offsetX: interpolate(previous.offsetX, current.offsetX, t),
        offsetY: interpolate(previous.offsetY, current.offsetY, t),
        detail: interpolate(previous.detail, current.detail, t),
        spacing: interpolate(previous.spacing, current.spacing, t),
        padding: interpolate(previous.padding, current.padding, t),
      };
    }
  }

  return stripZoom(stops[stops.length - 1]);
}
