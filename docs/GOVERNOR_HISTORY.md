# Governor archive

Governor Details → History and State → History show an offline archive saved in
`assets/data/governor_history.json`. The current snapshot has **1,584 people and
1,738 service periods across all 50 states**. State coverage varies significantly;
this is not a complete national roster. Every new state explicitly says its archive
is partial, including gaps inside the displayed date range. California retains its
existing State Library gallery coverage (38 people, 39 periods).

## Saved facts and sources

Names, completed service wording, start/end years, permanent person/service IDs,
government source URLs, verification dates, and identified acting/provisional service
are saved. Nonconsecutive periods remain separate. Dates follow the source’s precision
and conventions: a source ending a tenure in December and one using inauguration-year
boundaries can display different years. Exact transitions are never inferred from a
successor, an election, a forecast, or the current-officeholder feed. Colonial and
territorial sections are excluded from the new imports; state-era source conventions
are retained (including Vermont’s pre-admission elected governors).

Only HTTPS `.gov` sources are accepted. These include state archives, state libraries,
secretaries of state, official manuals, governor offices, and federal government
biographies/resolutions. No NGA, Wikipedia, `.org`, `.edu`, or `.us` records are imported.
Only factual tenure cells/headings are saved; full biographies and historical documents
open at their original government source. Historical contacts are never shown as current.

## Preservation and updates

- `python3 scripts/import_governor_history.py --check` validates the reviewed national facts.
- `python3 scripts/import_governor_history.py` merges the other 49 states from
  `scripts/data/governor_history_reviewed.json` into the durable archive, without network access.
- `python3 scripts/refresh_governor_history.py` fetches California State Library updates;
  redirects are restricted to that library's HTTPS domains.

The national file is a **reviewed snapshot, not an automatic nationwide scraper**.
The sources use HTML tables, PDFs, images, and individually indexed biographies;
some reject automated requests. New national leaders and corrections require a verified
source review and an edit to the reviewed manifest. Keep existing person and service IDs
when correcting facts. Never generate IDs anew for a correction or conflate two people
with similar names. The importer validates the entire file before an atomic replacement.
It never removes existing people/service periods merely because a source/import stops
listing them, and changed fields retain their previous values in `revisions`.

The weekly government-data workflow refreshes California and reapplies the reviewed
national snapshot. Reapplying it is idempotent and does not pretend the national sources
were rechecked. The workflow must be on the default branch; refresh PRs must be merged
and the app rebuilt/distributed before users receive updated bundled records.

## Review gaps

Coverage remains intentionally partial, particularly Georgia, Louisiana, Massachusetts,
Minnesota, New Hampshire, New York, Ohio, Oklahoma, Rhode Island, and Wisconsin. Some
other archives omit short acting periods or stop before recent governors. Omitted rows
include contradictory Arizona Fannin dates, conflicting Arkansas modern summaries,
ambiguous Virginia acting-name cells and Peery/Price dates, Vermont’s conflicting
Gibson Sr./Jr. label, and Washington’s conflicting Ferry end year. These need a second
verified government source before inclusion. Historical manual dates alone do not prove
that the app contains all completed service periods through that year.

## Saved coverage inventory

Counts are saved people and service periods, not a claim of completeness. Each state's
in-app source link and each service period's source URL identify the supporting record.

| State | People | Service periods | Earliest–latest recorded year |
| --- | ---: | ---: | --- |
| AK | 11 | 13 | 1959–2018 |
| AL | 57 | 63 | 1819–2017 |
| AR | 42 | 42 | 1836–2007 |
| AZ | 22 | 25 | 1912–2022 |
| CA | 38 | 39 | 1849–2019 |
| CO | 12 | 16 | 1876–2019 |
| CT | 66 | 70 | 1784–2019 |
| DE | 16 | 17 | 1937–2025 |
| FL | 44 | 45 | 1845–2019 |
| GA | 2 | 2 | 2003–2019 |
| HI | 8 | 8 | 1959–2022 |
| IA | 39 | 41 | 1846–2017 |
| ID | 30 | 32 | 1890–2019 |
| IL | 19 | 21 | 1818–2019 |
| IN | 49 | 51 | 1816–2025 |
| KS | 47 | 47 | 1861–2019 |
| KY | 58 | 62 | 1792–2019 |
| LA | 2 | 2 | 2008–2024 |
| MA | 2 | 2 | 2007–2023 |
| MD | 30 | 30 | 1869–2023 |
| ME | 69 | 73 | 1820–2019 |
| MI | 46 | 48 | 1835–2018 |
| MN | 8 | 9 | 1967–2019 |
| MO | 55 | 57 | 1820–2025 |
| MS | 53 | 63 | 1817–2020 |
| MT | 23 | 23 | 1889–2021 |
| NC | 67 | 120 | 1776–2009 |
| ND | 31 | 32 | 1889–2024 |
| NE | 40 | 43 | 1867–2023 |
| NH | 1 | 1 | 2013–2017 |
| NJ | 12 | 13 | 1962–2026 |
| NM | 27 | 41 | 1912–2019 |
| NV | 30 | 30 | 1864–2023 |
| NY | 10 | 10 | 1915–2010 |
| OH | 2 | 2 | 2007–2019 |
| OK | 6 | 6 | 1915–2019 |
| OR | 37 | 38 | 1859–2023 |
| PA | 42 | 45 | 1790–2023 |
| RI | 1 | 1 | 1963–1969 |
| SC | 50 | 52 | 1787–2011 |
| SD | 31 | 32 | 1889–2019 |
| TN | 46 | 53 | 1796–2003 |
| TX | 44 | 47 | 1846–2015 |
| UT | 17 | 17 | 1896–2021 |
| VA | 74 | 79 | 1776–2026 |
| VT | 75 | 81 | 1778–2011 |
| WA | 20 | 21 | 1893–2013 |
| WI | 13 | 13 | 1882–1977 |
| WV | 28 | 28 | 1863–1977 |
| WY | 32 | 32 | 1890–2019 |
