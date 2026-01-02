import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import * as d3 from 'd3-geo';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const EXTRACT_DIR = path.resolve(__dirname, '../data/raw/tiger-places-extracted');
const OUT_DIR = path.resolve(__dirname, '../assets/data/places');

if (!fs.existsSync(OUT_DIR)) {
    fs.mkdirSync(OUT_DIR, { recursive: true });
}

// Projection setup
const projParamsPath = path.resolve(__dirname, '../data/atlasProjection.json');
let projection = d3.geoAlbersUsa().scale(1070).translate([487.5, 305]);

if (fs.existsSync(projParamsPath)) {
    try {
        const params = JSON.parse(fs.readFileSync(projParamsPath, 'utf8'));
        if (params.scale && params.translate) {
            projection = d3.geoAlbersUsa().scale(params.scale).translate(params.translate);
            console.log(`Using atlas projection: scale=${params.scale}, translate=${params.translate}`);
        }
    } catch (e) {
        console.warn('Failed to read atlasProjection.json, using defaults.');
    }
}

async function convert() {
    const items = fs.readdirSync(EXTRACT_DIR);

    for (const item of items) {
        // Check if it is a directory (FIPS folder)
        const itemPath = path.join(EXTRACT_DIR, item);
        if (!fs.statSync(itemPath).isDirectory()) continue;

        // Find .shp in this directory
        const files = fs.readdirSync(itemPath).filter(f => f.endsWith('.shp'));
        if (files.length === 0) continue;

        const file = files[0];
        if (file.includes('_72_')) continue; // Skip Puerto Rico

        const stateFips = item; // Folder name is FIPS
        const shpPath = path.join(itemPath, file);
        const tempGeoJsonPath = path.join(itemPath, `temp_${stateFips}.json`);
        const outPath = path.join(OUT_DIR, `${stateFips}.json`);

        console.log(`Processing ${stateFips} (${file})...`);

        try {
            // 1. Ogr2Ogr to Raw GeoJSON
            execSync(`ogr2ogr -f GeoJSON -t_srs EPSG:4326 -simplify 0.0001 "${tempGeoJsonPath}" "${shpPath}"`, { stdio: 'pipe' });

            if (!fs.existsSync(tempGeoJsonPath)) {
                console.error(`Failed to generate temp GeoJSON for ${stateFips}`);
                continue;
            }

            // 2. Project
            const rawData = JSON.parse(fs.readFileSync(tempGeoJsonPath, 'utf8'));
            const features = [];

            for (const feature of rawData.features) {
                if (!feature.geometry) continue;
                const projectedGeom = projectGeometry(feature.geometry, projection);
                if (projectedGeom) {
                    feature.geometry = projectedGeom;
                    delete feature.bbox;
                    features.push(feature);
                }
            }

            const outputCollection = {
                type: "FeatureCollection",
                features: features
            };

            fs.writeFileSync(outPath, JSON.stringify(outputCollection));
            fs.unlinkSync(tempGeoJsonPath);

        } catch (e) {
            console.error(`Error processing ${stateFips}:`, e.message);
        }
    }
    console.log('Conversion complete.');
}

function projectGeometry(geometry, projection) {
    const type = geometry.type;
    const coords = geometry.coordinates;

    if (type === 'Polygon') {
        const p = projectPolygon(coords, projection);
        if (!p || p.length === 0) return null;
        return { type: 'Polygon', coordinates: p };
    } else if (type === 'MultiPolygon') {
        const p = coords.map(poly => projectPolygon(poly, projection)).filter(poly => poly && poly.length > 0);
        if (p.length === 0) return null;
        return { type: 'MultiPolygon', coordinates: p };
    }
    return null;
}

function projectPolygon(rings, projection) {
    const newRings = [];
    for (const ring of rings) {
        const newRing = [];
        for (const point of ring) {
            const projected = projection(point);
            if (projected) {
                newRing.push([
                    Math.round(projected[0] * 10) / 10,
                    Math.round(projected[1] * 10) / 10
                ]);
            }
        }
        if (newRing.length > 2) {
            newRings.push(newRing);
        }
    }
    return newRings.length > 0 ? newRings : null;
}

convert();
