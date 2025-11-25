## USA Representative Map

Interactive, offline-first React + TypeScript app that lets users explore US states via an SVG map or list and view high‑level civic representation info per state.

### Features
- Pan & zoom SVG US map (D3 zoom)
- List view alternative with quick navigation
- Per‑state detail sheet with government structure, federal delegation counts, resources, and cited sources
- Dark / light mode (prefers-color-scheme)
- All data embedded (no runtime API calls)

### Tech Stack
- React 19 + TypeScript
- Vite 6
- Tailwind CSS 3
- D3 v7 (zoom & selection utilities)

### Getting Started
Prerequisites: Node.js 18+ (LTS recommended)

1. Install deps:
   ```bash
   npm install
   ```
2. (Optional) Provide a Gemini key if you later add AI features:
   Create `.env.local` with:
   ```bash
   GEMINI_API_KEY=your_key_here
   ```
3. Run dev server:
   ```bash
   npm run dev
   ```

## Map Data Generation Workflow

You can ingest raw Census (or other) shapefiles with almost no manual editing.

1. Download a state (or national) shapefile (e.g. Census Cartographic Boundary States 5m).
2. Place the `.shp`, `.shx`, `.dbf`, and `.prj` files into `data/raw/`.
3. Run an atlas build (example):
   - `npm run build:atlas -- --input data/raw/cb_2023_us_state_5m.shp --simplify 8`
4. The script outputs `data/atlas.generated.ts` which the app can import.

Options:
--input <file>   Path to .shp
--simplify <pct> Visvalingam simplification percent (default 8)
--out <file>     Custom output path (default data/atlas.generated.ts)
--width <px>     Canvas width for projection (default 975)
--height <px>    Canvas height for projection (default 610)

