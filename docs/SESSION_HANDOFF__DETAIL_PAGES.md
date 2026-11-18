# Details pages and government history handoff

Saved on November 18, 2026. This file preserves the decisions and implementation
context independently of the chat window.

## User experience

- Leader entry opens a brief contact-first profile. Details opens the deeper sections.
- State-name matches lead city matches in search and open state leadership; maps stay optional.
- State and governor details use the approved tabs/cards/charts design.
- History is a separate section on state and governor details.
- Mobile home has US States, Federal Branches, and Find My Reps entry points.
- The historical design reference is `docs/design/details-page-mockup.html`.
  Its sample values and old connection labels are design examples, not current data.

## Saved data and maintenance

- `assets/data/detail_population.json`: bundled population history.
- `assets/data/government_indicators.json`: government income, GDP, unemployment,
  and housing snapshots and time series. See `docs/GOVERNMENT_INDICATORS.md`.
- `assets/data/governor_history.json`: 1,738 historical service periods across
  all 50 states, covering 1,584 saved people. Several state rosters remain partial.
- `scripts/data/governor_history_reviewed.json`: reviewed national history facts.
- `scripts/import_governor_history.py`: validates and preserves national history,
  including nonconsecutive service and correction revisions.
- `scripts/refresh_governor_history.py`: California State Library refresher.
- `docs/GOVERNOR_HISTORY.md`: state coverage, source rules, known gaps, update steps.
- `.github/workflows/government-indicators.yml`: weekly government indicator and
  California history refresh, with reviewed national history retained.
- Federal profiles, snapshots, source evidence, and recovery releases are also saved
  in this checkout. See `docs/FEDERAL_OFFICIALS.md` and
  `docs/FEATURE_DEV_SCRIPT__FEDERAL_OFFICIALS.md` for their separate maintenance flow.

National governor history is a reviewed snapshot, not a nationwide automatic scraper.
Only verified government sources should be added. Never infer completed service from
an election, an incoming officeholder, or a device clock. Do not delete older records
because a source no longer lists them.

## Distribution

Saving to GitHub main preserves the work and bundled data. It does not install a new
phone build or publish an App Store release. App users receive bundled-data changes
with a rebuilt/distributed app. Future refresh jobs can propose additional data changes.

For iPhone testing, use a Release build. A Debug build previously failed to launch
outside developer tooling. The last signed Release build was successful; installing
the latest saved changes on the phone remains a separate step.

## Final save verification

- Full Flutter suite: 95 tests passed.
- Python data/preservation suite: 49 tests passed.
- National governor history validation and Git whitespace checks passed.
- Home/navigation checks were updated for the approved mobile layout.
- The remote-data future-date check now uses an actual future timestamp.
- A long election-date label now wraps within narrow layouts.

This handoff and the approved design reference are committed alongside the app and
data. Future work can start from the repository without reopening the original chat.
