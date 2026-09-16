# Feature Control: Contact Congress

Goal: Let a constituent find the correct House member and senators and contact them with minimal effort, truthful delivery status, strong privacy, and bot resistance.
Definition of done: The one-submit flow uses approved direct delivery and passes recipient-accuracy, privacy, abuse, accessibility, idempotency, and per-office status acceptance targets in the feature assessment.
Base commit: d82879f55065c3fb58f476547e9891ed917c024f
Source of truth: [Feature assessment](CONTACT_CONGRESS_FEATURE_ASSESSMENT.md), [address and recipient workflow](CONTACT_CONGRESS_WORKFLOW_PLAN.md), [abuse and verification plan](CONTACT_CONGRESS_ABUSE_AND_VERIFICATION_PLAN.md), and [delivery contract](CONTACT_CONGRESS_DELIVERY_CONTRACT.md)

## Invariants

- Never guess a House district or recipient when address resolution is ambiguous.
- Never expose delivery credentials or enforce abuse controls only in the client.
- Never claim a message was delivered or read beyond the evidence returned by the real channel.
- Never place raw address, email, subject, or message data in analytics, logs, traces, or crash reports.
- Ask for exact address and verification only when the user chooses a task that requires them.

## Work

| ID | State | Owner | Task | Evidence |
| --- | --- | --- | --- | --- |
| C-01 | Active | Product/Partnerships | Confirm House CWC and Senate SCWC eligibility, contracts, fields, verification, volume, sandbox, and status semantics | `docs/CWC_SCWC_REQUIREMENTS_OUTREACH.md` |
| C-02 | Active | Civic data | Replace 116th-district runtime data and benchmark the exact-address resolver | 11 tests + live browser CA-7 response; production proxy/benchmark pending |
| C-03 | Done | Product design | Build address-first, exact-district, delegation, compose, verification, recoverable back navigation, one-submit preview, and per-office result flow | Start + compose screens; focused tests |
| C-04 | Done | Architecture | Define the client delivery contract, placeholder gateway, per-office results, and session idempotency | `docs/CONTACT_CONGRESS_DELIVERY_CONTRACT.md` |
| C-05 | Done | Security | Threat model and define adaptive challenge, email confirmation, layered limits, moderation, cooldowns, circuit breakers, and kill switch | `docs/CONTACT_CONGRESS_ABUSE_AND_VERIFICATION_PLAN.md` |
| C-06 | Todo | Privacy/Legal | Approve purpose copy, field inventory, contracts, retention, deletion, and incident access | Retention proposal pending |
| C-07 | Done | Flutter | Add contact/Bioguide fields and expose one consistent assisted-contact entry from landing/local screens | Models + landing/local entries |
| C-08 | Active | QA/Research | Validate recipient accuracy, territories/vacancies, accessibility, recovery, trust comprehension, and funnel | 32 focused tests + browser one-submit preview pass; full benchmark pending |
| C-09 | Blocked | Backend | Implement and pilot direct House/Senate delivery adapters | Blocked by C-01 approval/sandbox |
| C-10 | Todo | Backend/Security | Add same-origin address proxy, email verification, persistent idempotency, rate limits, encrypted queue, and status ledger | Contract defined; backend absent |

## Blockers

- Direct sending is blocked until House CWC/SCWC or an approved provider supplies authoritative requirements and sandbox access.
- Current district lookup is exact-address based, but production still needs a current-roster refresh process and nationwide accuracy benchmark.
- The browser prototype uses the Census-documented JSONP path. Production still needs a same-origin proxy to apply privacy controls, observability, and abuse limits consistently.

## Decisions

- 2026-09-15: Use a truthful non-transmitting submission preview before direct credentials exist; the eventual experience stays one-submit and does not depend on reverse-engineered form automation.
- 2026-09-15: Use address match + confirmed email + constituent attestation as the baseline; device location may be opt-in autofill but is never required or represented as residency proof.
- 2026-09-15: Use progressive server-side abuse friction, content safety review, duplicate-specific limits, and temporary multi-signal cooldowns; never ban solely by IP, device, or a classifier result.
- 2026-09-15: Build UI against a delivery-adapter contract so sandbox, direct, and handoff modes share one recoverable result model.
- 2026-09-15: State selection alone cannot enter the composer; fill city/state locally from ZIP, preserve saved-address autofill, then require an exact Census address/district match and show the delegation first (JSONP is prototype-only on web).

## Next Action

`C-01`: Send the Phase 0 requirements questionnaire to House CWC and Senate SCWC and obtain the current application/sandbox requirements in writing.
