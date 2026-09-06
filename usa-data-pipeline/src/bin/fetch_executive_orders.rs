use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::error::Error;
use std::fs;
use std::path::Path;

#[derive(Deserialize, Debug)]
struct FrPresident {
    identifier: Option<String>,
    name: Option<String>,
}

#[derive(Deserialize, Debug)]
struct FrDocument {
    title: Option<String>,
    executive_order_number: Option<String>,
    signing_date: Option<String>,
    publication_date: Option<String>,
    html_url: Option<String>,
    pdf_url: Option<String>,
    citation: Option<String>,
    #[serde(rename = "abstract")]
    abstract_text: Option<String>,
    president: Option<FrPresident>,
    disposition_notes: Option<String>,
}

#[derive(Deserialize, Debug)]
struct FrApiResponse {
    count: usize,
    results: Vec<FrDocument>,
    next_page_url: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ExecutiveOrderRecord {
    pub id: String,
    #[serde(rename = "orderNumber")]
    pub order_number: String,
    pub title: String,
    #[serde(rename = "signingDate")]
    pub signing_date: String,
    #[serde(rename = "publicationDate")]
    pub publication_date: String,
    pub president: String,
    #[serde(rename = "presidentId")]
    pub president_id: String,
    pub citation: String,
    pub url: String,
    #[serde(rename = "pdfUrl")]
    pub pdf_url: String,
    pub summary: Option<String>,
    #[serde(rename = "dispositionNotes")]
    pub disposition_notes: Option<String>,
    pub status: String,
    #[serde(rename = "statusDetails")]
    pub status_details: Option<String>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    dotenvy::dotenv().ok();

    println!("==================================================");
    println!(" Official U.S. Executive Orders Data Fetcher");
    println!(" Sourcing across Presidential Administrations");
    println!(" Source: Office of the Federal Register & GPO GovInfo");
    println!("==================================================");

    let client = Client::builder()
        .user_agent("USA-Representative-Map/1.0 (Direct Gov Integration)")
        .build()?;

    let target_presidents = vec![
        ("donald-trump", "Donald Trump"),
        ("joe-biden", "Joe Biden"),
        ("barack-obama", "Barack Obama"),
        ("george-w-bush", "George W. Bush"),
        ("william-j-clinton", "William J. Clinton"),
    ];

    let mut all_orders: Vec<ExecutiveOrderRecord> = Vec::new();
    let mut seen_ids: HashSet<String> = HashSet::new();

    for (target_id, target_name) in target_presidents {
        println!("\n>>> Fetching executive orders for President {} ({})", target_name, target_id);
        let mut current_page = 1;
        let max_pages_per_pres = 4; // Up to 400 orders per president
        let mut next_url = Some(format!(
            "https://www.federalregister.gov/api/v1/documents.json?conditions[type][]=PRESDOCU&conditions[presidential_document_type][]=executive_order&conditions[president]={}&per_page=100&fields[]=title&fields[]=executive_order_number&fields[]=signing_date&fields[]=publication_date&fields[]=html_url&fields[]=pdf_url&fields[]=president&fields[]=abstract&fields[]=citation&fields[]=disposition_notes&page=1",
            target_id
        ));

        let mut pres_order_count = 0;

        while let Some(url) = next_url {
            if current_page > max_pages_per_pres {
                break;
            }

            println!("  Fetching page {} for {}...", current_page, target_name);
            let resp = client.get(&url).send().await?;

            if !resp.status().is_success() {
                eprintln!("  Warning: HTTP {} for {}", resp.status(), target_name);
                break;
            }

            let api_data: FrApiResponse = resp.json().await?;
            if api_data.results.is_empty() {
                break;
            }

            println!("  Received {} items on page {} (Total in Federal Register: {})",
                api_data.results.len(),
                current_page,
                api_data.count
            );

            for doc in api_data.results {
                let order_num = doc.executive_order_number.unwrap_or_else(|| "Unknown".to_string());
                let title = doc.title.unwrap_or_else(|| "Untitled Executive Order".to_string());
                let signing_date = doc.signing_date.unwrap_or_else(|| "".to_string());
                let pub_date = doc.publication_date.unwrap_or_else(|| "".to_string());
                let citation = doc.citation.unwrap_or_default();
                let html_url = doc.html_url.unwrap_or_default();
                let pdf_url = doc.pdf_url.unwrap_or_default();

                let (pres_name, pres_id) = match doc.president {
                    Some(p) => (
                        p.name.unwrap_or_else(|| target_name.to_string()),
                        p.identifier.unwrap_or_else(|| target_id.to_string())
                    ),
                    None => (target_name.to_string(), target_id.to_string()),
                };

                let id = if order_num != "Unknown" {
                    format!("EO-{}", order_num)
                } else if !signing_date.is_empty() {
                    format!("EO-{}-{}", pres_id, signing_date.replace('-', ""))
                } else {
                    format!("EO-{}-{}", pres_id, pub_date.replace('-', ""))
                };

                if seen_ids.contains(&id) {
                    continue;
                }
                seen_ids.insert(id.clone());

                let summary = doc.abstract_text.or_else(|| {
                    let citation_part = if !citation.is_empty() {
                        format!(" under Federal Register citation {}", citation)
                    } else {
                        "".to_string()
                    };
                    let date_part = if !signing_date.is_empty() {
                        format!(" on {}", signing_date)
                    } else {
                        "".to_string()
                    };
                    Some(format!(
                        "Executive Order {} directs federal departments and agencies regarding \"{}\". Promulgated by President {}{}{} pursuant to presidential authority under Article II of the United States Constitution.",
                        order_num,
                        title,
                        pres_name,
                        date_part,
                        citation_part
                    ))
                });

                let disp_notes = doc.disposition_notes;
                let (status, status_details) = match &disp_notes {
                    Some(notes) if notes.to_lowercase().contains("revoked by") => {
                        ("Revoked".to_string(), Some("Officially revoked by subsequent presidential order.".to_string()))
                    },
                    Some(notes) if notes.to_lowercase().contains("superseded by") => {
                        ("Superseded".to_string(), Some("Superseded by subsequent presidential order.".to_string()))
                    },
                    Some(notes) if notes.to_lowercase().contains("amended by") => {
                        ("Amended".to_string(), Some("Amended by subsequent executive action.".to_string()))
                    },
                    _ => (
                        "In Effect".to_string(),
                        Some("Active force of law across federal agencies. Promulgated in the Federal Register and not revoked or superseded.".to_string())
                    ),
                };

                all_orders.push(ExecutiveOrderRecord {
                    id,
                    order_number: order_num,
                    title,
                    signing_date,
                    publication_date: pub_date,
                    president: pres_name,
                    president_id: pres_id,
                    citation,
                    url: html_url,
                    pdf_url,
                    summary,
                    disposition_notes: disp_notes,
                    status,
                    status_details,
                });

                pres_order_count += 1;
            }

            next_url = api_data.next_page_url;
            current_page += 1;
        }

        println!("  ✓ Loaded {} executive orders for President {}", pres_order_count, target_name);
    }

    // Sort all orders by signing date (most recent first)
    all_orders.sort_by(|a, b| b.signing_date.cmp(&a.signing_date));

    println!("\n==================================================");
    println!(" Successfully fetched and processed {} total executive orders across all administrations.", all_orders.len());
    println!("==================================================");

    // Determine target file path (handles executing from workspace root or usa-data-pipeline directory)
    let target_dir = if Path::new("assets/data").exists() {
        "assets/data"
    } else if Path::new("../assets/data").exists() {
        "../assets/data"
    } else {
        "assets/data"
    };

    let target_path = format!("{}/executive_orders.json", target_dir);
    let json_output = serde_json::to_string_pretty(&all_orders)?;
    fs::write(&target_path, json_output)?;

    println!("Written official executive orders to: {}", target_path);
    println!("Automation execution complete.");
    Ok(())
}
