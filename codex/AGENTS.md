# Codex Agent Mirror

This folder defines the project-owned Codex agent roster for USA Representative Map.

It mirrors the HuddleWay Codex scheme without modifying the HuddleWay files at:

- `/Users/kennygrimblejr./HuddleWay/codex`

## Codex Labeling Rules

This Codex mirror follows the same agent conventions used in the reference project:

- use the short `first-last-role` agent ID format
- keep each `description` narrow and keyword-rich for routing
- keep files alphabetized with a single-letter prefix
- keep handoffs explicit and scoped to the next specialist
- treat this `codex/` folder as the active source set for this project unless a future `.github/agents/` source is introduced

## Product Mission

USA Representative Map helps Americans quickly find the public officials who represent them, understand the jurisdiction they live in, and contact the correct office without searching across many disconnected websites.

The product standard is:

- accurate, source-backed civic information
- fast, mobile-first discovery
- inviting, consistent, predictable interface design
- nonpartisan presentation
- clear freshness and source lineage for volatile civic data
- architecture that can expand from federal/state/local representation into live legislation, voter information, and city-level government coverage

## Current App Context

The current repository is primarily a Flutter app with static/offline civic data assets and supporting data-pipeline scripts.

Key areas:

- Flutter app entry and map shell: `lib/main.dart`
- data loading and in-memory civic records: `lib/data/`
- national, state, place, and jurisdiction map painting: `lib/map/`
- representative and section detail screens: `lib/screens/`
- reusable map/detail widgets: `lib/widgets/`
- static app data: `assets/data/`
- generated and raw data pipeline assets: `data/`
- Node/TypeScript scraping and overlay scripts: `scripts/`
- Rust data pipeline prototype: `usa-data-pipeline/`
- tests: `test/`

Default local checks should favor:

- `flutter analyze`
- `flutter test`
- focused data script dry runs or validation commands when pipeline files change
- web smoke runs on port 8080 when UI behavior needs manual verification

## Civic Data Rules

- Prefer official government, election office, legislative, or directly maintained public-office sources.
- Record source URLs, retrieval dates, and known coverage gaps for any changing civic data.
- Never present guessed contact details, party labels, district assignments, photos, or voter deadlines as verified.
- Treat voter registration, election deadlines, officeholders, districts, and live legislation as time-sensitive.
- Separate current shipped behavior from future intended behavior in copy, docs, and agent reports.

## Codex Roster

- `angela-davis-builder`
  File: `codex/agents/a-angela-davis-builder.agent.md`
- `bayard-rustin-architect`
  File: `codex/agents/b-bayard-rustin-architect.agent.md`
- `coretta-scott-king-release`
  File: `codex/agents/c-coretta-scott-king-release.agent.md`
- `dorothy-height-deployment`
  File: `codex/agents/d-dorothy-height-deployment.agent.md`
- `eldridge-cleaver-integrations`
  File: `codex/agents/e-eldridge-cleaver-integrations.agent.md`
- `fred-hampton-agentics`
  File: `codex/agents/f-fred-hampton-agentics.agent.md`
- `marcus-garvey-hardening`
  File: `codex/agents/g-marcus-garvey-hardening.agent.md`
- `jesse-jackson-performance`
  File: `codex/agents/h-jesse-jackson-performance.agent.md`
- `john-lewis-security`
  File: `codex/agents/i-john-lewis-security.agent.md`
- `james-baldwin-docs`
  File: `codex/agents/j-james-baldwin-docs.agent.md`
- `medgar-evers-accuracy-liaison`
  File: `codex/agents/k-medgar-evers-accuracy-liaison.agent.md`
- `lorraine-hansberry-brand`
  File: `codex/agents/l-lorraine-hansberry-brand.agent.md`
- `rosa-parks-testing`
  File: `codex/agents/m-rosa-parks-testing.agent.md`
- `a-philip-randolph-infra`
  File: `codex/agents/n-a-philip-randolph-infra.agent.md`
- `oliver-tambo-civic-data`
  File: `codex/agents/o-oliver-tambo-civic-data.agent.md`
- `pauli-murray-voter-info`
  File: `codex/agents/p-pauli-murray-voter-info.agent.md`
- `quincy-jones-components`
  File: `codex/agents/q-quincy-jones-components.agent.md`
- `ruby-bridges-address-lookup`
  File: `codex/agents/r-ruby-bridges-address-lookup.agent.md`
- `shirley-chisholm-representatives`
  File: `codex/agents/s-shirley-chisholm-representatives.agent.md`
- `toni-morrison-seo`
  File: `codex/agents/t-toni-morrison-seo.agent.md`
- `ursula-burns-mobile-compliance`
  File: `codex/agents/u-ursula-burns-mobile-compliance.agent.md`
- `viola-liuzzo-wireframes`
  File: `codex/agents/v-viola-liuzzo-wireframes.agent.md`
- `gordon-parks-ui-capture-refactor`
  File: `codex/agents/w-gordon-parks-ui-capture-refactor.agent.md`
- `xernona-clayton-legislation`
  File: `codex/agents/x-xernona-clayton-legislation.agent.md`
- `yvonne-burke-local-government`
  File: `codex/agents/y-yvonne-burke-local-government.agent.md`

