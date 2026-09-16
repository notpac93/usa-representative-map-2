# Contact Congress Delivery Contract

Status: one-submit client flow implemented; direct delivery intentionally disabled

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

The application backend—not this repository—must implement one adapter per
approval and protocol:

1. `HouseCwcAdapter`: validate the approved House fields, map the internal
   request to the supplied schema, submit using server-held credentials, and
   translate the acknowledgement into one typed office result.
2. `SenateScwcAdapter`: do the equivalent using the approved Senate SOAPBox
   contract and credentials.
3. `CongressionalDeliveryGateway`: authenticate the app user, verify email and
   abuse-control tokens, enforce persistent idempotency, route each recipient
   to the correct adapter, and return results separately for every office.

The Flutter implementation can replace the placeholder only with a gateway
that calls this application-owned backend over HTTPS. It must not choose an
adapter or hold chamber configuration locally.

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
