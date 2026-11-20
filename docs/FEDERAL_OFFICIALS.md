# Federal officials and verified transitions

Implemented federal coverage: occupied House seats (including delegates), Senate seats, president, vice president, Supreme Court seats, and ten principal congressional leadership roles. The initial government-checked snapshot has 560 occupied offices/roles: 439 House, 100 Senate, 9 justices, 2 executive, and 10 leadership roles. People may hold a legislative seat and a leadership role simultaneously.

The serving-official collector covers these federal offices. Election evidence intake also registers all 50 states, parses selected Mississippi, Wyoming, and Delaware inputs, and supports explicitly reviewed imports for the remaining states. This does not provide a complete roster of incoming officials or current state/local officials. See [election intake and its coverage limits](ELECTION_INTAKE.md). Cabinet and lower federal court collection are not connected. Registered FJC and Congress.gov sources prepare those integrations without claiming their data has been collected. Vacant seats are not represented as people. Historical assets remain available to the existing records screens.

## Display contract

- Serving official: the single primary profile and portrait, with that term's contact details.
- Incoming: a smaller text-only card. No competing portrait or contact button.
- Recognition and certification have distinct labels. The card opens at the later of verified recognition/certification and **90 days before the scheduled start**. Recognition without a verified start has a bounded 90-day display window.
- At a verified handoff, the successor becomes the primary profile and the incoming card disappears.
- When confirmation is delayed, the incoming card remains for **seven days after the scheduled start**, then collapses to a small verification notice without a second person's name or portrait.
- A reelected incumbent receives a next-term notice on their existing profile.
- Disputed/withdrawn terms do not produce incoming cards.
- A verified expiration suppresses the outgoing occupant even when the successor is unconfirmed. The device never promotes anyone based on its clock.
- Exact instants use explicit UTC offsets. Regular federal January noon in Washington is 17:00 UTC. State laws that specify only a day use `scheduledStartDate`, date precision, and a verified time zone where available. A civil day is not an exact service-start timestamp.

These rules are implemented in the app model and profile integration. A data check or archive save does not ship app changes or update installed apps. Data delivery and app releases remain separate decisions.

## Records and evidence

The app model in `lib/data/federal_officials.dart` defines `FederalOffice`, `FederalPerson`, `FederalTerm`, `FederalEvidence`, `FederalSource`, and `FederalSnapshot`.

- Office IDs identify seats, independently of people. Senate IDs include class; House IDs include state/district. Associate justice slot numbers are local stable identifiers, not government-assigned seat numbers: preserve the slot ID when reviewing a replacement.
- A term separates scheduled start/end, actual start/end, certification, status, and term-scoped contacts. An observation does not invent an exact historical service-start or resignation timestamp.
- `incomingRecognized` records government recognition without implying certification. A certified result still needs a verified office-specific start before it has a fully dated incoming term. Neither status means current service.
- House terms retain Congress identifiers; Senate terms retain verified class periods. New periods create new terms, including reelection.
- Every evidence item binds a person, office, claim, government source URL, retrieval instant, and SHA-256 of the retrieved response.
- The source registry restricts allowed hosts, office kinds, claims, and (for state election authorities) states. A government host alone is not authority for every fact.
- The runtime uses the bundled registry, not a registry supplied by an untrusted downloaded snapshot.
- Checks save compressed government responses under `tmp/federal-checks/<run>/sources/`. Published evidence is retained by SHA-256 under `data/federal/evidence/`; recovery releases live under `data/federal/releases/`. The workflow also retains downloadable check artifacts for 90 days.

Existing portraits are retained by stable person identity. They are legacy assets, not newly certified or rights-reviewed portraits. A missing portrait uses a person icon. No photo is inherited by seat number. Portrait licensing/refresh collection is a separate follow-up; source evidence for current membership does not certify an inherited image's rights.

## Official sources

Canonical registry: `scripts/data/federal_sources.json`. Its asset mirror is `assets/data/federal_sources.json`; update both together when registering sources.

Active collection reads:

- House Clerk member XML, including sworn dates and current Congress.
- Senate roster XML and the three official class-term pages.
- National Archives 20th Amendment for regular federal term-time rules.
- White House current administration headings.
- Supreme Court current member headings.
- House and Senate leadership directories.
- Partial government senators-elect and House caucus members-elect recognition sources.
- All-state result directories, approved linked exports, the Mississippi/Wyoming/Delaware adapters, and any configured reviewed result packages. Directory coverage, parsed contests, certification, and start-date coverage are reported separately.

