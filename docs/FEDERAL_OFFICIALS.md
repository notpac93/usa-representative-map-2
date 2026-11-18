# Federal officials and verified transitions

Implemented federal coverage: occupied House seats (including delegates), Senate seats, president, vice president, Supreme Court seats, and ten principal congressional leadership roles. The initial government-checked snapshot has 560 occupied offices/roles: 439 House, 100 Senate, 9 justices, 2 executive, and 10 leadership roles. People may hold a legislative seat and a leadership role simultaneously.

This is a first federal implementation. Cabinet and lower federal court collection are not connected. Registered FJC and Congress.gov sources prepare those integrations without claiming their data has been collected. Vacant seats are not represented as people. Historical assets remain available to the existing records screens.

## Display contract (separate app integration)

- Serving official: the single primary profile and portrait, with that term's contact details.
- Incoming: a smaller text-only card. No competing portrait or contact button.
- Card opens at the later of verified certification and **90 days before the scheduled start**.
- At a verified handoff, the successor becomes the primary profile and the incoming card disappears.
- When confirmation is delayed, the incoming card remains for **seven days after the scheduled start**, then collapses to a small verification notice without a second person's name or portrait.
- A reelected incumbent receives a next-term notice on their existing profile.
- Disputed/withdrawn terms do not produce incoming cards.
- A verified expiration suppresses the outgoing occupant even when the successor is unconfirmed. The device never promotes anyone based on its clock.
- Dates are stored with UTC offsets. Regular federal January noon in Washington is 17:00 UTC. Display dates use UTC to avoid shifting the official date for users in other time zones.

The app integration was developed separately in the local workspace. This pipeline-only deployment does not ship those screen changes or change how installed apps load their data. The display rules above describe the intended app integration.

## Records and evidence

The separately developed app model in `lib/data/federal_officials.dart` defines `FederalOffice`, `FederalPerson`, `FederalTerm`, `FederalEvidence`, `FederalSource`, and `FederalSnapshot`.

- Office IDs identify seats, independently of people. Senate IDs include class; House IDs include state/district. Associate justice slot numbers are local stable identifiers, not government-assigned seat numbers: preserve the slot ID when reviewing a replacement.
- A term separates scheduled start/end, actual start/end, certification, status, and term-scoped contacts. An observation does not invent an exact historical service-start or resignation timestamp.
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

House XML does not provide member websites. Those records expose the verified phone/address without promoting a historical website to verified status. Senate websites/contact forms come directly from the roster. Executive and judicial contacts remain blank unless verified contact evidence is connected.

`federal_reviewed_offices.json` binds reviewed executive, justice, and leadership identities to exact government roster excerpts. Executive/justice excerpts must match current roster headings rather than incidental mentions. A mismatch blocks publication and requires review; the collector never guesses the new person from a search result.

## On-demand collection, comparison, and publication

The primary entry point is `scripts/federal_data_pipeline.py`. The original `refresh_federal_officials.py` command delegates to the same safe workflow and now checks only by default.

Check without modifying published data:

```sh
python3 scripts/federal_data_pipeline.py --check
```

This downloads the government sources, validates them, saves the raw source responses and a candidate, and writes readable `report.md`, structured `report.json`, and an integrity manifest under `tmp/federal-checks/<run>/`. The report lists changes with old/new values. Source-page changes and retrieval timestamps do not create a new meaningful data version. The `dataVersion` fingerprint changes when office/person/term data changes; each successful publication still records its fresh verification date.

Check and publish valid data:

```sh
python3 scripts/federal_data_pipeline.py --publish
```

Serving-person changes, lost contacts, missing current offices, removed history, or updates affecting over 50 records require explicit review. The report supplies the exact data version to approve. To publish an already reviewed candidate without another download:

```sh
python3 scripts/federal_data_pipeline.py --publish-run tmp/federal-checks/RUN_ID --approve DATA_VERSION_FROM_REPORT
```

Placeholders above must come from the actual report. No approval is needed for an ordinary validated contact correction or a successful recheck with no data differences. Approving a version does not bypass schema, source, evidence, configuration, or integrity failures. It only acknowledges flagged data changes.

A saved check expires after 24 hours. Changed collection rules, source configuration, candidate bytes, or the currently published baseline invalidate it. Concurrent publication is locked. Government fetches retry transient failures up to three times; redirects and permanent failures remain errors. A failed source/parser/coverage check cannot replace the latest snapshot. Duplicate government seat/person entries are rejected before they can be merged away.

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

`scripts/data/federal_transition_plans.json` starts empty intentionally. No 2026 winner has been invented, inferred from vote totals, or labeled certified by this implementation.

To add a real incoming term:

1. Register the responsible election authority with exact approved hosts, appropriate office kinds, `states`, and the `certification` claim. Update the bundled mirror and ship that registry before relying on it for remote updates.
2. Add the incoming person using an official stable ID where available and the existing seat's office ID.
3. Add reviewed evidence for `certification` and `scheduledStart`. Every plan evidence item requires `id`, `sourceId`, `url`, `officeId`, `personId`, `claim`, an exact normalized-text `excerpt`, and `expectedSha256` of the reviewed government response. A changed hash or missing excerpt blocks publication for review.
4. Add a term with `id`, `officeId`, `personId`, `status: incoming`, `certifiedAt`, `scheduledStart` (explicit offset), and `evidenceIds`. Future service starts belong in `scheduledStart`, never `actualStart`.
5. For a special election or appointed position, review the applicable office-specific start rule; do not apply regular January rules automatically.
6. The official congressional current roster can confirm a handoff when the scheduled start arrives (House records additionally require a nonfuture sworn date). Other planned handoffs require fresh `assumedOffice` evidence and a verified nonfuture `actualStart`. An already promoted or ended plan is not reset on the next run.
7. Mark revoked/disputed plans `withdrawn` or `disputed`; deleting a plan is not a revocation of the saved history. A conflicting source or unexpected roster requires human review.

Reviewed transition records are trusted editorial inputs. A hash proves the exact document used, not that arbitrary text in a government document proves a claim. Reviewers must check that the excerpt actually identifies the person, election/appointment, seat, certification, and applicable date. Broad automatic extraction from election-result sites is not enabled.

## Live delivery and offline use

Collection, saving approved data, and releasing data to app users are separate decisions. The current default is manual collection with no hosted app feed configured. Keep `FEDERAL_SNAPSHOT_URL` unset for the slower release process: checking or saving data does not change an installed app. Ship the saved asset with a normal app release, or later choose a separately managed hosted release endpoint. The approved snapshot branch is an archive until explicitly selected for delivery.

The runtime reads a validated bundled snapshot, then the last valid saved snapshot (native app-support file or browser local storage). With a configured HTTPS endpoint it checks for a newer snapshot every five minutes and on profile resume. Invalid, older, future-dated, or unavailable updates retain the last valid data. A minute tick rechecks visibility and expiration without promoting anyone. Snapshots older than 48 hours show a freshness notice.

App delivery is deliberately separate from the data archive. Keep `FEDERAL_SNAPSHOT_URL` unset for the current release process. When you decide to release an update, select a specific saved snapshot for a normal app release, or later introduce a separately controlled hosted release endpoint. The `codex/federal-snapshots` branch stores approved data and recovery history; it is not configured as the app's live data feed.

The manual GitHub deployment includes only the collection/publishing workflow, its tests and source registry, a federal baseline dataset, and this documentation. App screen changes, production hosting, automatic app delivery, and a recurring schedule are outside this deployment. Use the [GitHub operator guide](GOVERNMENT_DATA_CHECK.md) to run checks, review reports, and save verified data.
