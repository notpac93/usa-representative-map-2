# Contact Congress Abuse and Verification Plan

Status: Product and security baseline; live enforcement requires the application backend and chamber approval.

## Product Decision

Do not require device location to contact Congress. A location ping shows where a device is at one moment; it does not establish identity, home ownership, or residency. It is also unavailable or inappropriate for many legitimate constituents.

Offer one-time device location only as an optional, user-initiated address autofill convenience. Denying it must never block address entry, district matching, review, or sending.

Use this baseline before a first live send:

1. Match the entered address to one current congressional district.
2. Confirm control of the reply email with a magic link or one-time code.
3. Capture the constituent's explicit residency and message authorization attestation.
4. Validate a managed human challenge at final send when the risk engine requests it.
5. Bind those signals, the recipients, and the message hash to a short-lived server send intent.

These checks confirm an address, an inbox, and an affirmative claim. The UI must not call them identity or residency proof.

## Threats in Scope

- automated or scripted message floods;
- repeated or near-duplicate messages to the same office;
- stolen or fabricated constituent email details;
- direct threats of violence, targeted incitement, doxxing, or extortion;
- header, XML, control-character, URL, and payload injection;
- bypass attempts using IP rotation, reinstalling, or minor text changes;
- accidental duplicates caused by taps, retries, or delivery timeouts.

Strong criticism, unpopular political views, references to violence in policy discussion, personal stories, and ordinary profanity are not by themselves prohibited content.

## Server-Side Send Pipeline

1. Normalize Unicode and whitespace without rewriting the constituent's meaning.
2. Enforce the approved chamber field and length limits.
3. Reject control characters, markup/header injection, unsupported attachments, and excessive links.
4. Restrict recipients to the current official roster and the address-matched delegation.
5. Verify the email, send intent, attestation, challenge token, and idempotency key.
6. Apply rate and near-duplicate checks across several privacy-preserving signals.
7. Run a narrowly scoped safety classifier for direct threats, targeted incitement, doxxing, and extortion.
8. Send only after every server-side check passes; record a content-minimized event and return an office-specific status.

Do not use a simple keyword blacklist. High-confidence prohibited content is blocked with a neutral explanation and an opportunity to revise. Ambiguous content is not transmitted automatically; it enters a short review or re-verification path. Classifier output alone must not create a permanent ban.

## Provisional Pilot Limits

These are conservative product defaults until House CWC and Senate SCWC provide binding volume rules and pilot data supports tuning:

| Scope | Initial limit | User experience |
| --- | --- | --- |
| Same or near-duplicate message to the same office | 1 accepted copy per rolling 7 days | Explain that the office already received substantially the same message and preserve the draft |
| Different messages to the same office | 1 per 24 hours, 3 per 7 days, 10 per 30 days | Show the next eligible time before final send |
| One-submit actions across the matched delegation | 10 per rolling 30 days | Re-verify before a higher-risk exception; do not silently discard |
| Failed challenge or malformed payload attempts | Progressive 30-second to 1-hour cooldown | Retry guidance without revealing risk signals |
| Duplicate tap or network retry | Exactly one result per idempotency key | Return the original office results |

The limits apply per verified email and recipient, with supporting checks on a keyed address fingerprint, signed installation token, network risk, message similarity, and campaign pattern. Never ban solely by IP or device signal because networks and devices can be shared.

## Progressive Enforcement

- **Normal:** quiet checks; most people see only first-send email confirmation.
- **Elevated risk:** require managed challenge and fresh email confirmation.
- **Repeated prohibited attempts:** block the attempted message and apply a 24-hour send cooldown.
- **Confirmed repeated abuse:** extend the verified-email/address-recipient cooldown to 7 days, then at most 30 days for sustained abuse.
- **Coordinated attack:** quarantine the campaign pattern, open the adapter circuit breaker, or use the global send kill switch.

Every cooldown needs a visible reason category, expiry time, and support/appeal path. A user may continue editing and saving the draft while sending is unavailable.

## Privacy and Retention

- Keep raw name, address, email, and message only in the encrypted delivery queue; purge within 24 hours of terminal success or after a maximum 72-hour retry window.
- Rate-limit addresses with a rotating keyed HMAC retained for no more than 30 days.
- Use a random, signed installation token—not a durable hardware fingerprint—and rotate it at least every 30 days.
- Keep coarse abuse events and delivery status without raw content for the documented operations period.
- Never put message text, subject, address, email, precise location, or challenge tokens in analytics, traces, crash reports, or session replay.

## Current Implementation Boundary

The Flutter prototype currently provides field-length validation, official-recipient restriction, explicit attestation, and in-session idempotency. It does not yet provide authoritative email verification, bot scoring, moderation, persistent limits, bans, or chamber delivery. Those controls must live in the server-side send gateway before direct delivery is enabled.

## References

- [House CWC program and application](https://www.house.gov/doing-business-with-the-house/communicating-with-congress-cwc)
- [Senate SCWC overview](https://www.senate.gov/senators/scwc.htm)
- [Senate SCWC Terms of Service](https://soapbox.senate.gov/registration/terms-of-service/)
- [Apple location privacy guidance](https://developer.apple.com/documentation/corelocation/configuring-your-app-to-use-location-services)
- [Android guidance to minimize permission requests](https://developer.android.com/privacy-and-security/minimize-permission-requests)
- [Cloudflare Turnstile overview](https://developers.cloudflare.com/turnstile/)
- [OWASP resource quota and rate-limit guidance](https://owasp.org/www-project-top-10-for-business-logic-abuse/docs/the-top-10/resource-quota-violation)
