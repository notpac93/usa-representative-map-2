#!/usr/bin/env python3
import json
import re
import os
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

DATA_FILE = os.path.join(os.path.dirname(__file__), '..', 'assets', 'data', 'executive_orders.json')
OUT_FILE = os.path.join(os.path.dirname(__file__), '..', 'assets', 'data', 'executive_orders_text.json')

with open(DATA_FILE) as f:
    orders = json.load(f)

# The most recent 350 orders (all 2026 and 2025 orders)
targets = orders[:350]
print(f"Targeting {len(targets)} most recent orders...")

headers = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'}

existing = {}
if os.path.exists(OUT_FILE):
    try:
        with open(OUT_FILE) as f:
            existing = json.load(f)
        print(f"Already have {len(existing)} orders cached.")
    except Exception:
        existing = {}

to_fetch = [eo for eo in targets if eo['id'] not in existing]
print(f"To fetch: {len(to_fetch)}")

def clean_page_text(text):
    text = re.sub(r'<[^>]+>', '', text)
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

def fetch_eo(eo):
    eoid = eo['id']
    url = eo.get('url', '')
    m = re.search(r'/documents/(\d{4}/\d{2}/\d{2})/([^/]+)/', url)
    if not m:
        return eoid, None
    date_path, doc_num = m.group(1), m.group(2)
    txt_url = f"https://www.federalregister.gov/documents/full_text/text/{date_path}/{doc_num}.txt"
    for _ in range(2):
        try:
            req = urllib.request.Request(txt_url, headers=headers)
            with urllib.request.urlopen(req, timeout=6) as resp:
                raw = resp.read().decode('utf-8', errors='ignore')
                splits = re.split(r'\[\[Page\s+(\d+)\]\]', raw)
                pages = []
                if len(splits) > 2:
                    for i in range(1, len(splits), 2):
                        fr_page = splits[i]
                        ptext = splits[i+1]
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
            time.sleep(0.5)
    return eoid, None

t0 = time.time()
with ThreadPoolExecutor(max_workers=15) as ex:
    futs = {ex.submit(fetch_eo, eo): eo['id'] for eo in to_fetch}
    done = 0
    for fut in as_completed(futs):
        eoid, pages = fut.result()
        if pages:
            existing[eoid] = pages
        done += 1
        if done % 50 == 0:
            print(f"Done {done}/{len(to_fetch)} (total {len(existing)}) in {time.time()-t0:.1f}s")
            # Save incrementally
            with open(OUT_FILE, 'w') as f:
                json.dump(existing, f)

with open(OUT_FILE, 'w') as f:
    json.dump(existing, f)

print(f"Completed! Total {len(existing)} orders saved to {OUT_FILE}")
