# Government indicators

The state and governor State/Economy/Housing sections share the offline bundle
`assets/data/government_indicators.json`. Only HTTPS resources hosted by Census,
BEA, and BLS (including their subdomains) are accepted, including redirect targets.
No data keys or third-party data providers are used.

## Refresh

Run `python3 scripts/refresh_government_indicators.py`. The standard-library-only
script discovers the latest annual ACS 1-year summary files and downloads BEA's
annual SAGDP summary and BLS's current/previous-year monthly state series. Run
`python3 -m unittest discover -s scripts/tests -p 'test_government_indicators.py'`
to verify safeguards. A failed source or missing required state stops the refresh
before the previous bundle is replaced. Replacement is atomic. Rebuild the Flutter
app after refreshing; an installed app does not download new releases directly.

The GitHub workflow runs Mondays at 14:20 UTC and supports manual runs. Once this
workflow is on the default branch, it proposes a data refresh PR. GitHub Actions
must be enabled and repository settings must allow Actions to create pull requests.
Merge the refresh PR and rebuild/deploy the app to distribute it. It does not
publish or deploy automatically. A failed refresh is visible in Actions and leaves
the repository's last successful dataset intact.

## Definitions and cadence

- Income: Census B19013 median household income, annual ACS 1-year estimate.
- Rent: Census B25064 median monthly gross rent.
- Home value: Census B25077 median value of owner-occupied housing units.
- Homeownership: derived from B25003 owner-occupied / occupied housing units.
  A margin of error for the derived ratio is not calculated.
- ACS median estimates include their published 90% margins of error. Dollar values
  are in each reporting year's dollars; no inflation-adjusted cross-year change
  is claimed. ACS 1-year coverage here is states/DC, not small city coverage.
- GDP: BEA SAGDP1 line 3, annual current-dollar GDP, millions converted to dollars.
- Real GDP growth: annual percent change computed from SAGDP1 line 1 (chained 2017
  dollars). This is distinct from nominal GDP growth. BEA revises earlier years.
- Unemployment: BLS LASST state series, measure 03; monthly seasonally adjusted
  rates. Excludes M13 annual averages. Retains preliminary footnotes, source IDs,
  and missing months rather than interpolating. Monthly releases may be revised.

Source URLs, file/table/series identifiers, retrieval timestamps, periods, and units
are saved in the bundle. Weekly checks do not imply weekly agency releases.
Population remains a separate historical Census Vintage 2024 snapshot. Governor
activity remains unconnected. Territories outside the supported state/DC data
receive explicit unavailable states, never another state's figures.


## History charts

State and governor State sections share interactive line charts. Population uses
2020–2024 July 1 estimates, BEA GDP includes ten annual observations, unemployment
uses available monthly observations from the current/previous year, and ACS income
and housing use the latest five annual 1-year releases (currently 2021–2025).
The refresh now retrieves the historical ACS files and margins of error as well.
All historical source URLs are retained. Missing/suppressed observations are omitted
and chart lines break across missing months/years. Calendar spacing is proportional.

Dollar history is in each reporting year's dollars, not inflation-adjusted change.
ACS changes are not tested for statistical significance; median margins of error
appear on inspection. Homeownership is a derived rate without a calculated margin
of error. Rate changes use percentage points, other changes use percent. Chart axes
fit observed values with explicit tick labels rather than implying a zero baseline.
Period chips, pointer inspection and an accessible reporting-period selector expose
exact values. No fabricated or interpolated points are added. The experimental 2020
ACS 1-year data is excluded. Weekly refresh, merge and rebuild requirements above
also apply to chart updates.
