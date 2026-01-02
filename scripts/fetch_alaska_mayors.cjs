const fs = require('fs');
const path = require('path');

(async () => {
    const url = 'https://dcra-cdo-dcced.opendata.arcgis.com/api/download/v1/items/1fb7ea7342d840359fb52fedf0255dae/geojson?layers=8';
    console.log(`Fetching Alaska data from ${url}...`);

    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`Fetch failed: ${response.statusText}`);

        const geojson = await response.json();
        const features = geojson.features;
        console.log(`Found ${features.length} features.`);

        const cleaned = [];

        features.forEach(f => {
            const props = f.properties;
            // CommunityName: "Adak"
            // EntityName: "Adak, City of"
            // OfficialName: "Tom Spitler"
            // OfficialPosition: "Mayor"

            // Only want Mayors
            if (props.OfficialPosition && props.OfficialPosition.toLowerCase() === 'mayor') {
                let city = props.CommunityName || props.EntityName;

                // Cleanup
                city = city.replace(/, Municipality of/i, '')
                    .replace(/, City and Borough of/i, '')
                    .replace(/, City of/i, '')
                    .replace(/ City/i, '')
                    .trim();

                if (!city.endsWith(", AK")) city = `${city}, AK`;

                cleaned.push({
                    name: props.OfficialName,
                    city: city,
                    originalCity: props.EntityName,
                    detailsUrl: "https://dcra-cdo-dcced.opendata.arcgis.com/datasets/city-mayors",
                    party: "Nonpartisan",
                    photoUrl: null,
                    phone: null,
                    email: null
                });
            }
        });

        const outputPath = path.join(__dirname, '../data/mayors_ak_full.json');
        fs.writeFileSync(outputPath, JSON.stringify(cleaned, null, 2));
        console.log(`Saved ${cleaned.length} mayors to ${outputPath}`);

    } catch (e) {
        console.error("Failed:", e);
    }
})();
