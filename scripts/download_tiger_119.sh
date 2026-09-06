#!/bin/bash
# Script to download and convert 119th Congress TIGER shapefiles
# This requires ogr2ogr (GDAL) to be installed.

set -e

echo "Downloading 119th Congress TIGER Shapefiles..."
# URL is illustrative; Census Bureau updates this periodically
TIGER_URL="https://www2.census.gov/geo/tiger/TIGER2024/CD/tl_2024_us_cd119.zip"
TMP_DIR="tiger_119_tmp"

mkdir -p $TMP_DIR
cd $TMP_DIR

wget $TIGER_URL -O tl_2024_us_cd119.zip
unzip tl_2024_us_cd119.zip

echo "Converting to GeoJSON (cd119.json)..."
ogr2ogr -f GeoJSON cd119_raw.json tl_2024_us_cd119.shp

echo "Simplifying GeoJSON geometry for web performance..."
# Assuming mapshaper is installed: npm install -g mapshaper
mapshaper cd119_raw.json -simplify dp 5% -o format=geojson ../assets/data/overlays/cd119.json

cd ..
rm -rf $TMP_DIR

echo "Done! Saved to assets/data/overlays/cd119.json"
