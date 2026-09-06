use serde::{Deserialize, Serialize};
use std::error::Error;
use std::fs::File;
use std::io::Write;

#[derive(Debug, Deserialize)]
pub struct LegislatorId {
    pub bioguide: Option<String>,
    pub govtrack: Option<u64>,
    pub wikipedia: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct LegislatorName {
    pub first: String,
    pub last: String,
    pub official_full: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct LegislatorTerm {
    #[serde(rename = "type")]
    pub term_type: String, // 'rep' or 'sen'
    pub state: String,
    pub district: Option<u32>,
    pub party: Option<String>,
    pub url: Option<String>,
    pub phone: Option<String>,
    pub contact_form: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct LegislatorRaw {
    pub id: LegislatorId,
    pub name: LegislatorName,
    #[serde(default)]
    pub terms: Vec<LegislatorTerm>,
}

#[derive(Debug, Serialize)]
pub struct RepresentativeRecord {
    pub role: String, // "Representative" or "Senator"
    pub state: String,
    pub district: Option<u32>,
    pub name: String,
    pub party: Option<String>,
    pub phone: Option<String>,
    pub url: Option<String>,
    pub contact_form: Option<String>,
    pub bioguide_id: Option<String>,
}

pub async fn fetch_and_save_congress() -> Result<(), Box<dyn Error>> {
    println!("Fetching current Congress data from @unitedstates...");

    let url = "https://raw.githubusercontent.com/unitedstates/congress-legislators/main/legislators-current.yaml";
    let client = reqwest::Client::new();
    
    let response = client.get(url).send().await?;
    if !response.status().is_success() {
        eprintln!("Error fetching congress data: {}", response.status());
        return Ok(());
    }

    let yaml_content = response.text().await?;
    let legislators: Vec<LegislatorRaw> = serde_yaml::from_str(&yaml_content)?;

    let mut records = Vec::new();

    for leg in legislators {
        if let Some(last_term) = leg.terms.last() {
            let role = if last_term.term_type == "sen" {
                "Senator".to_string()
            } else {
                "Representative".to_string()
            };

            let name = leg.name.official_full.unwrap_or_else(|| format!("{} {}", leg.name.first, leg.name.last));

            records.push(RepresentativeRecord {
                role,
                state: last_term.state.clone(),
                district: last_term.district,
                name,
                party: last_term.party.clone(),
                phone: last_term.phone.clone(),
                url: last_term.url.clone(),
                contact_form: last_term.contact_form.clone(),
                bioguide_id: leg.id.bioguide.clone(),
            });
        }
    }

    println!("Found {} current federal representatives.", records.len());

    let json_output = serde_json::to_string_pretty(&records)?;
    let mut file = File::create("congress.json")?;
    file.write_all(json_output.as_bytes())?;

    println!("Saved to congress.json");

    Ok(())
}
