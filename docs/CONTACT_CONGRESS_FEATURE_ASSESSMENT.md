# Contact Congress Feature Assessment

Status: Planning recommendation  
Assessment date: 2026-09-15  
Product goal: Help a constituent identify and contact the correct members of Congress with very little effort, while protecting constituent data and congressional offices from automated abuse.

## Executive Decision

The feature is feasible, but direct delivery is not a client-only Flutter feature. It requires:

1. an exact, current district-resolution service;
2. a trusted backend that owns delivery credentials and queues;
3. House CWC and Senate SCWC approval, or a contracted delivery provider;
4. privacy, retention, and abuse controls designed before launch; and
5. a graceful official-form handoff while direct delivery is unavailable.

Build the user experience now behind a delivery-adapter boundary, launch an assisted-contact MVP first, and enable direct sending only after a House or Senate sandbox proves the real message contract.

Do not make reverse-engineered form submission the default production path. The `unitedstates/contact-congress` project says its House definitions have not been actively maintained since 2017, and it does not provide retries, error tracking, data storage, or delivery statistics.

## What the App Can Reuse

| Existing capability | Readiness | Assessment |
| --- | --- | --- |
| Address/ZIP entry | Partial | The landing search already accepts an address, city, state, or ZIP. It parses text locally; it does not validate that an address exists. |
| State and city discovery | Useful | Good for exploration and for finding two senators, but insufficient for an exact House member. |
| House and Senate data | Partial | Static assets include names, Bioguide IDs, websites, phone numbers, and scrape dates. The Dart models discard some useful fields, including Senate `contactUrl` and House `bioguideId`. |
| Exact House district | Not ready | ZIP-centroid and city matching can be wrong near district boundaries. The running app loads a 116th-Congress overlay even though a 119th-Congress download script exists. |
| Contact action | Minimal | Lawmaker details can call a phone number or open a general website. There is no composer, direct contact URL, recipient group, or delivery result. |
| Backend and credentials | Missing | No production API, queue, secret storage, authentication, rate limiting, or delivery ledger is present. |
| Abuse controls | Missing | No human challenge, verified email, throttling, deduplication, idempotency, or kill switch is present. |
| Privacy controls | Missing | No purpose-specific consent, retention policy, deletion behavior, privacy copy, or sensitive-field log filtering is present. |

The present UX is also not aligned with the stated mission. After a location search, `LocalDetailScreen` defaults to “On Your Ballot”; current representatives are the third tab and contact is another screen deeper. Contact must become a first-class action without removing the broader civic features.

## Facts to Confirm Before Direct Delivery

Public official material supports the following:

