# Feature Control: Contact Congress

Goal: Let a constituent find the correct House member and senators and contact them with minimal effort, truthful delivery status, strong privacy, and bot resistance.
Definition of done: An approved direct-delivery or clearly labeled assisted-handoff flow passes recipient-accuracy, privacy, abuse, accessibility, idempotency, and per-office status acceptance targets in the feature assessment.
Base commit: d82879f55065c3fb58f476547e9891ed917c024f
Source of truth: [Feature assessment](CONTACT_CONGRESS_FEATURE_ASSESSMENT.md), [address and recipient workflow](CONTACT_CONGRESS_WORKFLOW_PLAN.md), and [delivery contract](CONTACT_CONGRESS_DELIVERY_CONTRACT.md)

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
| C-02 | Active | Civic data | Replace 116th-district runtime data and benchmark the exact-address resolver | 11 tests + live 119th response; overlay/proxy pending |
| C-03 | Done | Product design | Build address-first, exact-district, delegation, compose, verification, review, and per-office result flow | Start + compose screens; focused tests |
| C-04 | Done | Architecture | Define the client delivery contract, placeholder gateway, per-office results, and session idempotency | `docs/CONTACT_CONGRESS_DELIVERY_CONTRACT.md` |
| C-05 | Todo | Security | Threat model and define adaptive challenge, email confirmation, layered limits, circuit breakers, and kill switch | Threat model pending |
| C-06 | Todo | Privacy/Legal | Approve purpose copy, field inventory, contracts, retention, deletion, and incident access | Retention proposal pending |
| C-07 | Done | Flutter | Add contact/Bioguide fields and expose one consistent assisted-contact entry from landing/local screens | Models + landing/local entries |
| C-08 | Active | QA/Research | Validate recipient accuracy, territories/vacancies, accessibility, recovery, trust comprehension, and funnel | 31 focused tests; full benchmark pending |
| C-09 | Blocked | Backend | Implement and pilot direct House/Senate delivery adapters | Blocked by C-01 approval/sandbox |
| C-10 | Todo | Backend/Security | Add same-origin address proxy, email verification, persistent idempotency, rate limits, encrypted queue, and status ledger | Contract defined; backend absent |

## Blockers

- Direct sending is blocked until House CWC/SCWC or an approved provider supplies authoritative requirements and sandbox access.
- Current client data cannot reliably resolve an exact House member: ZIP/city matching is approximate and the runtime district overlay is for the 116th Congress.
- Census exact matching works for native clients, but its public response lacks a browser CORS header; web needs a same-origin backend proxy.

## Decisions

- 2026-09-15: Launch a truthful assisted official-form/call handoff before direct credentials exist; do not depend on reverse-engineered form automation.
- 2026-09-15: Use address match + confirmed email + constituent attestation as the baseline; do not request government ID or voter-file proof by default.
- 2026-09-15: Use progressive abuse friction and server-side enforcement; keep the normal human path quiet.
- 2026-09-15: Build UI against a delivery-adapter contract so sandbox, direct, and handoff modes share one recoverable result model.
- 2026-09-15: State selection alone cannot enter the composer; require one exact address/district match and show the resulting delegation first.

## Next Action

`C-01`: Send the Phase 0 requirements questionnaire to House CWC and Senate SCWC and obtain the current application/sandbox requirements in writing.
