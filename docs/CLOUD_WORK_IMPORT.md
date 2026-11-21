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

The user identified two additional Codex Cloud chats: **Build Official Congress
Vote Data** and **Improve mobile map layout**. These chats are not returned by
the connected chat-history or cloud task tools. Browser access requires signing
in to the same cloud account as the phone. Their contents and changes have
**not yet been audited or confirmed as imported**. The local branch/snapshot
audit must not be represented as an audit of these two chats.
