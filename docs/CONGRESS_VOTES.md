# Congressional roll calls

In Flutter, open **The United States Congress**, select **Federal Legislation**, and choose **Browse bills and recorded roll calls**. Choose a roll call to see the exact question, announced result, and member-by-member positions. The **Not Voting** filter selects the people explicitly listed in that category by the chamber. Present votes are displayed separately. Vacancies and people absent from the record are excluded from those counts. The vice president's recorded tie-breaker appears separately from senator totals.

## Government sources

| Source | Use |
| --- | --- |
| [House Clerk vote archive](https://clerk.house.gov/Votes) and [House roll-call XML specification](https://xml.house.gov/) | Official House roll-call numbers, questions, results, vote-date member identities, and positions. |
| [Senate roll-call XML directory](https://www.senate.gov/general/common/generic/XML_Availability.htm) | Official Senate session index, questions, results, vote-date positions, and the vice president's tie-breaker when recorded. |
| [GovInfo BILLSTATUS](https://www.govinfo.gov/bulkdata/BILLSTATUS) and [GPO XML user guide](https://github.com/usgpo/bill-status/blob/main/BILLSTATUS-XML_User_User-Guide.md) | Government bill titles, CRS summaries labeled by stage, sponsors, cosponsors, committees, reports, subjects, policy area, related measures, CBO cost estimates, actions, text versions, and law citations when published. |
| [Congress.gov](https://www.congress.gov/) | Official text versions and legislative history for each linked measure. The [Congress.gov API](https://api.congress.gov/) is an official alternative for bill metadata. |

Data starts with the 119th Congress (2025–2026). The collector imports floor roll calls that a chamber explicitly connects to a bill or resolution, including procedural questions and amendments with an identified parent measure. The chamber's structured measure reference is required. Voice votes and unanimous consent can appear in a bill's action history. Neither procedure supplies individual voting positions. Committee votes, nominations, treaties, and votes with no structured bill link are outside the feed.

## Run and verify

Run the read-only pull request check or use the local commands below. Network access to the three official hosts is required. No commercial provider or Congress.gov API key is needed.

```sh
python3 -m unittest discover -s scripts/tests -p test_congress_votes.py
python3 scripts/congress_votes.py --output tmp/congress-data
```

After merge, run **Congressional roll calls** from GitHub Actions for the first publication. The scheduled workflow checks daily at 11:23 UTC. It stores the normalized data on the separate `congress-votes-data` branch. The app reads that public JSON feed, so data updates after the app version containing this feature ships. The check timestamp is displayed in the app and GitHub Actions retains run failures and logs. For a test build, use `--dart-define=CONGRESS_VOTES_FEED_URL=<JSON origin with trailing slash>` to read a different snapshot.

The script joins measures by Congress, type, and number, while preserving chamber, session, and roll number for every vote. The Senate index supplies its complete list of rolls. House discovery uses the Clerk’s year archive and current results list to establish the latest roll number, then verifies every sequentially numbered Clerk XML file through that number. Compare with [House Clerk roll calls](https://clerk.house.gov/Votes) if a session appears stale. The script retries transient source failures and checks member tallies against the official counts. Freshly linked measures can display before the GovInfo record arrives. The Senate sometimes indexes a roll before it posts member details. The feed reports these rolls as pending and retries them on the next refresh. A missing previously published record halts publication for review. Git sends a complete validated snapshot at once and the previous published snapshot stays available if validation or publication fails.
