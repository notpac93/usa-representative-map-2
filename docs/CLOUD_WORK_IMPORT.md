# Saved UI work integrated into the local app

On November 20, 2026, the local app incorporated the saved UI work in commit
`a801844b5842d4c488900fd326af67965173f7ef` ("Codex worktree snapshot: startup-cleanup").
Its parent is `281aeafa0d4942392c7d32033539d5b5f23a6021`; it was a separate
line of work from the newer `main` branch and had not been merged into it.
Updating only the officials asset therefore did not bring these screens into
the installed app.

The complete snapshot change was applied with a three-way merge. Conflicts in
the home and location screens use the saved navigation and layouts while
preserving newer official-records access, entity details, and election lifecycle
rules. Newer federal, governor, historical data, and chart code remain present.

## Visible changes

- Home: restored shared light label surfaces, navy styling, branch artwork,
  rotating congressional portraits, and expanding image transitions.
- Map: restored blue map styling, dedicated map page, finder shortcut, reset
  control, and removal of the overlaid branch panels. The home map artwork
  expands into this destination.
- Leaders: portraits rotate every eight seconds, and previous portrait choices
  are remembered to prefer a different trio on later visits. This decoration
  does not identify a user's matched representatives.
- Find My Reps: dedicated location search, representatives first, address-based
  House district lookup, and separate exploration/election/voting pages.
- Messaging: Direct Message buttons on congressional listings and individual
  profiles. Newer verified profiles retain this action only for the matching
  serving person. A subsequent requested change restores a prominent home
  **Contact My Reps** button opening the address-first constituent flow.

The selected officials data is still the reviewed archive snapshot documented
in `GOVERNMENT_DATA_CHECK.md`, with explicit incoming/certification gaps.
Past election dates remain historical; they are not reused as upcoming
deadlines. Data checks remain manual and separate from app releases.

## Verification

The restored home, map, and finder were inspected in the browser. Tests cover
home routes, image transitions, portrait rotation and selection, keyboard focus,
representatives-first navigation, district matching, and individual messaging.
The iPhone release build succeeded, and its bundled officials dataset,
congressional roster, and branch artwork matched the local source assets byte
for byte. The release was installed and launched on the connected iPhone Max.

## Follow-up finder and audit status

The finder now requests input focus once its entry transition completes,
retains that focus and entered text through keyboard resizing, and centers its
title and search controls in the page while keeping the portrait background.
The map uses collision-aware state labels and defers city labels until zoomed.

All 161 app tests pass after these changes. The changed application files
have no analyzer errors; two style notices remain in the map renderers.

## Completed cloud chat audit

The signed-in browser exposed the actual cloud chats on November 20, 2026:

- [Improve mobile map layout](https://chatgpt.com/local/6b007653-ea8c-83ea-942a-c2de927bd035)
- [Build Official Congress Vote Data](https://chatgpt.com/local/6b0080a3-46b8-83e8-87ed-5942bde64011)

Their latest complete patches are preserved in `docs/cloud-import/2026-11-20/`:
`mobile-contact.patch` and `iphone-build.patch`. These patches were saved in
cloud workspaces and were never applied to the local checkout. The older
startup-cleanup snapshot was not a replacement for these changes.

The combined patch contains three commits: official congressional roll calls,
the bottom home contact button, and the approved state explorer with focused
House/Senate rosters. The earlier mobile patch adds matching colors, rotating
portraits, direct entry to location search, representatives first, and direct
Contact actions on previews and profiles.

All patch changes have now been reviewed and integrated. The current centered
finder and automatic focus preserve the user's later requests; the established
portrait transitions and verified official profiles remain intact. The explorer
uses the same map artwork on the landing tile and full map, selects a state on
first tap, opens its page on a second tap or its name, and opens the appropriate
state/chamber roster from each seat count. The House district lookup remains
address-based rather than treating every state House member as a user's match.

Validation: 168 app tests and 155 pipeline tests pass. The source analyzer has
no errors; existing warnings and style notices remain.

### Roll-call data delivery limitation

The new screens and collector are present, but the `congress-votes-data` branch
has not been published. A local collection reached the House session archive
before an official source returned HTTP 403. No partial or synthetic vote feed
was published. The UI's unavailable/retry state remains accurate until the first
verified feed is published. The imported GitHub workflow is saved locally; it
has not been pushed or enabled by this integration. No production data service
or App Store release was published.
