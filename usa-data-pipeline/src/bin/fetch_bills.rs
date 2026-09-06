use reqwest::Client;
use roxmltree::Document;
use serde::{Deserialize, Serialize};
use std::env;
use std::error::Error;
use std::fs;

#[derive(Serialize)]
struct BillRecord {
    id: String,
    title: String,
    description: String,
    status: String,
    #[serde(rename = "stateId")]
    state_id: String,
    #[serde(rename = "upcomingDate")]
    upcoming_date: Option<String>,
    #[serde(rename = "sponsorIds")]
    sponsor_ids: Vec<String>,
}

#[derive(Serialize)]
struct VoteRecord {
    #[serde(rename = "billId")]
    bill_id: String,
    #[serde(rename = "lawmakerId")]
    lawmaker_id: String,
    vote: String,
}

#[derive(Serialize)]
struct DonorRecord {
    name: String,
    amount: f64,
}

#[derive(Serialize)]
struct FinanceRecord {
    #[serde(rename = "lawmakerId")]
    lawmaker_id: String,
    #[serde(rename = "totalRaised")]
    total_raised: f64,
    #[serde(rename = "topDonors")]
    top_donors: Vec<DonorRecord>,
}

#[derive(Deserialize)]
struct GovInfoFile {
    link: String,
}

#[derive(Deserialize)]
struct GovInfoResponse {
    files: Vec<GovInfoFile>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Load variables from .env if the file exists
    dotenvy::dotenv().ok();

    println!("Starting bills fetcher...");
    let client = Client::new();
    
    let mut bills = Vec::new();
    
    // 1. Fetch Federal Bills from govinfo.gov
    println!("Fetching federal bill list from govinfo.gov...");
    let list_url = "https://www.govinfo.gov/bulkdata/json/BILLSTATUS/118/s";
    let resp = client.get(list_url).header("Accept", "application/json").send().await?;
    
    if resp.status().is_success() {
        let resp_body: GovInfoResponse = resp.json().await?;
        let files = resp_body.files;
        println!("Found {} federal bills. Fetching top 20 for this build...", files.len());
        
        for file in files.iter().take(20) {
            let xml_resp = client.get(&file.link).send().await?.text().await?;
            if let Ok(doc) = Document::parse(&xml_resp) {
                let mut title = "Unknown Title".to_string();
                let mut status = "Unknown".to_string();
                let mut sponsors = Vec::new();
                let mut id = "US-118-Unknown".to_string();
                
                // Very basic XML extraction
                if let Some(bill_node) = doc.descendants().find(|n| n.has_tag_name("bill")) {
                    if let Some(num_node) = bill_node.children().find(|n| n.has_tag_name("number")) {
                        id = format!("US-118-S{}", num_node.text().unwrap_or(""));
                    }
                    if let Some(latest_action) = bill_node.descendants().find(|n| n.has_tag_name("latestAction")) {
                        if let Some(text_node) = latest_action.children().find(|n| n.has_tag_name("text")) {
                            status = text_node.text().unwrap_or("Unknown").to_string();
                        }
                    }
                    if let Some(sponsors_node) = bill_node.descendants().find(|n| n.has_tag_name("sponsors")) {
                        for item in sponsors_node.children().filter(|n| n.has_tag_name("item")) {
                            if let Some(full_name) = item.children().find(|n| n.has_tag_name("fullName")) {
                                // e.g. "Sen. Crapo, Mike [R-ID]" -> clean up or use raw for demo
                                let name_str = full_name.text().unwrap_or("");
                                // Simple extraction for demo: just grab the name part if possible, or use the bioguide
                                if let Some(first_name) = item.children().find(|n| n.has_tag_name("firstName")) {
                                    if let Some(last_name) = item.children().find(|n| n.has_tag_name("lastName")) {
                                        sponsors.push(format!("{} {}", first_name.text().unwrap_or(""), last_name.text().unwrap_or("")));
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Get title from titles block
                if let Some(titles_node) = doc.descendants().find(|n| n.has_tag_name("titles")) {
                    if let Some(item) = titles_node.children().find(|n| n.has_tag_name("item")) {
                        if let Some(title_node) = item.children().find(|n| n.has_tag_name("title")) {
                            title = title_node.text().unwrap_or("Unknown").to_string();
                        }
                    }
                }
                
                bills.push(BillRecord {
                    id,
                    title,
                    description: "Automatically parsed from govinfo XML.".to_string(),
                    status,
                    state_id: "US".to_string(),
                    upcoming_date: None,
                    sponsor_ids: sponsors,
                });
            }
        }
    } else {
        println!("Failed to fetch from govinfo.gov");
    }

    // 2. Fetch State Bills (Open States)
    let openstates_key = env::var("OPENSTATES_API_KEY").unwrap_or_default();
    if openstates_key.is_empty() {
        println!("No  found. Injecting mock state bills...");
        bills.push(BillRecord {
            id: "TX-88-SB1".to_string(),
            title: "Texas Property Tax Relief Act".to_string(),
            description: "Mock bill injected because API key is missing.".to_string(),
            status: "Passed".to_string(),
            state_id: "TX".to_string(),
            upcoming_date: None,
            sponsor_ids: vec!["Greg Abbott".to_string()],
        });
        bills.push(BillRecord {
            id: "CA-AB-123".to_string(),
            title: "California Clean Energy Act".to_string(),
            description: "Mock bill for California.".to_string(),
            status: "In Committee".to_string(),
            state_id: "CA".to_string(),
            upcoming_date: Some("2024-11-01".to_string()),
            sponsor_ids: vec!["Gavin Newsom".to_string()],
        });
    } else {
        println!("Fetching state bills via OpenStates API...");
        // Real implementation would go here
    }

    // 3. Mock Finance Data (FollowTheMoney)
    let mut finances = Vec::new();
    let ftm_key = env::var("FTM_API_KEY").unwrap_or_default();
    if ftm_key.is_empty() {
        println!("No FTM_API_KEY found. Injecting mock finance data...");
        finances.push(FinanceRecord {
            lawmaker_id: "Maria Cantwell".to_string(),
            total_raised: 4500000.0,
            top_donors: vec![
                DonorRecord { name: "Healthcare PAC".to_string(), amount: 150000.0 },
                DonorRecord { name: "Technology Workers Union".to_string(), amount: 80000.0 },
            ],
        });
        finances.push(FinanceRecord {
            lawmaker_id: "Greg Abbott".to_string(),
            total_raised: 12500000.0,
            top_donors: vec![
                DonorRecord { name: "Energy Sector PAC".to_string(), amount: 450000.0 },
            ],
        });
    }

    // 4. Mock Voting Records
    let mut votes = Vec::new();
    votes.push(VoteRecord {
        bill_id: "US-118-S7".to_string(),
        lawmaker_id: "Maria Cantwell".to_string(),
        vote: "Yea".to_string(),
    });

    // Write to assets/data
    let base_path = "../assets/data";
    
    fs::write(format!("{}/bills.json", base_path), serde_json::to_string_pretty(&bills)?)?;
    fs::write(format!("{}/votes.json", base_path), serde_json::to_string_pretty(&votes)?)?;
    fs::write(format!("{}/finance.json", base_path), serde_json::to_string_pretty(&finances)?)?;
    
    println!("Successfully generated bills.json, votes.json, and finance.json.");
    Ok(())
}
