use axum::{
    routing::{get, post},
    Router,
};
use tower_http::cors::{Any, CorsLayer};
use tower_http::services::ServeDir;
use std::net::SocketAddr;
use std::error::Error;
use std::sync::Arc;
use tokio_cron_scheduler::{Job, JobScheduler};

mod congress;
mod compile;
mod geo_utils;
mod spatial_api;
mod civic_api;

use spatial_api::{AppState, load_overlay, intersect_districts};
use civic_api::CivicApiClient;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    println!("Starting Rust Backend Server on http://127.0.0.1:8080");

    // Initialize Google Civic API Client
    let civic_client = Arc::new(CivicApiClient::new()?);
    let civic_client_clone = civic_client.clone();

    // Setup Cron Scheduler
    let mut sched = JobScheduler::new().await?;
    
    // Run weekly at 2 AM on Sunday (Cron: "0 0 2 * * Sun *")
    let job = Job::new_async("0 0 2 * * Sun *", move |_uuid, _l| {
        let client = civic_client_clone.clone();
        Box::pin(async move {
            let _ = client.sync_data().await;
        })
    })?;
    sched.add(job).await?;
    sched.start().await?;

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let cd116_features = load_overlay("../assets/data/overlays/cd116.json").await;
    let judicial_features = load_overlay("../assets/data/overlays/judicial.json").await;
    let state = Arc::new(AppState { cd116_features, judicial_features });

    let app = Router::new()
        .route("/api/ping", get(|| async { "pong" }))
        .route("/api/intersect_districts", post(intersect_districts))
        // Serve the Flutter web build
        .fallback_service(ServeDir::new("../build_smoke_admin/web"))
        .layer(cors)
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("127.0.0.1:8080").await?;
    axum::serve(listener, app).await?;
    
    Ok(())
}
