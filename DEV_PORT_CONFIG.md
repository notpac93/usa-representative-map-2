# Development Port Configuration

This document defines the standard port configuration for the `usa-representative-map` project to ensure consistency and avoid stale builds.

## Primary Port: 8080

All Flutter Web development and testing should be performed on port **8080**.

### Usage
To start the application:
```bash
flutter run -d web-server --web-port=8080 --web-hostname=localhost
```

### Rationale
Consolidating to a single port prevents confusion when multiple instances are running and ensures that browser sessions and caches are consistently updated with the latest code changes.

### Redundant Ports
- Port **8081** (Legacy/Temporary): Should not be used.
- Port **5173/5174** (Vite): Used for internal tooling/scrapers if applicable, but not for the primary app UI.
