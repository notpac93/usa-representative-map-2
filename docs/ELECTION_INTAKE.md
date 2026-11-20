# Election evidence intake and release controls

The manual government data check now has an intake path for all 50 states. That means every state has a registered election authority and a coverage row, not that every winner, certification, start date, or serving state official has been collected. The active election intake is scoped to **November 3, 2026**. Local elections are outside its national coverage claim.

Government recognition, certified election results, a scheduled term start, and confirmed service are separate facts. The pipeline preserves those distinctions through collection, review, saving, and display. Checking or saving data does not release an update to the app.

## What is connected

| Input | Implemented behavior | Remaining limit |
| --- | --- | --- |
| All 50 states | USA.gov-discovered authorities, scoped government hosts and linked delegated results sources; directory and export checks with per-state reporting. | A reachable directory or downloaded file does not prove parsed contests, certification, or a complete ballot inventory. |
| Mississippi | Government recognition of Scott Colom; official election calendar; an 82-county document inventory and conservative county-total checks. | Statewide certification is not verified. County PDFs, incomplete aggregation, and recognition do not become a certified winner. |
| Wyoming | Exact government workbooks, signed state canvass certificate dated November 10, 2026, and office-specific start rules. The adapter parses 86 candidate contests. | Local offices and judicial retention are excluded. One special state Senate start remains unverified; this is not complete state ballot coverage. |
| Delaware | Reconciles the government election-reporting JSON against the government's open-data publication, including candidate coverage and vote components. | An `OFFICIAL RESULTS` label is retained as publication status. Independent certification and the separate write-in report are not fully verified, so reported leaders do not become certified incoming terms. |
| Senate recognition | The government's senators-elect directory supplied 19 recognized incoming people in the reviewed November 2026 edition. | This is a partial recognition source, not the complete election result set or proof of certification. Ohio's special Senate election does not inherit the regular January start rule. |
| House recognition | The November 11 government caucus release explicitly names 40 new members-elect across 26 states. | This covers that caucus list only, excludes reelected members, and supplies no certification, serving status, contacts, or portraits. |
| Reviewed state packages | A configured, evidence-bound import path accepts explicitly reviewed contests from any of the 50 states. | `scripts/data/election_result_reviews.json` currently contains no packages. Supporting an import format is not evidence that a state's results have been imported. |

Wyoming has **85 verified scheduled starts** after applying the national rule to its two regular federal contests: two federal starts at January 3, 2027, noon in Washington, and **83 state civil start dates of January 4, 2027, America/Denver**. The state law supplies a day, not an exact clock time. Senate District 6 is a special election and remains pending office-specific start verification. Certification and these scheduled starts do not confirm anyone has assumed office.

Use the latest run's `report.json` and `state-reports.json` for current counts. Reachability changes, governments revise publications, and an adapter can fail closed on a changed edition. Current implementation has three state adapters and independently verified certified contests from Wyoming; **no state has complete reviewed national-intake coverage**. Do not turn the number of registered or fetched states into a claim that all 50 states' winners are complete.

## Run, review, save, release

