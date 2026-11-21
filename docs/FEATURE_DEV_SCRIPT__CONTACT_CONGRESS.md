# Feature Control: Contact Congress

Goal: Let an ordinary constituent send a reviewed message directly to their current congressional office, using official data collected ahead of use and embedded in the app.
Definition of done: At least one real delivery channel works per supported office; validated official imports prepare app/backend records without hand-editing members or send-time government fetches; recipient accuracy, privacy, abuse, accessibility, idempotency, freshness, and per-office status release gates pass. Copy/open handoff and previews do not count as delivery.
Base commit: 281aeafa0d4942392c7d32033539d5b5f23a6021
Source of truth: [Official sources and refresh commands](CONGRESSIONAL_DATA_SOURCES.md), [Feature assessment](CONTACT_CONGRESS_FEATURE_ASSESSMENT.md), [address and recipient workflow](CONTACT_CONGRESS_WORKFLOW_PLAN.md), [privacy-minimal protocol](CONTACT_CONGRESS_PRIVACY_MINIMAL_PROTOCOL.md), [abuse and verification plan](CONTACT_CONGRESS_ABUSE_AND_VERIFICATION_PLAN.md), and [delivery contract](CONTACT_CONGRESS_DELIVERY_CONTRACT.md)

## Invariants

- Never guess recipients or destinations; use source-backed current office/term data and the district boundaries currently in effect.
- Never expose delivery credentials or enforce abuse controls only in the client.
- Never claim a message was delivered or read beyond the evidence returned by the real channel.
- Never place raw address, email, subject, or message data in analytics, logs, traces, or crash reports.
- Publish only validated versioned data; stale or disputed routes cannot authorize sends, and recipient changes require renewed review.

## Work

| ID | State | Owner | Task | Evidence |
| --- | --- | --- | --- | --- |
| C-01 | Active | Product/Partnerships | Prove a viable delivery route and its field/receipt contract: CWC/SCWC, contracted delivery, or officially supported fax/email | Outreach drafts exist; access and channel coverage unconfirmed |
| C-02 | Todo | Civic data | Pin serving-Congress geography, replace cd116, and benchmark exact-address resolution behind the backend | Resolver tests exist; production proxy/benchmark pending |
| C-03 | Done | Product design | Build address-first, exact-district, delegation, compose, email code, attestation, trust summary, recoverable back navigation, one-submit preview, and truthful confirmation flow | Screens + focused tests |
| C-04 | Done | Architecture | Define the client delivery contract, placeholder gateway, per-office results, and session idempotency | `docs/CONTACT_CONGRESS_DELIVERY_CONTRACT.md` |
| C-05 | Done | Security | Threat model and define adaptive challenge, email confirmation, layered limits, moderation, cooldowns, circuit breakers, and kill switch | `docs/CONTACT_CONGRESS_ABUSE_AND_VERIFICATION_PLAN.md` |
| C-06 | Active | Privacy/Legal | Approve the pass-through field inventory, processor contracts, TTL ledger, deletion, purpose copy, and incident access | `docs/CONTACT_CONGRESS_PRIVACY_MINIMAL_PROTOCOL.md`; review pending |
| C-07 | Done | Flutter | Add contact/Bioguide fields and expose one consistent assisted-contact entry from landing/local screens | Models + landing/local entries |
| C-08 | Todo | QA/Research | Validate advertised coverage, turnover/vacancies, accessibility, recovery, and real per-office outcomes | 45 focused/regression tests passed 2026-10-16; live delivery and nationwide benchmark pending |
| C-09 | Blocked | Backend | Implement one real delivery adapter and pilot before adding other channels | Depends on C-01 access and authoritative contract |
| C-10 | Todo | Backend/Security | Implement production verification, authorization, persistent idempotency, abuse limits, and minimal receipts | Flutter contracts exist; production endpoints absent |
| C-11 | Done | Civic data | Download and validate official bulk rosters; publish the embedded snapshot | `scripts/refresh_congress.py`; 11 import tests; source manifest |
| C-12 | Todo | Operations | Define independent maintenance/release refresh cadence and alerts; no user-triggered collection | Repeatable refresh command and atomic app publication implemented; hosted schedule absent |
| C-13 | Done | Flutter | Load the official embedded snapshot and open existing composer from any congressional profile without a lookup | `congressional_roster.dart`; directory-mode widget test; live sending still disabled |

| C-14 | Done | Flutter | Implement shared Direct Message entry, compact portrait/contact profile, minimal delivery field and confirmation, sender-copy result contract | 45 tests; `flutter build web --no-pub`; profile/contact tests |

## Blockers

- No real delivery route has confirmed credentials, coverage, requirements, and receipt semantics; CWC and SCWC need separate access.
- Official bulk import and embedded data are implemented; hosted refresh operations and production delivery remain unconfigured.
- Hosting, persistent storage, operational alert destination, and per-source freshness limits need to be resolved before deployment.

## Decisions

- 2026-10-16: Collect government data during development/release or separate maintenance; embed it for users. No send-time government roster fetch. Direct delivery is still required.
- 2026-10-16: One proven channel per supported office is enough initially; defer additional channels, guided calling, AI, campaigns, saved profiles, and state/local expansion.
- 2026-10-16: Prefer official structured feeds; enrich missing destinations from official member sites and never infer email/fax values. Validate coverage before publication.
- 2026-09-15: Address matching is not residency proof; use email confirmation and constituent attestation without disproportionate identity collection.
- 2026-10-16: Keep one compact confirmation and email the sender their record; no in-app history, response tracking, or email preview. Email-copy delivery is independently confirmed; backend setup is pending.

## Next Action

`C-01`: Establish a delivery account or chamber approval and obtain the authoritative sender-field, recipient-eligibility, and receipt contract before implementing a live adapter; the user confirmed no account/approval exists.
