# Congressional data: collect ahead of use

Updated: 2026-10-16

The app ships with a prepared congressional directory. Browsing, opening an
official's profile, and drafting to that selected office do not fetch government
rosters or call Census. Data collection is a development/release operation.
The eventual delivery backend will use its already-published recipient/route
configuration, not scrape or refresh government data when a user presses Send.
Authorization and receipt processing are delivery operations, not data collection.

## Official bulk sources actually downloaded

| Source | What the downloaded source supplies | What it does not supply |
| --- | --- | --- |
| [House Clerk member XML](https://clerk.house.gov/xml/lists/MemberData.xml) | All 441 seats, member names, Bioguide IDs, state/district, party, office address/phone, sworn dates, explicit vacancy notes, Congress and publication date | Member websites, public email inboxes, fax numbers, delivery credentials |
| [House directory](https://www.house.gov/representatives) | All state/territory delegations and member website links in one HTML download | Uniform direct messaging endpoints or a bulk fax/email list |
| [Senate contact XML](https://www.senate.gov/general/contact_information/senators_cfm.xml) | 100 senators, names, Bioguide IDs, state/class, party, office address/phone, websites, contact links | Delivery credentials, fax numbers, verified public email inboxes, explicit source publication date |

The House XML identifies American Samoa's seat as `AQ00` but uses postal code
`AS` in the state element; the import explicitly normalizes that seat to `AS00`.
The Senate field named `email` contains URLs in this download. It is imported as
`contactUrl`, never as an SMTP destination. Some links are home pages rather than
direct contact forms. The importer preserves published HTTP URLs rather than
claiming untested HTTPS support.

Documentation: [House XML guide](https://clerk.house.gov/member_info/MemberData_UserGuide.pdf)
and [Senate XML catalog](https://www.senate.gov/general/XML.htm).
The House also explains that it has
[no central listing of public member email addresses](https://www.house.gov/representatives/find-your-representative).
These are the federal sources; state/local officials require separate official
sources and are not covered by this import.

## Files and repeatable commands

- `data/sources/congress/`: compressed original responses and a manifest of
  official source URLs, retrieval time, byte counts, and SHA-256 hashes.
- `scripts/refresh_congress.py`: dependency-free Python import and validation.
- `assets/data/congressional_roster.json`: one atomically published app snapshot.
- `lib/data/congressional_roster.dart`: local asset loader shared by the map and
  Congress directory. There is no network client in this loader.
- Legacy `houseMembers.json` and `senators.json` files remain as portrait metadata
  input, joined by Bioguide ID only. They no longer determine the Flutter roster.

Rebuild from the saved official downloads, fully offline:

```sh
npm run data:congress:build
```

Fetch fresh official bulk downloads, validate, and update the embedded snapshot:

```sh
npm run data:congress:refresh
```

Inspect without publishing:

```sh
python3 scripts/refresh_congress.py --congress 119
```

The expected Congress is explicit. Update the command only after reviewing a
Congress rollover, effective district geography, and source schema. A refresh
does not submit messages or probe congressional contact forms. No cron job or
hosted automation has been installed. The refresh command can later run in a
controlled release/maintenance job, independently of user requests.

## Publication checks

The import requires the complete 2020-apportionment House seat inventory,
including six delegate/resident-commissioner seats, and two Senate seats per
state. It rejects duplicate seats/identities, unexpected state codes, missing
members without vacancy evidence, unreviewed Congress changes, and external
website hosts. House XML and directory must agree on the seat and occupant
before attaching a website. Middle initials may differ; surname and first given
name must agree. Senate missing-seat cases stop for review because that source's
vacancy format is not established here. Do not fill them with an old senator.

All three inputs must parse and pass checks before publishing. A failed download
or validation leaves the app snapshot untouched. The output is a single atomic
file replacement; existing source snapshots and app versions are recoverable
through Git. Offline rebuilding retains the original retrieval timestamp.
Optional portraits are preserved only for the same Bioguide ID; changed members
never inherit their predecessor's image.

This snapshot contains 439 occupied House seats, two House vacancies, and 100
senators. The Clerk source is marked published October 1, 2026. The original
manifest records the UTC download timestamp separately. Counts describe this
saved snapshot, not a permanent assumption about occupancy.

## Existing contact workflow

An individual senator/representative profile now opens the existing composer
with that person selected. This directory path does not resolve a district and
does not claim the sender is that office's constituent. It collects the sender's
own state separately from the selected office's state. It remains an explicitly
labeled local preview; a future live adapter must establish recipient eligibility
and required fields before this path can transmit.

The separate **Find my members** path still uses the existing Census address
resolver when the user explicitly asks to discover their own district. That is
not necessary for directory-selected drafting and is not a send-time roster
refresh. Replacing that optional address resolver with local geometry is separate
work; the old cd116 map overlay is not approved for accurate current matching.

## What still blocks real sending

The user confirmed that no delivery account or congressional approval exists.
The repository has a placeholder delivery gateway and preview verification, not
a configured live provider. The official bulk feeds do not grant delivery access.
No public email or fax destination has been invented or enabled by this import.

The next delivery milestone is confirmed access and a technical contract for
House CWC/Senate SCWC or an alternative delivery provider, including recipient
eligibility, mandatory sender fields, credentials, and receipts. Fax/email also
needs an official destination for each supported office. The existing
[approval quickstart](CWC_SCWC_APPROVAL_QUICKSTART.md) and
[outreach drafts](CWC_SCWC_REQUIREMENTS_OUTREACH.md) remain the starting points;
no application or message has been sent on the user's behalf.

Then implement server-side delivery and verification against the actual contract,
with stored routes, duplicate protection, conservative receipt semantics, and
failure recovery. Selecting any official for a draft does not establish that a
particular delivery channel accepts non-constituent messages.

## Validation

```sh
npm run test:congress-data
flutter test test/congressional_roster_test.dart test/contact_congress_screen_test.dart
```

The import tests exercise complete coverage, vacancies, duplicate identities,
partial responses, conflicting occupants, unofficial URLs, rollover rejection,
portrait identity, deterministic offline rebuilds, and failed publication. The
directory-contact widget test verifies no district lookup and truthful Not sent
results. Neither test suite claims real delivery has occurred.

Verification on 2026-10-16: the real `--download` command completed against all
three official sources into a temporary validation directory; 11 import tests and
33 focused Flutter tests passed, and `flutter build web --no-pub` succeeded.
The full Flutter suite had 67 passes and two failures in unchanged local-detail
tests (horizontal overflow and missing expected labels). Targeted analysis found
existing style/deprecation notices in surrounding screens; no compile errors.
