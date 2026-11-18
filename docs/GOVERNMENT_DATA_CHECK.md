# Run a government data check

Open [Government data check in GitHub Actions](https://github.com/notpac93/usa-representative-map-2/actions/workflows/federal-officials.yml). There is no recurring schedule.

## 1. Download and check

1. Choose **Run workflow**.
2. Leave the branch set to **main** and the mode set to **check**.
3. Leave **approve_version** blank and choose **Run workflow**.
4. Open the run when it finishes. The Summary lists the government downloads, data differences, and anything requiring review.
5. Download the `federal-data-check-...` artifact for `report.md`, machine-readable `report.json`, the candidate dataset, its verification manifest, and compressed copies of the actual government responses.

Check mode does not change either the saved data archive or an installed app. Source-page formatting, retrieval times, and source hashes alone do not count as changes to officials' data.

## 2. Review differences

The report lists additions, removals, and changed fields with old/new values. A successful check may report zero meaningful changes; that confirms the collector ran without inventing a new data version.

Missing officials, changed officeholders, lost contact fields, removed history, or a large update require review. That run stops with the data preserved; inspect the report rather than treating it as permission to save. A failed download, changed source layout, or invalid evidence also stops the run. Approval cannot override those validation failures.

## 3. Save verified data when ready

Run the workflow again with mode **save**. Saving performs a fresh government check, preserves recovery history, and writes to the separate `codex/federal-snapshots` archive branch. If flagged changes were reviewed, supply the exact **data version** from the report as **approve_version**. If the meaningful data has changed since review, saving stops again.

Only the validated federal dataset, reports, manifests, and government evidence are saved. The app source branch and installed apps are not updated by this action. The next check compares against the latest saved archive automatically.

## 4. Release to the app separately

Saving is not an app release. Keep the app's hosted snapshot setting unset while using the current slower release process. When you decide to release, select a saved snapshot for a normal app update, or later establish a separately managed hosted release endpoint. This workflow does not build, deploy, or release the app.

## Coverage and limits

The initial baseline covers 560 occupied federal offices and roles: 439 House members/delegates, 100 senators, president, vice president, nine Supreme Court justices, and ten congressional leadership roles. Collection uses official House, Senate, White House, Supreme Court, and National Archives sources. Empty contact fields remain empty when the sources do not provide them.

Portrait refresh, incoming election certification adapters, Cabinet collection, lower federal court collection, and state/local officials are separate work. Government results must be certified before an incoming official is labeled certified. The saved government documents make each verification auditable; a government website can still publish late or require a source-specific correction.

Check artifacts are downloadable for 90 days. Saved releases, recovery copies, and compressed evidence are retained on the archive branch. Detailed local commands and recovery instructions are in [the federal data runbook](FEDERAL_OFFICIALS.md).