Regenerate any time you adjust simplification. Do not hand-edit the generated file.
4. Open the printed local URL (usually http://localhost:5173).

### TIGER 2025 bulk downloader
Need the full TIGER releases in your workspace? Run our helper script (Node 18+ required):

```bash
npm run download:tiger
```

The script walks every subdirectory under [`https://www2.census.gov/geo/tiger/TIGER2025/`](https://www2.census.gov/geo/tiger/TIGER2025/), downloads each `.zip`, unpacks it into `data/raw/tiger2025/<subdirectory>/<dataset>/`, and drops a `.download-complete` marker so future runs skip already processed archives.

> Heads up: the entire TIGER tree is large—plan for significant disk space and runtime if you grab everything.

#### What gets downloaded?

Each top-level directory under `https://www2.census.gov/geo/tiger/TIGER2025/` is mirrored into `data/raw/tiger2025/<folder>/<dataset>/`. Examples:

| Folder | Sample datasets pulled locally | Primary contents |
| --- | --- | --- |
| `ADDR` / `ADDRFEAT` / `ADDRFN` | `tl_2025_01001_addr/`, `tl_2025_02240_addrfn/` | Address ranges, site names, feature IDs |
| `AREAWATER` & `LINEARWATER` | `tl_2025_02240_areawater/`, … | Polygons & polylines for rivers, lakes, coastline |
| `EDGES`, `FACES`, `FACESAH` | `tl_2025_<county>_edges/` | TIGER topological graph (great for county boundaries/roads) |
| `ROADS`, `PRIMARYROADS`, `PRISECROADS` | `tl_2025_02240_roads/` | Hierarchical road layers |
| `COUNTY`, `COUSUB`, `PLACE`, `TRACT`, … | matching folders per county/state | Administrative boundaries for overlays |

Every extracted folder contains the raw shapefile bundle plus a `.download-complete` marker so reruns can safely skip it.

#### Resuming or targeting subsets

The downloader now honors a couple of opt-in environment variables:

```bash
# Limit crawling to specific top-level folders (comma separated)
TIGER_FOLDERS=ADDR,ROADS npm run download:tiger

# Only download ZIPs whose filename starts with the given prefix
TIGER_ONLY=tl_2025_04001 npm run download:tiger
```

If you interrupt a run midway, just re-run the command—the script deletes any incomplete folder (missing `.download-complete`) before retrying, and prints a summary of downloaded/skipped/failed archives when it finishes.

#### Converting TIGER slices into overlay-ready GeoJSON

Once the raw TIGER folders exist locally, use `processTigerLayer.cjs` to convert specific datasets into simplified GeoJSON chunks you can plug into `buildOverlay.cjs`:

```bash
# Convert ROADS for one or more counties into data/overlays/tiger/roads/<county>.geojson
node scripts/processTigerLayer.cjs \
   --folder ROADS \
   --counties 02240,01001 \
   --simplify 18 \
   --out data/overlays/tiger/roads

# Re-run with --force to overwrite existing GeoJSON
node scripts/processTigerLayer.cjs --folder ROADS --counties 02240 --force
```

Parameters:
- `--folder` (required): the TIGER directory name (ROADS, AREAWATER, COUNTY, etc.).
- `--counties`: comma-separated list of 5-digit FIPS codes; omit to process every downloaded county.
- `--simplify` (default 12%): Visvalingam simplification applied via mapshaper.
- `--out`: destination folder (defaults to `data/overlays/tiger/<folder>`).

Each run emits `*.geojson` chunks—feed them into `scripts/buildOverlay.cjs` (with `--input` pointing to the generated GeoJSON) to produce the TypeScript overlay modules consumed by the app.

#### Building the Interstate Highways overlay

To visualize the national Interstate network you’ll need the TIGER `PRIMARYROADS` download (one ZIP for the whole country), a GeoJSON conversion, and the overlay builder:

```bash
# 1. Grab the PRIMARYROADS archive (≈35 MB) and extract it under data/raw/tiger2025
TIGER_FOLDERS=PRIMARYROADS npm run download:tiger

# 2. Convert it to GeoJSON alongside the county road slices (optional --simplify tweak)
node scripts/processTigerLayer.cjs \
   --folder PRIMARYROADS \
   --out data/overlays/tiger/roads \
   --simplify 12

# 3. Merge, filter RTTYP="I", and emit data/overlays/interstates.generated.ts
node scripts/buildInterstatesOverlay.cjs --simplify 3 --lod 1,4,10
```

The build script reads every `*.geojson` under `data/overlays/tiger/roads`, so you can mix national `PRIMARYROADS` slices with per-county `ROADS` exports if you prefer to scope smaller regions. The resulting overlay is exposed in the UI as “Interstate Highways” and is clipped automatically on the state detail view.

#### Auditing the generated cities overlay

Want to know how complete `data/overlays/cities.generated.ts` is compared to the latest Census place dataset? Run the verifier:

```bash
# Compare the overlay against the 2025 Gazetteer file, filtering to active places (FUNCSTAT=A)
node scripts/verifyCitiesCompleteness.cjs \
   --source data/raw/places/2025_Gaz_place_national.txt \
   --minpop 0 \
   --funcstat A

# Or point it at a TIGER place/populated-place shapefile
node scripts/verifyCitiesCompleteness.cjs \
   --source data/raw/tl_2023_us_place/tl_2023_us_place.shp \
   --minpop 0 \
   --report tmp/city-gap-report.json
```

Key flags:
- `--overlay` (defaults to `data/overlays/cities.generated.ts`)
- `--source` (required): Gazetteer `.txt`, GeoJSON, or shapefile `.shp`
- `--minpop`: only count places meeting this population (set to 0 to include every record that has coordinates)
- `--funcstat`: comma-separated FUNCSTAT codes to include (e.g., `A,S`)
- `--report`: optional path to emit a JSON summary of missing/mismatched places

The script prints overall coverage, per-state stats, the largest missing places (by population), and any overlay entries that no longer exist in the source data. Use it before regenerating the overlay to confirm whether new population thresholds or source files would materially change the map.

#### Emitting per-state coverage metadata

Need structured stats for the UI? Run:

```bash
npm run build:city-coverage
```

This wraps the verifier, then writes `data/cityCoverage.generated.ts`, exporting:

- `cityCoverageMeta`: run metadata (source path, filters, and top missing cities)
- `cityCoverage`: per-state coverage ratios and a short list of missing examples

Import `cityCoverage` anywhere in the app to highlight how complete each state's city directory is, or to prioritize future data backfills.

### Production Build
```bash
npm run build
npm run preview   # serve built assets locally
```

### Scraping official USA.gov links
We ship a Playwright helper that clicks through [USA.gov's state government directory](https://www.usa.gov/state-governments) like a human (one state at a time) and captures the links listed under “State government website” and “Governor”.

1. Install deps (includes Playwright):
    ```bash
    npm install
    ```
    The first run may ask to download browser binaries—follow the prompt.
2. Run the scraper (headless by default):
    ```bash
    npm run scrape:usa-gov
    ```
    - Set `HEADLESS=false` to watch the browser as it clicks through states.
    - Set `SLOWMO=250` (ms) to slow interactions and make them appear more “human”.

Output is saved to `data/usaGovSites.json` in this shape:

```json
[
   {
      "state": "Alabama",
      "stateGovSites": [{ "label": "Alabama", "url": "https://www.alabama.gov/" }],
      "governorSites": [
         { "label": "Governor Kay Ivey", "url": "https://governor.alabama.gov/" },
         { "label": "Contact Governor Ivey", "url": "https://governor.alabama.gov/contact/" }
      ],
      "scrapedAt": "2025-11-18T12:34:56.789Z"
   }
]
```

Feel free to re-run the command whenever you need refreshed links—the JSON file is overwritten each time.

### How the Map Pipeline Works (Short Version)
1. Build (offline preprocessing)
   - You run the script (`npm run build:atlas`) against a Census state polygon shapefile.
   - Mapshaper (via our script) optionally dissolves by `STUSPS`, simplifies with Visvalingam (%), and outputs raw GeoJSON.
   - We do NOT project inside mapshaper (default) to avoid double projection; instead d3’s `geoAlbersUsa()` fits the geometry to the target width/height.
   - The script serializes the result as a TypeScript module `data/atlas.generated.ts` containing: width, height, projection label, and an array of states each with id, name, bbox, centroid, and a precomputed SVG path string.

2. Runtime load
   - App imports (or dynamically loads) that generated module—no network fetch needed.
   - Each state already has its flattened SVG path; no client-side reprojection or topo decoding step.

3. Rendering
   - `MapView` renders one `<svg>` sized by atlas dimensions; each state becomes a `<path d=...>`.
   - A single D3 zoom behavior modifies a wrapping `<g>` transform (matrix pan/scale) instead of recomputing paths.

4. Interaction & accessibility
   - Paths are focusable (role=button + keyboard Enter/Space select).
   - Hover/focus updates a tooltip and an ARIA live region.
   - Very small states get duplicate transparent hit areas for easier clicking.

5. Performance rationale
   - Heavy GIS (dissolve, simplify, projection fit) runs once at build-time.
   - Browser just paints static path data + applies a transform; minimal CPU and no geo libraries in the critical path.
   - Simplification % lets you trade fidelity for bundle size by regenerating the atlas.

In short: Shapefile → build script precomputes everything → lightweight SVG render with D3 zoom.

### Project Structure
- `App.tsx` root layout & navigation
- `components/` view components (Map, List, Details, About, Icons)
- `data/` statically embedded state geometry + civic data
- `index.html` entry document (no external CDN deps; everything bundled)
- `tailwind.config.cjs` / `postcss.config.cjs` styling pipeline

### Adding More State Data
Extend `data/stateData.ts` with additional state entries conforming to `StateDetail` in `types.ts`.

### Future Enhancements (Ideas)
- Add all remaining states to `stateData.ts`
- Search / filter in list view
- Progressive Web App (PWA) manifest & service worker for installability
- Unit tests (React Testing Library + Vitest)
- Accessibility audit improvements (focus outlines for map paths, ARIA labels)

### License / Data
Geometry derived from public domain U.S. Census cartographic boundary files. Other data from cited official sources per state.