House XML does not provide member websites. Those records expose the verified phone/address without promoting a historical website to verified status. Senate websites/contact forms come directly from the roster. Executive and judicial contacts remain blank unless verified contact evidence is connected.

`federal_reviewed_offices.json` binds reviewed executive, justice, and leadership identities to exact government roster excerpts. Executive/justice excerpts must match current roster headings rather than incidental mentions. A mismatch blocks publication and requires review; the collector never guesses the new person from a search result.

## On-demand collection, comparison, and publication

The primary entry point is `scripts/federal_data_pipeline.py`. The original `refresh_federal_officials.py` command delegates to the same safe workflow and now checks only by default.

Check without modifying published data:

```sh
python3 scripts/federal_data_pipeline.py --check
```

This downloads the government sources, validates supported inputs, saves the raw source responses and a candidate, and writes readable `report.md`, structured `report.json`, per-state `state-reports.json`, and an integrity manifest under `tmp/federal-checks/<run>/`. The report lists changes with old/new values and distinguishes source access from parsed/certified contest coverage. Routine retrieval timestamps and archived response metadata do not create a new meaningful data version. The `dataVersion` fingerprint covers normalized office/person/term/election-result data; each successful publication still records its fresh verification date.

Check and publish valid data:

```sh
python3 scripts/federal_data_pipeline.py --publish
```

Serving-person changes, lost contacts, missing current offices, removed history, updates affecting over 50 records, or incomplete all-state election coverage require explicit review. The report supplies the exact data version to approve. Approval of partial coverage acknowledges the reported gaps; it does not certify missing results. To publish an already reviewed candidate without another download:

```sh
python3 scripts/federal_data_pipeline.py --publish-run tmp/federal-checks/RUN_ID --approve DATA_VERSION_FROM_REPORT
```

Placeholders above must come from the actual report. A run with no flagged conditions can save without approval, but incomplete election coverage remains a review condition even when there are no meaningful data changes. Approving a version does not bypass schema, source, evidence, configuration, or integrity failures. It only acknowledges the reported changes and coverage gaps.

A saved check expires after 24 hours. Changed collection rules, source configuration, candidate bytes, or the currently published baseline invalidate it. Concurrent publication is locked. Government fetches retry transient failures up to three times; redirects and permanent failures remain errors. Required source or integrity failures block saving. Optional state-source/parser failures remain explicit coverage gaps and cannot produce an unverified replacement; a reviewed partial snapshot can be saved with those gaps. HTTP 200 security challenges are rejected as election evidence, and Nevada's restricted automated directory request is skipped. Duplicate government seat/person entries are rejected before they can be merged away.

Before replacement, the publisher saves the exact previous file, candidate, reports, source evidence, configuration hashes, and any approval in a new recovery release. The app asset is replaced atomically only after these copies succeed. The canonical published file is `assets/data/federal_officials.json`; an orphan recovery folder from an interrupted run does not mean publication occurred. Run a fresh check after an interrupted preparation. If a process dies while holding a `.publish-lock`, verify no publisher is still running before removing that lock.

Verify the saved publication or restore its exact previous version:

```sh
python3 scripts/federal_data_pipeline.py --verify-published
python3 scripts/federal_data_pipeline.py --rollback-release data/federal/releases/RUN_ID
```

Recovery refuses to overwrite a later publication, checks the recovery copy's hash, preserves the old verification date, and saves a recovery audit. It does not pretend old data was freshly checked. Publication archives and compressed evidence should be retained with the project/publishing branch and included in backups.

`.github/workflows/federal-officials.yml` is **manual only**. In GitHub Actions choose **Run workflow**, then **check** (default) or **save**. Neither choice releases an update to the app. Flagged changes stop publication and put the report in the run summary/downloadable artifact. A subsequent save run may use the exact approved data version if the meaningful data is unchanged. Saving restores previous history and updates `codex/federal-snapshots` in a separate checkout; it never force-pushes or changes the source branch. The branch-publishing helper verifies the saved release before pushing. Tests exercise initial and subsequent pushes against a temporary local Git remote.

No year-round government collection is enabled. Run a check when desired and around known election, certification, appointment, or term-start events. A scheduled handoff needs a new verified publication; an offline app cannot independently confirm that service began.

Checks:

