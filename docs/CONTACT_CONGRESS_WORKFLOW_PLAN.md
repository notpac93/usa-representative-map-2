# Contact Congress Address and Recipient Workflow

Current UI refinement (2026-10-16): congressional profiles/results use **Direct Message**; profiles consolidate portrait, identity and contact details with one app-bar action. The composer shows only a **Delivery Method** field in its sidebar. Successful submission ends with a heading and one sentence about the independently confirmed emailed copy; no tracking panel, email preview, or application message archive. Failure/partial results remain in review. See [delivery and sender-copy contract](CONTACT_CONGRESS_DELIVERY_CONTRACT.md). Live delivery and transactional email are not configured.

Updated: 2026-10-16

## Minimum release scope and priority

The minimum product lets an ordinary constituent identify their current federal
representative, write and review a message, and authorize actual transmission from
the app to that office. One working delivery method per supported office is
enough: approved congressional delivery, a contracted delivery service, or fax or
email to an officially published constituent-contact destination. Supporting all
methods is not required for the first release. An official form link, copied
message, opened mail client, or submission preview does not satisfy this goal.

Government-source data is collected and validated ahead of user interaction,
then embedded in the app and prepared for the delivery backend. The repeatable
refresh command runs during development/release or separate maintenance; browsing
and sending must not trigger government-source collection. Users select existing
records and send through configured routes. Source failures must not silently
replace good data. See [implemented sources and commands](CONGRESSIONAL_DATA_SOURCES.md).

Priority order:

1. Establish the canonical government-source roster/contact data contract and
   select a viable delivery route with confirmed requirements. Delivery access
   investigation can proceed while ingestion is built.
2. Prepare and validate the official bulk snapshot, bundle it in the app, and
   provide a repeatable refresh command independent of user requests.
3. Prove an authorized end-to-end delivery through one real adapter, including
   required constituent fields, verification, duplicate prevention, and receipts.
4. Connect the existing Flutter flow and validate the advertised coverage before
   enabling production sends. A small pilot proves integration, not national
   readiness. Unavailable offices remain explicitly unavailable.

Defer guided calling, AI drafting, campaigns, petitions, saved profiles, expanded
state/local coverage, and extra delivery methods until this minimum works.

## Government data and publication contract

Data preparation is implemented locally; live delivery remains unconfigured:

```text
Development/release: official bulk sources -> saved source snapshots
  -> validation -> bundled app roster + prepared backend routing records

User: select an embedded official -> write -> review
  -> backend validates request using stored routing configuration
  -> delivery adapter -> per-office receipt (no government roster fetch)
```

Source responsibilities:

| Data | Preferred authority | Required treatment |
| --- | --- | --- |
| House membership and identity | House Clerk member XML, reconciled with official membership/vacancy information | Preserve Bioguide ID, seat, Congress, effective dates, source publication and retrieval times |
| Senate membership and contact metadata | Senate current-senator XML and official directory | Separate senator identity from seat; represent vacancies explicitly |
| Address-to-district match | Census Geocoder and district geography for the Congress currently serving | Record benchmark, vintage, and Congress; do not assume the newest election boundary is the currently represented district |
| Fax, public constituent email, official contact form | Member-office pages linked from the official roster | Track provenance and last validation per destination; unknown is not usable; never derive email/fax from naming patterns |
| Delivery destination IDs, required fields, topics, and receipt meanings | Approved chamber/provider contract | Version independently from roster data; an official website alone does not establish delivery capability |

