# Contact Congress Address and Recipient Workflow

Updated: 2026-09-15  
Branch: `codex/contact-congress-workflow`

## Product decision

The primary flow targets the constituent's own federal delegation. For a resident
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
non-constituent Member offices. Until the programs answer that in writing, direct
delivery is limited to the address-matched delegation. Other offices may be
offered later as clearly separate official-directory links.

## Shipped workflow skeleton

1. **Find district:** collect structured street, city, state/territory, and ZIP.
2. **Match safely:** use the official Census current benchmark/vintage through the
   district-resolver boundary. Require one address, one state, and one current
   district; ambiguous and missing matches stop without guessing.
3. **Crosswalk roster:** join state + district number to one current House roster
   record and join state to its senators.
4. **Confirm delegation:** show the matched district and every recipient before
   composition. A state resident normally sees three offices.
5. **Compose once:** allow recipient opt-out, topic, subject, and an editable
   constituent-authored message.
6. **Reply details:** reuse the matched address; collect name, email, and explicit
   residency/message authorization.
7. **Review:** show the exact recipients, full message, and contact details.
8. **Deliver or hand off:** keep direct send disabled while credentials are absent;
   provide honest per-office official-site actions and preserve the message for
   copying.

## Production completion plan

### 1. Authoritative recipient accuracy

- Put the Census request behind a same-origin backend endpoint for Flutter web so
  addresses do not rely on browser CORS behavior.
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
- Keep raw address/message data out of analytics and logs; encrypt the delivery
  queue and purge raw payloads after the documented retry window.
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
- Preserve official-form handoff for an unapproved chamber, suspended office,
  outage, or permanent rejection.

### 5. Optional other-office experience

- Keep **Your federal delegation** as the default and only bulk-send group.
- Add **Find another congressional office** only as a visibly separate task.
- Use official directory links for committees, leadership, or non-constituent
  Members until each chamber gives written permission and recipient-handling rules.
- Never call another district's House member “your representative.”

## Acceptance checklist

- Full address precedes the composer; state selection alone never advances.
- The user sees district and recipients before writing or sending.
- A state address resolves to two senators plus one and only one House member.
- Territory and vacancy behavior is explicit and source-correct.
- Address change invalidates the prior recipient match.
- No-match and ambiguity cannot reach direct delivery.
- Final review names every selected office and shows the exact message.
- Duplicate delivery is impossible under retry/double-tap fault tests.
- Keyboard, screen reader, dynamic type, mobile web, and low-bandwidth paths pass.

## Official sources

- [House Find Your Representative](https://www.house.gov/representatives/find-your-representative)
- [House CWC program](https://www.house.gov/doing-business-with-the-house/communicating-with-congress-cwc)
- [House CWC agreement](https://www.house.gov/sites/default/files/uploads/documents/CWC-USAGE-AGREEMENT.pdf)
- [Senate SCWC overview](https://www.senate.gov/senators/scwc.htm)
- [Senate SCWC Terms](https://soapbox.senate.gov/registration/terms-of-service/)
- [House Clerk Member FAQ](https://clerk.house.gov/Help/ViewMemberFAQs)

