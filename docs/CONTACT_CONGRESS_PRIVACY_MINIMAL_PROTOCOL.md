# Contact Congress Privacy-Minimal Protocol

Status: Proposed architecture. Chamber requirements, privacy counsel, and service-provider contracts must be confirmed before live delivery.

## Privacy Goal

Keep raw constituent data on the device and in transit whenever possible. Do not create constituent accounts or reusable server profiles. Do not persist raw name, address, email, subject, or message on the application backend by default.

Zero processing is impossible: Census must receive the address to geocode it, the email provider must receive the destination email to deliver a code, the bot provider receives browser/security signals, and Congress must receive the final constituent payload. The product must disclose these processors and contractually review their retention.

## Default Delivery Mode

Use synchronous pass-through delivery:

1. The device keeps the draft in application memory.
2. The backend receives the final payload over TLS, validates it in request memory, and immediately calls the approved House/Senate adapter.
3. Request-body logging, tracing, analytics, crash capture, and session replay are disabled or redacted for every sensitive endpoint.
4. The backend discards the raw payload when the request completes.
5. If a chamber is unavailable, the app keeps the draft on the device and asks the constituent to retry. The backend does not silently create a raw-message retry queue.

An asynchronous encrypted queue may be added only if a chamber contract requires it or users explicitly choose delayed retry after a clear retention disclosure. Its key and record must be destroyed after terminal delivery or the shortest approved retry window.

## Five-Step Protocol

### 1. Exact address and district match

- Keep the entered address in device memory.
- Send it through a no-log same-origin proxy to the Census Geocoder.
- Return the normalized match, congressional district, benchmark/vintage, and match confidence.
- Create `address_proof`, a short-lived signed claim containing an HMAC of the canonical address, district ID, benchmark, and expiry. It contains no raw address.
- Keep the raw normalized address on the device because it is required again in the final congressional payload.
- Never advance on an ambiguous match.

### 2. First-send email confirmation

- Ask for confirmation after the message is written so verification friction never destroys the draft.
- Prefer a six-digit code with OS email-code autofill; offer a magic link as an alternative.
- Send a generic email that contains no address, recipients, topic, or message text.
- Keep only a random challenge ID, HMAC of the normalized email, HMAC of the code, failed-attempt count, and ten-minute expiry in the TTL store.
- On success, mint `email_proof` and immediately delete the code record.
- Require confirmation again only when the email changes, risk rises, or the proof expires.

### 3. Constituent attestation

- Use one unticked checkbox immediately above final review: “I live at this address and authorize this message to the selected offices.”
- Show the normalized address and offices next to the statement.
- Bind the attestation text version and server timestamp into the send authorization.
- Do not use legalistic identity-proof language or imply independent proof of residency.

### 4. Quiet bot challenge

- Execute the managed challenge only when the user presses the final send button.
- Most users see a brief “Checking…” state; show an interactive challenge only when the provider requests it.
- Validate the token on the backend and verify its action and production hostname.
- Never send form values to the bot provider.
- Treat the challenge as one signal, not identity proof or the sole reason for a long ban.

### 5. Short-lived send authorization

After the previous checks pass, mint a signed capability that stays in device memory and expires after five minutes. It contains:

- random authorization ID and expiry;
- `address_hmac` and `email_hmac`;
- official recipient IDs;
- keyed hash of the subject and message;
- attestation version and server timestamp;
- successful challenge action;
- random idempotency key.

The final send includes the raw payload and capability. The backend recomputes every HMAC, rejects any changed field or recipient, atomically marks the authorization ID used, and forwards the payload. Editing the address, email, recipients, subject, or message invalidates the capability and silently creates a new one after the required checks.

## Minimal Server Ledger

Reliable one-time verification, rate limiting, and duplicate prevention require a small amount of temporary server state. Store no raw constituent fields in this ledger.

| Record | Values | Maximum default TTL |
| --- | --- | --- |
| Email challenge | Random ID, email HMAC, code HMAC, attempts | 10 minutes; delete on success |
| Used authorization | Random authorization ID, used flag | 24 hours |
| Idempotency receipt | Random request ID, recipient IDs, coarse results | 72 hours |
| Rate counters | Rotating HMAC of email/address/install token, recipient ID, count | 30 days |
| Exact-duplicate counter | Rotating keyed hash of normalized message and recipient ID | 7 days |

Use HMACs with secrets held in the key manager, never plain hashes of emails or addresses. Rotate the rate-limit key monthly and destroy the prior key after the longest counter window. Treat derived identifiers as sensitive even though they do not contain raw PII.

Near-duplicate or semantic-message retention is excluded from the privacy-minimal baseline. Detect exact normalized duplicates plus rate and campaign anomalies first. Reconsider derived similarity fingerprints only after a privacy review and measured abuse demonstrates the need.

## Device Storage

- Default: draft exists only in application memory and disappears when the workflow is discarded or the app process ends.
- Optional: “Save this draft on this device” stores an encrypted draft in platform secure storage with a visible delete action and expiry.
- Never synchronize drafts or profiles to an account by default.
- Use a random installation token stored locally for abuse counters; do not read a hardware identifier or build a durable fingerprint.

## Third-Party Data Boundaries

| Processor | Minimum data received | Data deliberately excluded |
| --- | --- | --- |
| Census Geocoder | Address needed for the lookup | Email, message, recipients |
| Email provider | Destination email and generic verification code | Address, message, congressional offices |
| Bot provider | Challenge token and necessary browser/security signals | Form fields and message content |
| House/Senate gateway and office CRM | Approved constituent and message payload | Internal risk signals and rate counters |

Do not use a third-party message classifier unless it is self-hosted or contractually configured for zero retention and no model training. Content checks should otherwise run inside the application backend in request memory.

## Required Verification

- Automated tests prove that sensitive routes emit no request bodies to logs, traces, analytics, or crash reports.
- A privacy test confirms TTL deletion and cryptographic-key rotation behavior.
- A replay test proves that email codes, bot tokens, send authorizations, and idempotency keys cannot create duplicate messages.
- Service-provider agreements document subprocessors, retention, deletion, breach notice, and training/use restrictions.
- The public notice names each external processor category and explains that congressional offices retain messages under their own policies.

## References

- [Census Geocoding Services API](https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.html)
- [Cloudflare Turnstile server-side validation](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/)
- [NIST data minimization guidance](https://pages.nist.gov/800-63-4/sp800-63c/privacy/)
- [House CWC program](https://www.house.gov/doing-business-with-the-house/communicating-with-congress-cwc)
- [Senate SCWC service](https://www.senate.gov/senators/scwc.htm)
