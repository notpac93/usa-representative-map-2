# Feature Control: Federal officials and transitions

Goal: Keep federal data accurate through on-demand government checks, meaningful comparisons, guarded publication, and recoverable history.
Definition of done: Validated office/person/term/evidence records drive federal profiles; tested server publication gates transitions and preserves failed-refresh data.
Base commit: 281aeafa0d4942392c7d32033539d5b5f23a6021
Source of truth: docs/FEDERAL_OFFICIALS.md

## Invariants

- Government evidence is scoped to the fact, identity, office, and jurisdiction.
- A device clock never promotes an incoming official.
- One primary portrait; incoming information is text only and time limited.
- Failed collection never replaces a valid snapshot.
- Existing unrelated workspace changes remain intact.

## Work

| ID | State | Owner | Task | Evidence |
| --- | --- | --- | --- | --- |
| F-01 | Done | Codex | Model, registry, publisher, and bounded display | lib/data/federal_officials.dart; web build passed |
| F-02 | Done | Codex | Verify transition, source, and UI safeguards | 14 publisher + 21 Flutter checks |
| F-03 | Done | Codex | Document publication and deployment requirements | docs/FEDERAL_OFFICIALS.md |
| F-04 | Done | Codex | On-demand check, comparison, guarded publication, and rollback | scripts/federal_data_pipeline.py |
| F-05 | Done | Codex | Exercise recovery, corruption, concurrency, and Git publication | 34 federal pipeline tests + live recovery rehearsal |
| F-06 | Done | Codex | Deploy manual workflow and verify check, save, and default recheck in GitHub | PR #1; runs 44374891319, 44375167947, 44375440897 |

## Blockers

- None

## Decisions

- 2026-11-18: Display incoming after certification within 90 days of start; hide after verified handoff or seven days past expected start.
- 2026-11-18: Publisher validates government evidence; devices only display published service status.
- 2026-11-18: Collection is manual on demand; check-only is the default and every publication saves recovery evidence.

## Next Action

Use the deployed Government data check workflow on demand; app release remains a separate decision.
