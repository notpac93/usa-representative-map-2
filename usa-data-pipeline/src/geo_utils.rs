use geo::{Polygon, LineString, Coordinate};

pub fn parse_svg_path(path_str: &str) -> Option<Polygon<f64>> {
    let mut coords = Vec::new();
    
    // Simple tokenizer for paths like "M10,20L30,40Z" or "M 10 20 L 30 40 Z"
    // Since our data looks exactly like "M607.039,228.751L607.299,231.266...Z"
    
    let mut current_num_str = String::new();
    let mut current_x: Option<f64> = None;
    
    let bytes = path_str.as_bytes();
    let mut i = 0;
    
    while i < bytes.len() {
        let b = bytes[i];
        
        if b == b'M' || b == b'L' || b == b'Z' || b == b'z' || b == b' ' {
            if !current_num_str.is_empty() {
                if let Ok(num) = current_num_str.parse::<f64>() {
                    if let Some(x) = current_x {
                        coords.push(Coordinate { x, y: num });
                        current_x = None;
                    } else {
                        current_x = Some(num);
                    }
                }
                current_num_str.clear();
            }
            if b == b'Z' || b == b'z' {
                break;
            }
        } else if b == b',' {
            if let Ok(num) = current_num_str.parse::<f64>() {
                current_x = Some(num);
            }
            current_num_str.clear();
        } else if b.is_ascii_digit() || b == b'.' || b == b'-' {
            current_num_str.push(b as char);
        } else {
            // It might be a space separating M x y or L x y instead of comma
            if !current_num_str.is_empty() {
                if let Ok(num) = current_num_str.parse::<f64>() {
                    if let Some(x) = current_x {
                        coords.push(Coordinate { x, y: num });
                        current_x = None;
                    } else {
                        current_x = Some(num);
                    }
                }
                current_num_str.clear();
            }
        }
        i += 1;
    }
    
    // Push the last y if there was no trailing character before Z
    if !current_num_str.is_empty() {
        if let Ok(num) = current_num_str.parse::<f64>() {
            if let Some(x) = current_x {
                coords.push(Coordinate { x, y: num });
            }
        }
    }
    
    if coords.len() < 3 {
        return None;
    }
    
    Some(Polygon::new(LineString(coords), vec![]))
}
