# Places Gazetteer Raw Data

Add the Census Gazetteer Places file here, e.g. `2025_Gaz_place_national.txt`.

Source: https://www.census.gov/geographies/reference-files/time-series/geo/gazetteer-files.html

Fields used:
- `GEOID` or `GEOIDFQ` (identifier)
- `NAME` (place name)
- `INTPTLAT`, `INTPTLONG` (internal point lat/lon)

Example build command:
```
node scripts/buildCities.cjs --input data/raw/places/2025_Gaz_place_national.txt --out data/overlays/cities.generated.ts --year 2025 --minpop 0
```
