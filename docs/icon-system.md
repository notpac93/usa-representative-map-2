# Civic icon system

The app uses Material Symbols Rounded through `CivicIcons`. Product code should
import `lib/design/civic_icons.dart` and should not import the icon package
directly.

## Visual rules

- Use the rounded style throughout the consumer experience.
- Pair every unfamiliar icon with a short text label. Never make the user guess.
- Use filled icons for the selected navigation item and delivery success only.
- Put primary feature icons in a soft, tinted 44–56 px container; keep utility
  icons such as back, close, edit, and chevrons uncontained.
- Use one icon per action. Decorative images and official portraits carry the
  emotional storytelling; icons carry navigation and meaning.
- Keep touch targets at least 44×44 logical pixels even when the visible icon is
  20–24 px.
- Do not encode success, warning, or failure with color alone. Pair the icon with
  a plain-language status.

## Approved vocabulary

| Product meaning | `CivicIcons` name | Typical placement |
| --- | --- | --- |
| Home | `home` | Bottom navigation |
| Explore the map | `explore` | Home action |
| Write a message | `write` | Main action / bottom navigation |
| Message history | `activity` | Bottom navigation |
| Find | `search` | Search field and find action |
| Home address | `homeAddress` | Address matching |
| Current location | `useMyLocation` | Address shortcut |
| Congressional district | `district` | Match explanation |
| Match complete | `matched` | Address result |
| Congress | `congress` | Federal branch entry point |
| Senate | `senate` | Recipient type |
| House | `house` | Recipient type |
| Representative | `representative` | Profile fallback |
| Governor | `governor` | Separate state channel |
| Delegation | `delegation` | Recipient summary |
| Topic | `topic` | Message composer |
| Review | `review` | Preflight step |
| Send | `send` | Final primary action |
| Delivered | `delivered` | Per-office result |
| Receipt | `receipt` | Confirmation/history |
| Privacy | `privacy` | Address explanation |
| Secure | `secure` | Submit reassurance |
| Verified | `verified` | Constituent verification |
| Election | `election` | Election information |
| Ballot | `ballot` | Ballot details |
| Legislation | `legislation` | Bills and laws |
| Phone | `phone` | Office contact method |
| Website | `website` | Official website |
| External link | `externalLink` | Leaves the app |

## Recommended icon-led components

1. Feature action: 52 px tinted icon block, title, one-line explanation, chevron.
2. Trust note: 20 px privacy/verified icon, one sentence, optional “Learn why.”
3. Recipient chip: official portrait first; chamber icon only as a fallback.
4. Status row: delivered/warning/error icon, office name, plain-language result.
5. Empty state: original illustration first, icon only as a secondary cue.

Material Symbols are licensed under Apache 2.0. Keep the dependency and its
license notice in release attribution records.