In [GitHub Actions](https://github.com/notpac93/usa-representative-map-2/actions/workflows/federal-officials.yml), choose **Run workflow**, use the intended source branch, and select **check**. There is no recurring schedule. A check downloads available government sources, validates the supported inputs, compares against the latest saved archive, and retains an artifact without changing the archive or installed apps.

Review these outputs in `tmp/federal-checks/<run>/`:

- `report.md`: readable government download status, changes, and review reasons.
- `report.json`: old/new record differences and per-state `electionCoverage`.
- `state-reports.json`: adapter evidence, parsed contests, county coverage, start rules, and unresolved issues.
- `candidate.json` and `manifest.json`: the proposed snapshot and its integrity/configuration bindings.
- `configuration/`: the exact collection code, source rules, and review packages used by this check, retained with a saved release and checked for integrity.
- `sources/*.source.gz`: the exact downloaded response bytes, addressed by SHA-256. An archived challenge page is diagnostic evidence, not an election result.

Review directory retrieval, export download, contest parsing, certification, verified start dates, and ballot completeness separately. A successful check can still require review because election coverage is incomplete. Optional state-source failures appear as gaps; they do not authorize replacing a serving official with an unverified result. Required federal source or snapshot-integrity failures block the candidate.

When ready, run **save** with the exact reviewed `dataVersion` as `approve_version` when the report requires approval. Save performs a fresh check. Changed meaningful data requires another review. An approved partial save acknowledges the reported gaps; it does not certify missing contests or bypass invalid evidence. The saved snapshot and recovery evidence go to `codex/federal-snapshots`, separately from the app source branch.

Release to users is another decision. Keep `FEDERAL_SNAPSHOT_URL` unset for the current release process. Select a specific saved snapshot for a normal app release, or establish a separately controlled hosted data release later. This workflow does not build, install, deploy, or release the app. See [the operator guide](GOVERNMENT_DATA_CHECK.md) for the GitHub steps and [the federal runbook](FEDERAL_OFFICIALS.md) for local commands and recovery.

## Sources and blocked downloads

`scripts/data/state_election_sources.json` records authority discovery, current result URLs, exact allowed hosts, explicitly linked exports, and access limitations. `scripts/data/federal_sources.json` and its bundled mirror, `assets/data/federal_sources.json`, provide the runtime evidence-authority rules. Keep the two runtime registries identical when registering or changing sources.

Some governments provide CSV, JSON, or workbook files; others require a public export form or publish signed scanned PDFs. A registered export form is not a downloaded data file. The generic check reports forms as requiring manual export selection. Dedicated adapters download and parse only the formats they explicitly support.

HTTP success is insufficient: security challenges returned with HTTP 200 are rejected. Some state or delegated services return HTTP 403 or require robot verification. Nevada's public results site explicitly restricts automated traffic, so the collector skips its automated directory request. Do not bypass a security challenge or count it as usable data. Use an authorized, government-published export on an approved endpoint, or keep the state visibly unresolved. A file manually viewed in a browser is not automatically imported; a reviewed package still requires the collector to retrieve and verify the same approved government document bytes.

## Add a reviewed government result package

The implementation is `scripts/election_adapters/reviewed.py`; `scripts/tests/test_reviewed_elections.py` contains **synthetic contract examples**, not real officials or government claims. Add real packages only after reviewing the actual evidence.

1. Identify the exact state, election date, office, district, and election type. Obtain final government results, separate statewide certification evidence, and the applicable office-specific start rule. Register any new host or delegated endpoint before importing it. The current orchestrator accepts one package per state for November 3, 2026; another election needs separately reviewed cycle support.
2. Add a package to the `packages` array in `scripts/data/election_result_reviews.json`, with `schemaVersion: 1`, `state`, `electionDate`, an identified `review.reviewer`, a nonfuture offset-aware `reviewedAt`, `documents`, `certification`, and distinct `contests`. Every document has an ID, approved HTTPS URL, exact SHA-256, `role` (`results`, `certification`, or `startRule`), and supported `format` (`json`, `csv`, or `pdf`). Generic XLSX/XML imports are not implemented; use a dedicated adapter or a supported government publication.
3. Bind every result to the source's actual fields. JSON uses explicit pointers; CSV uses explicit column names and distinct winner flag values. The source must bind state, date, office, district where applicable, election type, single-seat scope, final outcome, complete candidate identities, totals, and winner flags. The normalized winner must exactly match the bound result. A hash alone cannot establish these facts. A raw first-choice ranked-choice tally is not a final result.
4. Bind the separate state certification to exactly the package's contest IDs and result-document hashes. JSON certification must explicitly supply the bound certification facts and revision scope. For a signed scanned certificate, an identified human reviewer must record `reviewerType: human`, `method: visually_reviewed_government_document`, the actual PDF pages, a factual statement, and `signedDocumentReviewed: true`. Scanned result transcriptions likewise require explicit human review of the complete candidate table and final outcome. PDF page references are checked with `pdfinfo`; unattended OCR is not treated as proof. A certification civil day must have completed before it is accepted.
5. Supply a start rule for each office whose start is verified. It must bind that jurisdiction, office kind/title, district, and source document. A day-only rule uses `scheduledStartDate`, `datePrecision: day`, and an explicitly reviewed IANA time zone. An exact `scheduledStart` additionally requires an explicit government clock time and time zone, a matching offset, and the adapter's explicit-time review fields. Missing rules remain a start-date gap; civil dates never become invented UTC midnight or `actualStart`.
6. Run a check and inspect the candidate and per-state report before approving a save. Changed document bytes, missing fields, a different edition, mismatched candidates/totals, wrong state/seat, uncompleted certification dates, or invalid rules stop that import. Ties, pending runoffs, multiple-seat outcomes, unresolved write-ins, and retention ballot choices require dedicated handling; the generic adapter rejects them.

Reviewed packages intentionally report `completeStateCoverage: false`. They cover their explicit contest set; they do not establish a complete statewide ballot inventory. Certification without a verified start can be retained as recognized incoming with a certification flag, while the start remains pending. No package asserts actual service or overrides a current term merely because a date arrived.

States with a dedicated adapter must be extended through that adapter or undergo an explicitly reviewed migration. A generic partial package cannot replace a native state report and silently drop its other contests or county evidence.

## Display and verification boundaries

The serving official remains the primary profile with the only portrait. Incoming people appear in a smaller text-only card, with recognition and certification labeled separately. The card normally opens at the later of government recognition/certification and 90 days before the verified scheduled start, and closes seven days after that start if service still needs verification. An undated recognition card has a bounded 90-day window. Reelection uses a notice on the existing profile.

The device clock only controls visibility and verified expiration. Promotion requires fresh government evidence of current service through a checked snapshot. State civil dates support honest display, not automatic assumption of office at a fabricated time. The client uses conservative day comparisons for these display windows, so an unspecified local start time cannot produce an early transition warning or early card removal. Incoming contacts and portraits stay empty unless separately verified; an outgoing official's details are never inherited by their successor.
