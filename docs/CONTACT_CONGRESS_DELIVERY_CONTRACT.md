# Contact Congress Delivery Contract

Status: one-submit client flow implemented; direct delivery intentionally disabled

2026-10-16 clarification: roster/contact collection runs ahead of user interaction.
The app loads `assets/data/congressional_roster.json`; the eventual backend uses
prepared recipient and delivery-route records. Send authorization does not fetch
government rosters or repeat a government-source freshness check. It validates
the request against application-owned records and configured delivery rules.
See [official sources and commands](CONGRESSIONAL_DATA_SOURCES.md).

Individual lawmaker profiles now open the existing composer in directory mode
without a Census lookup. This mode is preview-only until a provider's rules for
selected-office delivery are implemented; it does not assert constituency.

## Direct Message interface

Congress search results and congressional profiles share `DirectMessageButton`.
The profile keeps one button in the app bar and groups the portrait, identity,
district/state, party, and available contact information in one compact card.
The map is collapsed below it. Missing email/fax data is never invented.

The compose sidebar contains only a field labeled **Delivery Method**. It shows
the congressional electronic route as a disabled single option until configured
backend capabilities exist; it does not offer unimplemented fax/email routes.
No reminder card or extra delivery explanation is displayed below that field.

After every selected office confirms submission, the screen contains a success
heading, one email-copy sentence, and Done. It has no message history, tracking
panel, office-response expectation, or email preview. Partial/failed results
remain recoverable in review; they never become an overall success. The default
placeholder ends with **Preview complete / No message or email was sent.**

## Sender's email copy

`CongressionalDeliveryRequest.sendCopyToConstituent` is always true. The future
backend must send the exact submitted message, recipient(s), submission time,
route, and reference to the email bound to the verified send authorization.
Do not accept an independent copy destination, add a user-facing opt-in, or use
`mailto:` as delivery. A partial result must identify which offices accepted it.

The result reports `senderCopyStatus` independently: `notConfirmed` (default),
`pending`, `sent`, or `failed`. Only a confirmed email-service send may return
`sent`; office acceptance alone cannot imply that the sender's copy was emailed.
Duplicate results preserve this status. A copy retry must not repeat the
congressional send; use separate backend idempotency for that operation.

Generate the copy from the request in memory before disposing of the raw payload.
There is no application message archive or new account requirement. Provider
retention, verification, and failure/retry behavior must be confirmed before
launch. **Only the client contract and UI are implemented: no delivery backend
or transactional email provider is configured yet.**

## Current behavior

The Flutter app uses `PlaceholderCongressionalDeliveryGateway` by default.
The final screen sends one typed request containing every selected office through
that gateway. The placeholder performs no network request and returns a separate
`unavailable` result for each office, so the complete interaction can be tested
without implying that Congress received anything.

The production swap point is the `CongressionalDeliveryGateway` passed into
`ContactCongressStartScreen`. It will call an application-owned backend; the UI,
single-submit action, idempotency key, request model, progress state, and
per-office result rendering do not need to change when credentials arrive.

## Security boundary

Flutter may contain only the typed request and result contract in
`lib/services/congressional_delivery_service.dart`. It must never contain:

- House CWC or Senate SCWC API keys, passwords, client certificates, or signing
  keys;
- chamber endpoints, IP allowlist credentials, vendor IDs, or production
  campaign credentials;
- direct XML, SOAP, or chamber-specific HTTP clients.

Those values belong in an application-owned backend secret store. Mobile and
web builds are public artifacts, so build-time variables and obfuscation do not
make a congressional credential safe.

## Backend adapters to add after approval

The application backend (which may be implemented in this repository) must implement one adapter per
approval and protocol:

1. `HouseCwcAdapter`: validate the approved House fields, map the internal
   request to the supplied schema, submit using server-held credentials, and
   translate the acknowledgement into one typed office result.
2. `SenateScwcAdapter`: do the equivalent using the approved Senate SOAPBox
   contract and credentials.
3. `CongressionalDeliveryGateway`: validate the send authorization, verify email and
   abuse-control tokens, enforce persistent idempotency, route each recipient
   to the correct adapter, and return results separately for every office.

The Flutter implementation can replace the placeholder only with a gateway
that calls this application-owned backend over HTTPS. It must not choose an
adapter or hold chamber configuration locally.

## Verification gateway contract

`lib/services/contact_congress_verification_service.dart` now defines the
client-side proof sequence used before the delivery gateway:

1. an exact Census match receives a benchmarked, expiring address proof;
2. a first-send email challenge receives a short-lived email proof;
3. the constituent attestation is timestamped and versioned;
4. final send receives a single-use human-challenge proof; and
5. the backend binds those proofs, recipients, address, subject, and message to
   a five-minute opaque send authorization and idempotency key.

`PreviewContactCongressVerificationGateway` exercises this sequence locally and
labels it as a development preview. It does not send email, call a bot provider,
or produce a production authorization. A production HTTPS implementation must
replace it before direct delivery is enabled.

## Status mapping rule

Do not map an HTTP success to `delivered`. Use `acceptedForRouting` only when
the approved chamber documentation says the acknowledgement means gateway
acceptance for routing. Reserve `delivered` until a chamber provides an
authoritative status with that meaning. A timeout or unknown response becomes
`failed`, never success. The app keeps the draft available and shows the affected
office separately for retry or follow-up.

## Required backend controls before enabling live delivery

- confirmed constituent email and explicit authorization evidence;
- server-side bot/risk checks and rate limits;
- a persistent unique constraint on the idempotency key;
- pass-through delivery by default, on-device retry, content-minimized receipts,
  audit events, and circuit breakers;
- configurable chamber/office suspension and a global kill switch;
- documented encryption, retention, deletion, and incident response;
- sandbox acceptance followed by production approval for each chamber.

The backend storage boundary and short-lived proof design are defined in the
[privacy-minimal protocol](CONTACT_CONGRESS_PRIVACY_MINIMAL_PROTOCOL.md).

The in-memory Flutter idempotency wrapper prevents repeat taps during one app
session. It is a UX safeguard, not the authoritative deduplication control.