Prefer structured feeds over browser scraping. House XML is documented in the
[Clerk data guide](https://clerk.house.gov/member_info/MemberData_UserGuide.pdf);
the Senate publishes a [current-senator XML contact list](https://www.senate.gov/general/XML.htm).
Downloaded feed endpoints are
`https://clerk.house.gov/xml/lists/MemberData.xml` and
`https://www.senate.gov/general/contact_information/senators_cfm.xml`.
Original responses are saved under `data/sources/congress/`; the tested importer
publishes one `assets/data/congressional_roster.json` snapshot. The House directory
provides websites missing from the Clerk feed.

The House explicitly states that there is
[no central list of public member email addresses](https://www.house.gov/representatives/find-your-representative).
A contact-form URL is not an email inbox. Fax/email coverage must be measured,
and an email or fax provider does not establish that an office accepts that route.
Do not use webmaster, press, campaign, or staff-personal contacts as substitutes.

Minimum pipeline behavior:

- Run bulk collection during development/release or a separately configured
  maintenance job. No user action triggers a refresh. Record source URL, retrieval
  time, source publication time where available, and content hash. Retrieval time
  alone must not imply that an old source is current. A hosted schedule is not yet
  configured.
- Separate people, seats, terms, and contact endpoints. Use stable office/term
  keys and Bioguide IDs, not names, to join records. Preserve absence, confirmed
  vacancy, and retrieval failure as distinct states.
- Validate jurisdiction coverage against the official seat inventory, with
  explicit vacancies/delegates; do not require a fixed count of occupied seats.
  Reject duplicate active occupants, missing identities, conflicting Congress
  versions, schema changes, and unexplained coverage drops. Fetching HTTP 200
  is not a successful data update.
- Publish a complete validated snapshot atomically; retain the last good version
  for rollback and browsing. Quarantine suspect updates and alert. Define and
  enforce freshness limits for each source/route before production; stale or
  disputed records must not authorize new sends.
- Ship the prepared snapshot with Flutter. The backend uses already-stored office
  and route configuration for authorization, without fetching government data.
  Never silently redirect a reviewed message to a different person. Optional
  future background app-data updates are separate from the send action.
- Treat scraping as source-specific enrichment when structured data lacks a
  field. Follow source access limits; detect layout changes and ambiguous values.
  Keep portraits and other optional data failures outside contact publication.

## Current pipeline findings

Implemented on 2026-10-16:

- Official House/Senate downloads are archived with source hashes. The importer
  validates 441 House seats (439 occupied, two vacant) and 100 Senate records.
- Both Flutter loaders now use the same embedded snapshot; no network lookup is
  performed to read congressional records. CO, CT, and DE coverage is restored.
- Individual profiles open the existing composer with the chosen office and no
  Census request. This path remains explicitly preview-only.
- `scrapeAll.cjs` now uses the bulk importer for Congress. Legacy browser scrapers
  are no longer the main congressional ingestion path.
- The separate Find my members path retains its explicit Census address lookup.
  The legacy district map still uses cd116 and must not authorize current sends.
- Live verification and delivery remain unimplemented; the user confirmed there
  is no provider account or chamber approval yet.

## Minimum release evidence

- A development/release refresh regenerates the embedded roster from official
  bulk sources without hand-editing members; source and version are inspectable.
  Browsing and directory-selected drafting work without government requests.
- Fault tests prove partial downloads, malformed feeds, missing jurisdictions,
  vacancies, member replacement, and Congress rollover cannot misroute a send.
- The recipient benchmark covers the declared release geography; unresolved
  addresses and unavailable offices fail explicitly without inventing recipients.
- One enabled channel per supported office has confirmed access and required
  fields, a successful authorized delivery test, and defined receipt semantics.
- Timeouts, retries, duplicate taps, and delayed/duplicate provider callbacks do
  not create duplicate messages. Unknown delivery outcomes remain unknown until
  reconciled; do not automatically switch to fax/email after an uncertain send.
- The user sees a per-office status with an honest meaning: gateway acceptance,
  fax transmission confirmation, and staff reading are separate events.
- Backend verification, consent, abuse limits, secrets, privacy controls, stale
  data gates, and operational alerts work before accepting real constituent data.

## Product decision

The address-discovery flow targets the constituent's own federal delegation.
A second entry from an individual profile selects that existing directory record
without discovering a district. Its current implementation is draft/preview only;
channel-specific eligibility for non-constituents remains unresolved. For a resident
of a state, that normally means two U.S. senators and exactly one U.S. House
member determined by the residential address. District 1 and District 2 have
different House members; they do not give a constituent different numbers of
federal representatives.

District of Columbia and U.S. territory cases must show their House Delegate or
Resident Commissioner and must not invent senators. Vacancies and roster changes
must be represented explicitly rather than filled with stale data.

The House CWC and Senate SCWC public rules describe delivery to individual Member
offices and explicitly exclude committee, leadership, and support offices. They do
not publicly establish whether this neutral app may use direct delivery for
non-constituent Member offices. Production delivery must implement the selected provider's actual recipient
rules. Directory drafting is available now and must never falsely claim that a
selected office represents the sender.

## Shipped workflow skeleton

1. **Find district:** collect street and ZIP first, fill city/state from the
   bundled ZIP dataset when recognized, preserve browser saved-address autofill,
   and let the user correct every field.
2. **Match safely:** use the official Census current benchmark/vintage through the
   district-resolver boundary. Native clients use JSON and the browser prototype
   uses Census's documented callback/JSONP response mode. Require one address,
   one state, and one current district; ambiguous and missing matches stop without
   guessing.
3. **Crosswalk roster:** join state + district number to one current House roster
   record and join state to its senators.
4. **Confirm delegation:** show the matched district and every recipient before
   composition. A state resident normally sees three offices.
5. **Compose once:** allow recipient opt-out, topic, subject, and an editable
   constituent-authored message.
6. **Reply details:** reuse the matched address; collect name, email, and explicit
   residency/message authorization.
7. **Review:** show the exact recipients, full message, and contact details.
8. **Submit once:** send one idempotent request containing the message and all
   selected offices through the delivery gateway. While credentials are absent,
   the placeholder performs no network request and returns a truthful per-office
   `Not sent` result. Once approved, the backend routes House recipients to CWC
   and Senate recipients to SCWC without changing the user flow.

## Production completion plan

### 1. Authoritative recipient accuracy

- Put the Census request behind a same-origin backend endpoint for Flutter web so
  privacy controls, request limits, and operational telemetry are consistent. The
  current prototype uses Census's documented JSONP mode because its JSON response
  does not permit browser CORS.
- Return only normalized match, state, current district, and match status.
- Refresh the House/Senate roster on a monitored schedule using authoritative
  Bioguide/Clerk/Senate sources; record source time and congressional session.
- Test all states, at-large districts, DC, territories, vacancies, redistricting,
  apartments, rural routes, tribal lands, boundaries, no-match, and ambiguity.
- Require 99%+ benchmark agreement and 100% safe failure for ambiguous cases.

### 2. Trust and privacy

- Explain the address request inline before collection.
- Never label Census matching as identity or residency verification.
- Confirm email ownership before a first direct send; keep the drafted message.
- Bind the matched address, chosen recipients, message hash, consent, and challenge
  to a short-lived server send intent.
- Keep raw address/message data out of analytics and logs; default to
  synchronous pass-through and preserve failed drafts on device. Add an
  encrypted retry queue only when contractually required or explicitly chosen.
- Offer opt-in on-device profile saving only after a successful completion.

### 3. Abuse resistance

- Validate an adaptive human challenge on the server at final send.
- Rate-limit by verified email, recipient, session, privacy-preserving address
  fingerprint, network risk, and repeated campaign/message patterns.
- Enforce content limits, roster-only targets, idempotency, retry rules, per-office
  circuit breakers, office suspension, and a global kill switch in the backend.
- Use progressive re-verification/cooldowns so shared networks and accessibility
  tools are not punished by IP-only blocks.

### 4. Chamber delivery

- Obtain separate House CWC and Senate SCWC approval, technical packets, sandbox
  credentials, mandatory fields, campaign-ID rules, verification requirements,
  volume limits, retry semantics, and status meanings.
- Implement server-only House and Senate adapters behind the existing internal
  request/result contract.
- Map acknowledgements conservatively. `Accepted for routing` must never become
  `Delivered` or `Read` without an authoritative chamber status.
- Keep the draft recoverable for an unapproved chamber, suspended office, outage,
  or permanent rejection; never silently report partial success.

### 5. Optional other-office experience

- Keep **Your federal delegation** as the default and only bulk-send group.
- Add **Find another congressional office** only as a visibly separate task.
- Use official directory links for committees, leadership, or non-constituent
  Members until each chamber gives written permission and recipient-handling rules.
- Never call another district's House member “your representative.”

## Acceptance checklist

- In address-discovery mode, full address precedes the composer; state selection alone never advances. Directory mode opens the already-selected office without an address lookup.
- The user sees district and recipients before writing or sending.
- A matched state address resolves to two senators plus one House member when those seats are occupied; vacancies remain explicit.
- Territory and vacancy behavior is explicit and source-correct.
- Address change invalidates the prior recipient match.
- No-match and ambiguity cannot reach direct delivery.
- Final review names every selected office, shows the exact message, and offers
  one submission action rather than an office-by-office website workflow.
- Duplicate delivery is impossible under retry/double-tap fault tests.
- Keyboard, screen reader, dynamic type, mobile web, and low-bandwidth paths pass.

## Verification snapshot

On 2026-09-15, the four-step Flutter web flow was exercised in the browser using
the public California State Capitol address. ZIP `95814` filled Sacramento and
California locally; the Census lookup returned CA-7; the roster produced Alex
Padilla, Adam B. Schiff, and Doris Matsui. The UI has since replaced the former
official-site handoff with one gateway-backed submission action whose placeholder
mode transmits nothing.

## Official sources

- [House Find Your Representative](https://www.house.gov/representatives/find-your-representative)
- [House CWC program](https://www.house.gov/doing-business-with-the-house/communicating-with-congress-cwc)
- [House CWC agreement](https://www.house.gov/sites/default/files/uploads/documents/CWC-USAGE-AGREEMENT.pdf)
- [Senate SCWC overview](https://www.senate.gov/senators/scwc.htm)
- [Senate SCWC Terms](https://soapbox.senate.gov/registration/terms-of-service/)
- [House Clerk Member FAQ](https://clerk.house.gov/Help/ViewMemberFAQs)
