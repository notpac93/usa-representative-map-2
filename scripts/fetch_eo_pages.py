#!/usr/bin/env python3
"""
fetch_eo_pages.py
Fetches full verbatim text and page breakdowns for executive orders from Federal Register.
"""

import json
import re
import os
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

DATA_FILE = os.path.join(os.path.dirname(__file__), '..', 'assets', 'data', 'executive_orders.json')
OUT_FILE = os.path.join(os.path.dirname(__file__), '..', 'assets', 'data', 'executive_orders_text.json')

HEADERS = {
    'User-Agent': 'USARepresentativeMap/2.0 (CivicEducationApp; contact@usa-reps.local)'
}

def clean_page_text(text):
    # Strip HTML
    text = re.sub(r'<[^>]+>', '', text)
    # Fix smart quotes
    text = text.replace('``', '"').replace("''", '"').replace('`', "'")
    lines = [line.rstrip() for line in text.splitlines()]
    clean_lines = []
    blank_count = 0
    for l in lines:
        if not l.strip():
            blank_count += 1
            if blank_count <= 2:
                clean_lines.append('')
        else:
            blank_count = 0
            clean_lines.append(l)
    return '\n'.join(clean_lines).strip()

def process_one(eo):
    eoid = eo['id']
    url = eo.get('url', '')
    m = re.search(r'/documents/(\d{4}/\d{2}/\d{2})/([^/]+)/', url)
    if not m:
        return eoid, None
    date_path, doc_num = m.group(1), m.group(2)
    txt_url = f"https://www.federalregister.gov/documents/full_text/text/{date_path}/{doc_num}.txt"
    
    for attempt in range(2):
        try:
            req = urllib.request.Request(txt_url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=8) as resp:
                raw = resp.read().decode('utf-8', errors='ignore')
                
                # Split pages by [[Page XXXXX]]
                splits = re.split(r'\[\[Page\s+(\d+)\]\]', raw)
                pages = []
                if len(splits) > 2:
                    for i in range(1, len(splits), 2):
                        fr_page = splits[i]
                        ptext = splits[i+1]
                        # Check if cover page before actual order
                        if len(pages) == 0 and 'Section 1' not in ptext and 'Sec. 1' not in ptext and len(ptext) < 700:
                            continue
                        clean = clean_page_text(ptext)
                        if clean:
                            pages.append({
                                'pageNumber': len(pages) + 1,
                                'frPage': fr_page,
                                'content': clean
                            })
                if not pages:
                    clean = clean_page_text(raw)
                    pages = [{'pageNumber': 1, 'frPage': '', 'content': clean}]
                return eoid, pages
        except Exception:
            time.sleep(0.3)
    return eoid, None

def main():
    with open(DATA_FILE) as f:
        orders = json.load(f)

    # Prioritize Trump, Biden, Obama
    target = [eo for eo in orders if eo.get('presidentId') in ['donald-trump', 'joe-biden', 'barack-obama']]
    print(f"Targeting {len(target)} orders...")

    results = {}
    if os.path.exists(OUT_FILE):
        try:
            with open(OUT_FILE) as f:
                results = json.load(f)
            print(f"Loaded existing {len(results)} parsed orders.")
        except Exception:
            results = {}

    to_fetch = [eo for eo in target if eo['id'] not in results]
    print(f"Need to fetch: {len(to_fetch)} orders")

    t0 = time.time()
    with ThreadPoolExecutor(max_workers=20) as executor:
        futures = {executor.submit(process_one, eo): eo['id'] for eo in to_fetch}
        done = 0
        for fut in as_completed(futures):
            eoid, pages = fut.result()
            if pages:
                results[eoid] = pages
            done += 1
            if done % 50 == 0:
                print(f"Progress: {done}/{len(to_fetch)} ({len(results)} saved) in {time.time()-t0:.1f}s")

    t1 = time.time()
    print(f"Finished in {t1-t0:.1f}s! Total parsed orders: {len(results)}")

    with open(OUT_FILE, 'w') as f:
        json.dump(results, f)
    
    size_mb = os.path.getsize(OUT_FILE) / (1024 * 1024)
    print(f"Saved {OUT_FILE} ({size_mb:.2f} MB)")

if __name__ == '__main__':
    main()
