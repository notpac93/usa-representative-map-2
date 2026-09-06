# Mayor Data Integrity & Validation Plan

## Immediate Fixes
- [x] **Manual Correction (DeSoto)**: Directly update `assets/data/mayors.json` to show the correct mayor (Rachel L. Proctor) immediately.
- [x] **Source Correction**: Update `data/mayors_tx_full.json` with the correct data to prevent future overwrites.
- [x] **Re-merge**: Run `scripts/merge_texas_data.cjs` to verify the build pipeline produces the correct output.

## Systemic Improvements
- [x] **Cross-Reference Audit Tool**: Create a script (`scripts/audit_mayor_data.cjs`) that:
    - Compares names in `assets/data/mayors.json` against the "raw" trusted source (`data/mayors_raw.json`).
    - Flags entries where the name differs but the photo URL is identical (indicating a mismatch).
- [x] **Photo Heuristic Check**: Add logic to verify if the photo URL's filename fuzzily matches the mayor's name (e.g., checking if "Proctor" appears in the URL for "Rachel Proctor").
- [x] **Run Audit**: Execute the audit script and report a list of other potential mismatches across all states.

## Audit Findings (CRITICAL)
The audit detected **109 confirmed mismatches** in Texas data where the app displays an outdated name (from `mayors_tx_full.json`) combined with a correct photo of a different person (from `mayors_raw.json`).
- **Recommendation**: We need to modify the merge script to prioritize names from `mayors_raw.json` when a photo match exists, or bulk-update `mayors_tx_full.json`.

## Bulk Fix Implementation
- [x] **Enhance Merge Script**: Modify `scripts/merge_texas_data.cjs` to:
    - Load `data/mayors_raw.json` (Trusted Source).
    - Map `mayors_raw.json` entries by city.
    - When building the Texas list, check if a city exists in the Trusted Source.
    - If yes, use the Name, Photo, and details from the Trusted Source instead of the outdated Texas file.
- [x] **Execute Merge**: Run the enhanced script to update `assets/data/mayors.json`.
- [x] **Verify**: Re-run the audit script to confirm 0 name mismatches.

## Final Status
All identified data integrity issues, including 109 mismatched mayors in Texas and 1 in Alaska, have been resolved. The merge pipeline is now robust against using outdated Texas mayor names.