```sh
python3 -m unittest discover -s scripts/tests -p 'test_federal*.py'
flutter test test/federal_officials_test.dart test/federal_officials_service_test.dart
```

Exit codes: `0` successful check/publication, `1` invalid or failed check, `2` review required or publication/recovery blocked. A "review required" run keeps the published file unchanged.

## Incoming records

Incoming records now come from government recognition and reviewed state adapters, in addition to explicit transition plans. The reviewed November 2026 sources provide a partial list of 19 senators-elect and 40 new House caucus members-elect; neither list is a complete election roster or certification source. Wyoming's pinned signed canvass supports 86 candidate contests, with 85 verified scheduled starts after national federal rules are applied. Mississippi awaits verified statewide certification. Delaware's reconciled government results are retained without an independent certification claim. Read the current report for live counts and failures, and [the election intake guide](ELECTION_INTAKE.md) for source scope and reviewed package requirements.

`scripts/data/federal_transition_plans.json` remains the explicit plan input; it does not need to contain the records produced by these adapters. `scripts/data/election_result_reviews.json` is the separate pinned government-result package input, currently unconfigured. No import path establishes all-state winner completeness or confirms service from a date alone.

To add an explicit reviewed transition plan:

1. Register the responsible election authority with exact approved hosts, appropriate office kinds, `states`, and the `certification` claim. Update the bundled mirror and ship that registry before relying on it for remote updates.
2. Add the incoming person using an official stable ID where available and the existing seat's office ID.
3. Add reviewed evidence for `certification` and `scheduledStart`. Every plan evidence item requires `id`, `sourceId`, `url`, `officeId`, `personId`, `claim`, an exact normalized-text `excerpt`, and `expectedSha256` of the reviewed government response. A changed hash or missing excerpt blocks publication for review.
4. Add a term with `id`, `officeId`, `personId`, `status: incoming`, `certifiedAt`, `scheduledStart` (explicit offset), and `evidenceIds`. Future service starts belong in `scheduledStart`, never `actualStart`.
5. For a special election or appointed position, review the applicable office-specific start rule; do not apply regular January rules automatically.
6. The official congressional current roster can confirm a handoff when the scheduled start arrives (House records additionally require a nonfuture sworn date). Other planned handoffs require fresh `assumedOffice` evidence and a verified nonfuture `actualStart`. An already promoted or ended plan is not reset on the next run.
7. Mark revoked/disputed plans `withdrawn` or `disputed`; deleting a plan is not a revocation of the saved history. A conflicting source or unexpected roster requires human review.

Reviewed transition records are trusted editorial inputs. A hash proves the exact document used, not that arbitrary text in a government document proves a claim. Reviewers must check that the excerpt actually identifies the person, election/appointment, seat, certification, and applicable date. Structured automatic extraction is enabled only for supported adapters and explicit result bindings. Scanned result/certification packages require identified human review; unsupported contests and missing start rules remain visible gaps.

## Live delivery and offline use

Collection, saving approved data, and releasing data to app users are separate decisions. The current default is manual collection with no hosted app feed configured. Keep `FEDERAL_SNAPSHOT_URL` unset for the slower release process: checking or saving data does not change an installed app. Ship the saved asset with a normal app release, or later choose a separately managed hosted release endpoint. The approved snapshot branch is an archive until explicitly selected for delivery.

The runtime reads a validated bundled snapshot, then the last valid saved snapshot (native app-support file or browser local storage). With a configured HTTPS endpoint it checks for a newer snapshot every five minutes and on profile resume. Invalid, older, future-dated, or unavailable updates retain the last valid data. A minute tick rechecks visibility and expiration without promoting anyone. Snapshots older than 48 hours show a freshness notice.

App delivery is deliberately separate from the data archive. Keep `FEDERAL_SNAPSHOT_URL` unset for the current release process. When you decide to release an update, select a specific saved snapshot for a normal app release, or later introduce a separately controlled hosted release endpoint. The `codex/federal-snapshots` branch stores approved data and recovery history; it is not configured as the app's live data feed.

The manual GitHub workflow collects federal and registered state election evidence, validates supported adapters and reviewed packages, and saves approved data with its recovery history. It does not build or release the app, configure production hosting, enable automatic app delivery, or add a recurring schedule. Use the [GitHub operator guide](GOVERNMENT_DATA_CHECK.md) to run checks, review reports, and save verified data, and [the election intake guide](ELECTION_INTAKE.md) to interpret state coverage and add reviewed evidence.
