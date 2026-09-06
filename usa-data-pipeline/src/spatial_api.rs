use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use geo::{Polygon, BoundingRect};
use geo::algorithm::intersects::Intersects;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::fs;

use crate::geo_utils::parse_svg_path;

#[derive(Deserialize)]
pub struct IntersectRequest {
    pub path: String,
    pub bbox: [f64; 4],
}

#[derive(Serialize)]
pub struct IntersectResponse {
    pub intersecting_ids: Vec<String>,
    pub intersecting_judicial_names: Vec<String>,
}

// Overlay JSON structures
#[derive(Deserialize, Clone)]
pub struct OverlayJson {
    pub features: Vec<OverlayFeature>,
}

#[derive(Deserialize, Clone)]
pub struct OverlayFeature {
    pub id: String,
    pub name: Option<String>,
    pub path: String,
    pub bbox: [f64; 4],
}

pub struct AppState {
    pub cd116_features: Vec<(OverlayFeature, Polygon<f64>)>,
    pub judicial_features: Vec<(OverlayFeature, Polygon<f64>)>,
}

pub async fn load_overlay(path: &str) -> Vec<(OverlayFeature, Polygon<f64>)> {
    let mut result = Vec::new();
    let data = match fs::read_to_string(path).await {
        Ok(d) => d,
        Err(e) => {
            println!("Failed to read {}: {}", path, e);
            return result;
        }
    };
    
    match serde_json::from_str::<OverlayJson>(&data) {
        Ok(overlay) => {
            println!("Parsed {} features from {}", overlay.features.len(), path);
            for f in overlay.features {
                if let Some(poly) = parse_svg_path(&f.path) {
                    result.push((f, poly));
                } else {
                    println!("Failed to parse SVG path for feature id {}", f.id);
                }
            }
        },
        Err(e) => {
            println!("Error parsing {}: {}", path, e);
        }
    }
    
    println!("Loaded {} features from {}", result.len(), path);
    result
}

pub async fn intersect_districts(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<IntersectRequest>,
) -> impl IntoResponse {
    let req_poly = match parse_svg_path(&payload.path) {
        Some(p) => p,
        None => return (StatusCode::BAD_REQUEST, "Invalid path").into_response(),
    };
    
    let req_min_x = payload.bbox[0];
    let req_min_y = payload.bbox[1];
    let req_max_x = payload.bbox[2];
    let req_max_y = payload.bbox[3];

    let mut intersecting_ids = Vec::new();
    let mut intersecting_judicial_names = Vec::new();

    for (feat, dist_poly) in &state.cd116_features {
        // Fast BBox check first
        let f_min_x = feat.bbox[0];
        let f_min_y = feat.bbox[1];
        let f_max_x = feat.bbox[2];
        let f_max_y = feat.bbox[3];
        
        if req_max_x < f_min_x || req_min_x > f_max_x || req_max_y < f_min_y || req_min_y > f_max_y {
            continue;
        }
        
        // Detailed polygon intersection
        if req_poly.intersects(dist_poly) {
            intersecting_ids.push(feat.id.clone());
        }
    }
    
    for (feat, dist_poly) in &state.judicial_features {
        let f_min_x = feat.bbox[0];
        let f_min_y = feat.bbox[1];
        let f_max_x = feat.bbox[2];
        let f_max_y = feat.bbox[3];
        
        if req_max_x < f_min_x || req_min_x > f_max_x || req_max_y < f_min_y || req_min_y > f_max_y {
            continue;
        }
        
        if req_poly.intersects(dist_poly) {
            if let Some(name) = &feat.name {
                intersecting_judicial_names.push(name.clone());
            }
        }
    }

    Json(IntersectResponse { intersecting_ids, intersecting_judicial_names }).into_response()
}

