export interface StateRecord {
  id: string;
  name: string;
  fips: string;
  path: string;
  bbox: [number, number, number, number];
  centroid: [number, number];
  geometry?: {
    type: 'Polygon' | 'MultiPolygon';
    coordinates: any;
  };
}

export interface Atlas {
  width: number;
  height: number;
  projection: string;
  states: StateRecord[];
  projectionParams?: { scale: number|null; translate: [number,number]|null };
}

// Generic overlay feature (e.g., Urban Areas polygons) rendered atop a state map
export interface OverlayFeature {
  id: string;
  name: string;
  path: string; // SVG path
  // Optional multi-LOD alternatives (lower detail for far zooms)
  pathMid?: string; // medium detail
  pathLow?: string; // low detail
  bbox: [number, number, number, number];
}

export interface OverlayLayer {
  key: string;          // unique key e.g. 'urban-areas'
  label: string;        // UI label
  features: OverlayFeature[];
  source?: string;      // optional source description / URL
  stroke?: string;
  fill?: string;
  strokeWidth?: number;
  lineCap?: 'butt' | 'round' | 'square';
  category?: string;    // grouping/category (e.g., 'Demographics', 'Boundaries')
  legend?: Array<{ label: string; stroke?: string; fill?: string; shape?: 'line' | 'rect' | 'circle' }>; // optional legend entries
  // Optional projection parameters captured at build time to verify alignment consistency
  projectionParams?: { scale: number|null; translate: [number,number]|null };
  hidden?: boolean;
  renderOrder?: number;
}

// City point feature (projected coordinates + original lon/lat)
export interface CityFeature {
  id: string;
  name: string;
  x: number; // projected x (same coordinate space as atlas)
  y: number; // projected y
  lon: number; // original longitude
  lat: number; // original latitude
  population?: number | null; // optional joined population
}

export interface CityLayer {
  key: string; // 'cities'
  label: string; // e.g. 'Cities (2023)'
  features: CityFeature[];
  source?: string;
  stroke?: string; // for potential halo strokes around labels
  fill?: string;   // point fill color if rendered as circles
  projectionParams?: { scale: number|null; translate: [number,number]|null };
}

export interface CityCoverageStats {
  state: string;
  stateName: string;
  source: number;
  covered: number;
  coverage: number; // 0..1 ratio
  missingExamples: string[];
}

export type CityCoverageMap = Record<string, CityCoverageStats>;

export interface CityCoverageGap {
  id: string | null;
  name: string;
  stateAbbr: string | null;
  stateName: string | null;
  population: number | null;
}

export interface CityCoverageMeta {
  generatedAt: string;
  overlayPath: string;
  sourcePath: string;
  minPopulation: number;
  funcstatFilter: string;
  overlayFeatureCount: number;
  sourceFeatureCount: number;
  coverageRatio: number;
  topMissing: CityCoverageGap[];
}

export interface StateDetail {
  id: string;
  name: string;
  last_updated: string;
  government: {
    branches: Array<{ name: string; details: string }>;
    legislature: {
      upper_chamber_name: string;
      lower_chamber_name: string;
    };
  };
  federal_representation: {
    senators: Array<{ name: string; party: string; term_end?: string }>;
    house_districts: number;
    representatives?: HouseRepresentative[];
  };
  resources: Array<{ label: string; url: string }>;
  state_sites?: Array<{ label: string; url: string }>;
  governor_sites?: Array<{ label: string; url: string }>;
  sources: Array<{ label:string; url: string }>;
  // Added: consolidated list of key officials / representatives for per-official pages
  officials?: Official[];
}

export interface HouseRepresentative {
  name: string;
  officialName?: string;
  party: string;
  partyName?: string;
  district: string;
  districtNumber: number | null;
  isAtLarge?: boolean;
  isDelegate?: boolean;
  office?: string;
  phone?: string;
  committees?: string[];
  website?: string;
  slug: string;
  bioguideId?: string;
  hometown?: string;
  profileUrl?: string;
  photoUrl?: string;
  photoLocalPath?: string;
}

export interface Official {
  id: string;            // stable slug, e.g. 'governor', 'senator-padilla'
  role: string;          // Governor, U.S. Senator, etc.
  name: string;
  party?: string;
  portrait_url?: string; // optional image URL
  facts?: string[];      // bullet points / important facts
  promises?: string[];   // campaign promises or key issues
  links?: Array<{ label: string; url: string }>; // external references
  placeholder?: boolean; // true if auto-generated placeholder
}

export type StateDetailData = Record<string, StateDetail>;
