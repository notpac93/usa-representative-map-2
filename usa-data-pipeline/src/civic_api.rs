use serde::{Deserialize, Serialize};
use std::env;
use std::error::Error;
use reqwest::Client;

#[derive(Debug, Serialize, Deserialize)]
pub struct CivicApiElection {
    pub id: String,
    pub name: String,
    #[serde(rename = "electionDay")]
    pub election_day: String,
    #[serde(rename = "ocdDivisionId")]
    pub ocd_division_id: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CivicElectionsResponse {
    pub kind: String,
    pub elections: Vec<CivicApiElection>,
}

pub struct CivicApiClient {
    client: Client,
    api_key: String,
    pub base_url: String,
}

impl CivicApiClient {
    pub fn new() -> Result<Self, Box<dyn Error>> {
        let api_key = env::var("GOOGLE_CIVIC_API_KEY").unwrap_or_else(|_| "DEMO_KEY".to_string());
        Ok(Self {
            client: Client::new(),
            api_key,
            base_url: "https://www.googleapis.com".to_string(),
        })
    }

    /// Fetches all upcoming elections from the Google Civic Information API
    pub async fn fetch_elections(&self) -> Result<CivicElectionsResponse, Box<dyn Error>> {
        let url = format!(
            "{}/civicinfo/v2/elections?key={}",
            self.base_url,
            self.api_key
        );
        let resp = self.client.get(&url).send().await?;
        if resp.status().is_success() {
            let data: CivicElectionsResponse = resp.json().await?;
            Ok(data)
        } else {
            let error_text = resp.text().await?;
            Err(format!("Google Civic API Error: {}", error_text).into())
        }
    }

    /// Periodically called by the cron job to update internal caches/files
    pub async fn sync_data(&self) -> Result<(), Box<dyn Error>> {
        println!("Running scheduled sync with Google Civic API...");
        match self.fetch_elections().await {
            Ok(elections_resp) => {
                println!("Successfully fetched {} elections.", elections_resp.elections.len());
                let json = serde_json::to_string_pretty(&elections_resp)?;
                std::fs::write("elections_cache.json", json)?;
                Ok(())
            },
            Err(e) => {
                eprintln!("Failed to sync elections: {}", e);
                Err(e)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use wiremock::matchers::{method, path};
    use wiremock::{Mock, MockServer, ResponseTemplate};
    use std::fs;

    #[tokio::test]
    async fn test_civic_api_sync() {
        let mock_server = MockServer::start().await;

        let mock_response = CivicElectionsResponse {
            kind: "civicinfo#electionsQueryResponse".to_string(),
            elections: vec![
                CivicApiElection {
                    id: "2000".to_string(),
                    name: "VIP Test Election".to_string(),
                    election_day: "2024-11-05".to_string(),
                    ocd_division_id: "ocd-division/country:us".to_string(),
                },
            ],
        };

        Mock::given(method("GET"))
            .and(path("/civicinfo/v2/elections"))
            .respond_with(ResponseTemplate::new(200).set_body_json(&mock_response))
            .mount(&mock_server)
            .await;

        let mut client = CivicApiClient::new().expect("Failed to init client");
        client.base_url = mock_server.uri();

        let result = client.sync_data().await;
        assert!(result.is_ok(), "Sync function failed");

        let file_content = fs::read_to_string("elections_cache.json").expect("Failed to read cache file");
        assert!(file_content.contains("VIP Test Election"));

        let _ = fs::remove_file("elections_cache.json");
    }
}
