# Feature Control: Nationwide election intake

Goal: Collect official election evidence across 50 states, add incoming officials with independently verified starts, and remove stale election assumptions while keeping checks manual and app releases separate.
Definition of done: Every state has a scoped input path and coverage report; populated incoming records have government evidence; certification/date gaps stay explicit; manual check/save and stale-date UI pass verification.
Base commit: 44967cc
Source of truth: docs/ELECTION_INTAKE.md

## Invariants

- Government recognition is distinct from certification and current service.
- A download or directory listing never proves a certified winner or complete coverage.
- A civil start day never becomes an invented UTC timestamp.
- Source failures preserve previous validated records and expose gaps.
- Checks/save remain manual; no app release occurs here.

## Work

| ID | State | Owner | Task | Evidence |
| --- | --- | --- | --- | --- |
| E-01 | Done | Codex | Register all 50 government authorities and export evidence | scripts/data/state_election_sources.json |
| E-02 | Active | Codex | Mississippi, nationwide recognition, and reviewed state imports | scripts/election_results.py |
| E-03 | Done | Codex | Remove stale/guessed election dates from app flows | test/election_lifecycle_test.dart |
| E-04 | Active | Codex | Validate incoming/civil-date/conflict handling and real intake | scripts/tests/test_election_integration.py |
| E-05 | Todo | Codex | Document scope, save verified snapshot, and verify manual workflow | Pending |

## Blockers

- Some state sources block automated access; approved exports or reviewed downloads are needed.
- Several states have not published a verified statewide certification; do not invent it.

## Decisions

- 2026-11-19: Incoming recognition, election certification, and verified service are separate facts.
- 2026-11-19: Statewide/source/contest/start-date completeness are separate report dimensions.

## Next Action

`E-04`: Finish live intake and validate incoming records against the saved government evidence.
