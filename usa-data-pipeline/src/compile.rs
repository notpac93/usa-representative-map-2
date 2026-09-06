use serde::{Deserialize, Serialize};
use std::error::Error;
use std::fs;
use std::fs::File;
use std::io::Write;

#[derive(Debug, Deserialize, Serialize)]
pub struct MayorRecord {
    pub city: String,
    pub state: String,
    pub mayor: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct RepresentativeRecord {
    pub role: String,
    pub state: String,
    pub district: Option<u32>,
    pub name: String,
    pub party: Option<String>,
    pub phone: Option<String>,
    pub url: Option<String>,
    pub contact_form: Option<String>,
    pub bioguide_id: Option<String>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct JusticeRecord {
    pub name: String,
    pub title: String,
}

#[derive(Debug, Serialize)]
pub struct CivicData {
    pub mayors: Vec<MayorRecord>,
    pub congress: Vec<RepresentativeRecord>,
    pub scotus: Vec<JusticeRecord>,
}

pub fn compile_data() -> Result<(), Box<dyn Error>> {
    println!("Compiling civic data into single JSON file...");

    let mayors_content = fs::read_to_string("mayors.json")?;
    let mayors: Vec<MayorRecord> = serde_json::from_str(&mayors_content)?;

    let congress_content = fs::read_to_string("congress.json")?;
    let congress: Vec<RepresentativeRecord> = serde_json::from_str(&congress_content)?;

    let scotus_content = fs::read_to_string("scotus.json").unwrap_or_else(|_| "[]".to_string());
    let scotus: Vec<JusticeRecord> = serde_json::from_str(&scotus_content).unwrap_or_else(|_| vec![]);

    let civic_data = CivicData {
        mayors,
        congress,
        scotus,
    };

    let json_output = serde_json::to_string_pretty(&civic_data)?;
    let mut file = File::create("civic_data.json")?;
    file.write_all(json_output.as_bytes())?;

    println!("Saved compiled output to civic_data.json");
    
    Ok(())
}