- [House CWC](https://www.house.gov/doing-business-with-the-house/communicating-with-congress-cwc) is for approved advocacy vendors sending advocacy-generated constituent communications through a strict XML path. The application is reviewed; access is not automatic.
- The [House CWC agreement](https://www.house.gov/sites/default/files/uploads/documents/CWC-USAGE-AGREEMENT.pdf) says the vendor is not charged a CWC fee, requires vendor and campaign identifiers, prohibits unauthorized names or email addresses, and allows access to be withdrawn.
- [Senate SCWC](https://www.senate.gov/senators/scwc.htm) uses SOAPBox and asks delivery agents to meet high-volume infrastructure and message-format requirements before applying.
- The [Census Geocoder](https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.html) can match an address and return congressional-district geography. It is a geography match, not proof that a person lives there and not a substitute for USPS deliverability validation.
- `unitedstates/contact-congress` is useful research data, but [its own status note](https://github.com/unitedstates/contact-congress) says House form definitions stopped active maintenance in 2017.

The earlier proposal's sample XML must not be treated as the contract. Mandatory fields, supported topics, current endpoints, status semantics, rate requirements, and address/ZIP+4 rules must come from the sandbox documentation supplied after approval.

“Free API” also does not mean “zero-cost feature.” Hosting, email verification, queueing, monitoring, incident response, and privacy operations remain product costs.

## Recommended Experience

### Product principles

- Ask for data at the moment its value is obvious. Apple’s [privacy guidance](https://developer.apple.com/design/human-interface-guidelines/privacy) recommends requesting access only when needed and explaining the specific purpose.
- Give each screen one clear job and one primary action.
- Do not require an account to send a first message.
- Keep the user in control: show recipients, message, and return address before the final send.
- Make the common human path quiet; add friction only when risk rises.
- Never say “delivered to your representative” when the evidence only proves “accepted by gateway” or “official form opened.”

### Entry and recipient flow

1. Landing headline: **Find and contact your representatives**.
2. Keep ZIP/city search for browsing. Ask for a full street address only when the user chooses **Write to Congress** or wants an exact House member.
3. Resolve and show one compact “Your Congress” group: the House member and two senators, with a **Write to all 3** primary action and clear recipient toggles.
4. Mask the address after matching: `Home district: CA-30 • Address confirmed`, with **Change** beside it.
5. Keep **Call** and **Official website** as secondary actions and reliable fallbacks.

This avoids asking for a sensitive address before the user has chosen a feature that needs it, while preserving low-friction exploration.

### Compose flow

Use a short three-stage sheet or full-screen stepper:

1. **Your message** — recipient summary, topic, subject, message. Offer editable starters, never a hidden or automatic message.
2. **Where replies go** — name, address prefilled from district matching, email, and one plain-language attestation: “I live at this address and I authorize this message.”
3. **Review and send** — show the complete message and exactly which offices receive it. The button must say **Send to 3 offices**, not “Continue.”

Afterward, show one status row per office:

- `Accepted for delivery` for a confirmed gateway acceptance;
- `Needs your action` with **Open official form** for a fallback;
- `Could not send` with a retry that is safe and idempotent.

### Trust-building copy

Place this directly below the address field, not in a distant privacy policy:

> **Why we ask:** Congressional offices use your home address to determine whether you are a constituent. We use it to match your district and include it with your message. We do not sell it, and we delete our delivery copy after the send is complete.

Place this below email:

> Your congressional office may reply here. We confirm this email once to prevent automated messages.

Use **Confirm your district**, not **Verify your identity**. Address matching proves a location exists; it does not prove identity or residency. Claiming more would weaken trust.

### What not to request

Do not request a government ID, voter-file match, Social Security number, continuous GPS, contacts permission, or party affiliation. These are disproportionate, exclusionary, and unnecessary for the initial use case. Optional one-time device location may help fill city/state, but it cannot establish residency and must never be the only path.

## Validation Without Surveillance

Use three distinct checks and describe them honestly:

| Check | What it establishes | What it does not establish |
| --- | --- | --- |
| Census address match | The address can be located and mapped to current geography | Deliverability, ownership, or residency |
| Email magic link or one-time code | The sender controls the reply inbox | Identity or home address |
| Constituent attestation | The user explicitly claims residency and authorizes the message | Independent proof of the claim |

This is the recommended baseline. Stronger identity proof should be added only if House/SCWC rules require it or measured abuse cannot be controlled otherwise.

For repeat use, offer **Save on this device** after a successful send. Store the profile locally with explicit consent. Do not silently create an account or retain a reusable server-side constituent profile.

## Abuse-Prevention Design

The send endpoint must be server-only. Apply defense in depth:

1. **Human signal at final send.** Use an adaptive challenge such as [Turnstile Managed mode](https://developers.cloudflare.com/turnstile/concepts/widget/) with `interaction-only` appearance on web. Most people see nothing; higher-risk traffic may see a checkbox. Validate every token on the server.
2. **Confirmed return address.** Verify email before the first direct send and again when risk changes. Put verification after composition so failed verification does not erase work.
3. **Layered rate limits.** Limit by verified email, recipient, privacy-preserving address fingerprint, device session, IP/ASN risk, and repeated-message/campaign pattern. Do not rely on IP alone; shared networks and VPNs would exclude legitimate users.
4. **Authorization and freshness.** Bind the challenge, verified email, normalized address, recipients, and message hash to a short-lived server-issued send intent.
5. **Idempotency.** A double tap or network retry must reuse an idempotency key and never create duplicate congressional messages.
6. **Content and target validation.** Enforce length limits, sanitize control characters, reject header/XML injection, restrict link volume, and allow delivery only to an official roster entry.
7. **Progressive enforcement.** Allow normal traffic; cool down or re-verify suspicious bursts; quarantine clearly automated campaigns. Avoid unexplained permanent blocks.
8. **Operational controls.** Provide per-adapter circuit breakers, a global send kill switch, anomaly alerts, recipient complaint handling, and an auditable but content-minimized event ledger.

Do not expose CWC/SCWC credentials to Flutter clients. Do not rely on client-side CAPTCHA checks, client-side limits, or a hidden endpoint name.

## Privacy and Data Lifecycle

Proposed default, subject to legal and vendor-contract review:

| Data | Purpose | Storage proposal |
| --- | --- | --- |
| Full name, address, email, message | Required delivery payload | Encrypted queue only; purge within 24 hours of terminal success or after a maximum 72-hour retry window |
| Normalized address fingerprint | Rate limiting and duplicate defense | Keyed HMAC, rotating key; retain 30 days |
| Delivery event | Receipt and operations | Opaque message ID, target, timestamps, status code; no raw message or address; retain 90 days |
| Product analytics | Funnel improvement | Coarse district/state and step events only; never raw address, email, message, or subject |
| Saved profile | Faster repeat use | On device only, opt-in, with a visible delete action |

Redact request bodies and URL query strings from logs, traces, crash reports, session replay, and analytics. Encrypt traffic and queues. Restrict production access by role. Publish a concise privacy notice and a deletion/contact path before accepting real messages.

## Technical Shape

```text
Flutter UI
  -> Address Resolver API
       -> Census geocoder/current district vintage
       -> official roster crosswalk by state + district + Bioguide ID
  -> Send Intent API
       -> email confirmation + risk checks + human challenge
  -> Delivery Orchestrator
       -> House CWC adapter (when approved)
       -> Senate SCWC adapter (when approved)
       -> official-form handoff adapter
  -> status ledger (no raw content after terminal state)
```

Define one internal delivery result vocabulary: `queued`, `accepted`, `needs_user_action`, `retryable_failure`, and `permanent_failure`. Each adapter maps its real response into these states. This lets UI work proceed against a fake/sandbox adapter without pretending credentials exist.

For address matching, pin the Census benchmark/vintage used, monitor unmatched and ambiguous addresses, and test territories, rural routes, apartment formatting, new construction, tribal lands, and Puerto Rico. A no-match result must offer correction and an official lookup—not guess a district.

The Census endpoint's current response does not advertise cross-origin browser access. Native Flutter clients can call it directly, but Flutter web should use a same-origin backend proxy that strips sensitive fields from logs and returns only the normalized match and district. Until that proxy exists, the web assisted flow must fail safely to senators and official lookup rather than guessing a House member.

## Delivery Phases

### Phase 0 — Approval and proof

- Apply to House CWC and Senate SCWC/SOAPBox, or issue a delivery-provider RFP.
- Ask each program to confirm eligibility for a neutral consumer civic app, mandatory fields, address requirements, campaign identifiers, acceptable verification, volume expectations, status/receipt behavior, sandbox access, and data-retention obligations.
- Replace the app’s 116th district dependency with a current, versioned district source.
- Build a 50-state/territory address-to-member benchmark with boundary and ambiguity cases.

Exit: written delivery requirements and a sandbox or chosen provider exist.

### Phase 1 — Assisted-contact MVP

- Ship exact district resolution and a prominent “Your Congress” contact group.
- Let users write once, copy the message, and open each verified official contact form or call with a script.
- Keep the message and identity fields on device. Measure form-open and copy completion, while clearly labeling that the app cannot observe final submission on an external site.
- Build the compose/review UI against a fake adapter so it will not be discarded later.

Exit: users reliably reach the correct official contact channels, and no UI claims direct delivery.

### Phase 2 — Direct-send pilot

- Add backend queue, send intents, email confirmation, adaptive human challenge, layered limits, and delivery/status adapters.
- Pilot with internal/test addresses and sandbox targets, then a small percentage of real traffic if permitted.
- Keep official-form handoff available whenever an adapter is unavailable.

Exit: correct-recipient, privacy, abuse, and delivery SLOs pass the pilot.

### Phase 3 — Low-friction repeat use

- Add opt-in on-device profile saving, device-appropriate attestation signals, saved drafts, and accessible recovery.
- Expand only after measuring whether each extra verification step reduces abuse enough to justify its completion cost.

## Acceptance Targets

- At least 99% exact House-member agreement against the approved benchmark; 100% of ambiguous/no-match cases fail safely without guessing.
- A first-time human can go from a selected validated address to final send in at most five deliberate taps, excluding typing and one email confirmation.
- A repeat user with an opt-in local profile can reach review in at most three taps.
- Every final send names the recipients and shows the exact message first.
- Duplicate sends from retries or double taps: zero in automated fault tests.
- Raw address, email, subject, and message absent from analytics, application logs, traces, and crash reports.
- Direct delivery reports status per office and never upgrades “accepted by gateway” into “read by staff.”
- Keyboard, screen-reader, dynamic-type, low-bandwidth, and mobile-web paths pass accessibility and recovery tests.

## Research Plan

1. **Program interviews:** House CWC and Senate SCWC questions from Phase 0; archive written answers as source-of-truth requirements.
2. **Address spike:** Run a representative address corpus through Census current geography; record match, ambiguity, latency, district, and failure reason. Compare with official House lookup.
3. **Delivery spike:** Implement only a sandbox adapter and exercise success, partial success, timeout, retry, revocation, and malformed payload cases.
4. **Threat model:** Model scripted sends, disposable email, residential proxy rotation, replay, recipient enumeration, XML/header injection, leaked keys, insider access, and denial-of-service.
5. **Privacy review:** Confirm contract and applicable-law requirements; approve the retention table and user copy before production data is accepted.
6. **Usability sessions:** Test the prototype with people of mixed digital comfort and political engagement. Ask them what they believe “address confirmed” and “accepted for delivery” mean; revise any misleading copy.
7. **Funnel instrumentation:** Measure address start/match, composer start, email confirmation, review, per-office result, fallback open, and abandonment using content-free events.

## Open Decisions

- Whether the organization qualifies directly for both government programs or should use an approved provider.
- Whether direct sending launches House-first, Senate-first, or only when all three federal recipients are supported.
- The exact rate policy and retention durations after threat-model and contract review.
- Whether native mobile launches with direct sending or follows a web-first pilot.
- Whether editable message starters are neutral examples or a separate advocacy-campaign product with additional disclosures and controls.
