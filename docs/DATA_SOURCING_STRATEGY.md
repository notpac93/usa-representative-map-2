# Mayor Data Sourcing Strategy

## Overview

To provide comprehensive coverage of local leadership (mayors) for every incorporated municipality in the US, we cannot rely on generic national lists (like the US Conference of Mayors) as they typically only cover large cities (pop > 30k).

Instead, we use a **"Hub and Spoke" official sourcing strategy**. State-level "Municipal Leagues" or "Leagues of Cities" are the authoritative sources for this data, often maintaining complete, up-to-date directories of all member cities and their elected officials.

## The Strategy

1.  **Source Identification (The Hub)**:
    *   Start at [USA.gov Local Governments](https://www.usa.gov/local-governments).
    *   Select a state. The redirection target is usually the official state directory or the Municipal League.
    *   Example: Choosing "Texas" redirects to the *Texas Municipal League (TML)*.

2.  **State-Specific Scrapers (The Spokes)**:
    *   We build a custom scraper for each state's directory.
    *   While layouts differ, the goal is always to extracting pairs of `(City Name, Mayor Name)`.
    *   **Normalization is Critical**: City names in these directories often include prefixes/suffixes (e.g., "City of Austin", "Town of Abbott"). Our scripts normalizes these to `CityName, StateCode` (e.g., "Austin, TX") to match our mapping data.

## Implementation: Texas (Completed)

*   **Source**: Texas Municipal League ([directory.tml.org](https://directory.tml.org/))
*   **Technique**:
    *   The TML directory allows searching by official title ("Mayor").
    *   We use a Playwright script (`scripts/scrape_texas_mayors.cjs`) to load the results page.
    *   Since the mobile/responsive layout flattens tables, the script scrapes all links in sequence, pairing every "City Profile" link with the subsequent "Individual Profile" link to associate the correct Mayor with the correct City.
*   **Result**: 1,203 mayors scraped (vs ~114 previously).

## Implementation: Alabama (In Progress)

*   **Source**: Alabama League of Municipalities (ALM).
*   **Target URL**: `https://alm.imiscloud.com/ALALM/ALALM/About/ALM-Municipal-Directory.aspx` (or similar).
*   **Plan**:
    *   Investigate the ALM directory structure.
    *   Build a scraper to iterate through cities or officials.
    *   Normalize and merge into `assets/data/mayors.json`.

## How to Add a New State

1.  **Find the Source**: Use Google or USA.gov to find the "[State Name] League of Municipalities" or "Municipal League".
2.  **Inspect the Directory**:
    *   Look for a "Directory", "Roster", or "Member Search".
    *   Check if it lists officials directly or just cities.
3.  **Write the Scraper**:
    *   Create `scripts/scrape_[state]_mayors.cjs`.
    *   Use Playwright to handle dynamic JS content.
    *   Output raw JSON to `data/mayors_[state]_full.json`.
4.  **Merge Data**:
    *   Use `scripts/merge_state_data.cjs` (to be generalized) to merge the new raw data into `assets/data/mayors.json`.
    *   **Rule**: Always search for existing entries first to preserve high-quality metadata (photos, phone numbers) before overwriting with the basic name/city pair.

## Directory Structure

*   `scripts/`: Contains the state-specific scraping scripts.
*   `data/`: Intermediate raw JSON files (e.g., `mayors_tx_full.json`).
*   `assets/data/mayors.json`: The production database loaded by the app.
