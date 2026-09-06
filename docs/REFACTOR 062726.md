Keep React/Tailwind for the UI, because building detail sheets and lists in Rust is currently more painful than it's worth.
Rewrite the data ingestion/processing scripts in Rust so you can process the entire TIGER 2025 dataset in seconds instead of minutes, without memory crashes.
Wrap the React app in Tauri (Rust) if you want to distribute it as an offline-first desktop/mobile app. This gives you the performance of Rust for local data querying/searching and the UI velocity of React.


Wikidata and Wikipedia APIs are 100% free forever. They are run by the non-profit Wikimedia Foundation and do not have paid tiers or usage costs.
Lets do it then.

1. The @unitedstates Project (Community-Maintained Flat Files)
https://unitedstates.github.io

2. "Dumb" HTTP Scraping (Cheerio or BeautifulSoup)
In Python (or Rust): You use BeautifulSoup (Python) or scraper (Rust).
Why it's better: It takes milliseconds instead of seconds. It requires virtually zero overhead. It doesn't need to install browser binaries. It is still susceptible to layout changes (brittleness), but it is 100x faster and easier to maintain than Playwright.