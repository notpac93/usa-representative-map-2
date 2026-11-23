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

Missing officials, changed officeholders, lost contact fields, removed history, a large update, or incomplete election coverage require review. Check mode completes with a report and preserves the data. Required federal-source failures and invalid evidence block saving. Optional state-source failures remain explicit gaps; they cannot create new verified claims or erase previously saved facts. Approval cannot override validation failures.

## 3. Save verified data when ready

Run the workflow again with mode **save**. Saving performs a fresh government check, preserves recovery history, and writes to the separate `codex/federal-snapshots` archive branch. If flagged changes were reviewed, supply the exact **data version** from the report as **approve_version**. If the meaningful data has changed since review, saving stops again.

Only the validated officials dataset, state coverage reports, manifests, and government evidence are saved. The app source branch and installed apps are not updated by this action. The next check compares against the latest saved archive automatically. Certification and incoming recognition are separate facts; saving a partially covered dataset does not certify its missing contests.

## 4. Release to the app separately

Saving is not an app release. Keep the app's hosted snapshot setting unset while using the current slower release process. When you decide to release, select a saved snapshot for a normal app update, or later establish a separately managed hosted release endpoint. This workflow does not build, deploy, or release the app.

## Coverage and limits

The initial baseline covers 560 occupied federal offices and roles: 439 House members/delegates, 100 senators, president, vice president, nine Supreme Court justices, and ten congressional leadership roles. Collection uses official House, Senate, White House, Supreme Court, and National Archives sources. Empty contact fields remain empty when the sources do not provide them.

The election intake registers all 50 state authorities and reports source, contest, certification, and start-date coverage separately. Dedicated imports currently cover Mississippi county returns, Wyoming certified results, and Delaware official results. Government Senate recognition and a partial House list supply additional incoming records without implying certification. Every state also has a pinned, reviewed import path; unconfigured contests remain gaps. See [the election intake runbook](ELECTION_INTAKE.md) for supported records, review requirements, and limitations.

Portrait refresh, Cabinet collection, lower federal court collection, and local elections remain outside this collector. Incoming records do not inherit a predecessor's photo or contact details. The saved government documents make each verification auditable; a government website can still publish late or require a source-specific correction.

Check artifacts are downloadable for 90 days. Saved releases, recovery copies, and compressed evidence are retained on the archive branch. Detailed local commands and recovery instructions are in [the federal data runbook](FEDERAL_OFFICIALS.md).

## Deployment verification

On November 19, 2026 (Pacific time), the [government check](https://github.com/notpac93/usa-representative-map-2/actions/runs/44667039065), [reviewed archive save](https://github.com/notpac93/usa-representative-map-2/actions/runs/44667351086), and [check against the saved archive](https://github.com/notpac93/usa-representative-map-2/actions/runs/44667643100) all succeeded. The saved version added 144 incoming records and retained 560 serving federal records. The follow-up check found zero meaningful record changes. It still reported incomplete election coverage, as intended.

Archive commit `d369540f0598487155898d39f26417d8907aecdc` retains the reviewed snapshot, previous version, reports, 155 passed government responses, and the exact 18 collection-rule/configuration files. Their preserved hashes were independently verified. This validation did not replace the app's bundled officials snapshot or release an app update.

## Local app data selection — November 20, 2026

The local app now bundles the reviewed officials snapshot from archive commit `d369540f0598487155898d39f26417d8907aecdc`, data version `dedf2ce280ec3a87a13b079cad983f034535be5d150b6284c65fdc2c00561b22`. This adds the 144 incoming records to the bundled data while retaining the 560 serving records and explicit election coverage gaps. The imported snapshot passed schema and data-version validation, and the iPhone build's bundled asset matched it byte for byte. This is a selected saved snapshot, not a new government collection or a claim of complete election coverage. Checks remain manual and the hosted snapshot setting remains unset.

Publisher and election integration tests use `scripts/tests/fixtures/federal_baseline.json.gz`, a fixed copy of the pre-import baseline, so app data selections do not change their test conditions.
