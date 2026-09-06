#!/usr/bin/env python3
"""
extract_eo_summaries.py
Extracts authentic, substantive policy and purpose summaries directly from
the official Federal Register full text for executive orders.
"""

import json
import os
import re
import sys
import time
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed

DATA_FILE = os.path.join(os.path.dirname(__file__), '..', 'assets', 'data', 'executive_orders.json')

HEADERS = {
    'User-Agent': 'USARepresentativeMap/2.0 (CivicEducationApp; contact@usa-reps.local)'
}

def clean_text(text):
    text = re.sub(r'<[^>]+>', ' ', text)
    text = text.replace('``', '"').replace("''", '"')
    text = text.replace('`', "'")
    text = text.replace('\r', ' ').replace('\n', ' ')
    text = re.sub(r'\s+', ' ', text)
    # Fix hyphenated line wraps (e.g. "well- established" -> "well-established")
    text = re.sub(r'(\w+)-\s+(\w+)', r'\1-\2', text)
    return text.strip()

def extract_summary(raw_text, title, order_num):
    cleaned = clean_text(raw_text)

    # 1. Look for national emergency / national security "finds that" preamble
    find_match = re.search(
        r'(?:find|finds)\s+that\s+(.+?)(?:I hereby declare|Accordingly,?\s+I hereby order|hereby ordered)',
        cleaned,
        re.IGNORECASE
    )
    if find_match and len(find_match.group(1).strip()) > 50:
        findings = find_match.group(1).strip()
        findings = re.sub(r'^(?:the\s+)?', '', findings)
        findings = findings[0].upper() + findings[1:]
        # Extract Sec 1 action if available
        sec1_action = ''
        sec1_m = re.search(r'(?:Section\s*1\.|Sec\.\s*1\.)\s*(.+?)(?=(?:Sec\.\s*2|Section\s*2|\bSec\.\s*2\b|\Z))', cleaned, re.IGNORECASE)
        if sec1_m:
            first_sent = sec1_m.group(1).strip().split('.')[0].strip()
            if 20 < len(first_sent) < 180 and not first_sent.lower().startswith('policy'):
                sec1_action = f' Directs that {first_sent.lower()}.'
        summary = f"Finds that {findings}.{sec1_action}"
        sentences = [s.strip() for s in re.split(r'(?<=[.!?])\s+', summary) if s.strip()]
        res = ' '.join(sentences[:3])
        if len(res) > 420:
            res = res[:417].rsplit(' ', 1)[0] + '...'
        if len(res) > 40:
            return res

    # 2. Look for Section 1 / Sec. 1 (Policy / Purpose / Background / General)
    sec1_match = re.search(
        r'(?:Section\s*1\.|Sec\.\s*1\.)\s*([^=\n\r]+?[\.\:\-])\s*(.+?)(?=(?:Sec\.\s*2|Section\s*2|\bSec\.\s*2\b|\bSection\s*2\b|\Z))',
        cleaned,
        re.IGNORECASE
    )
    if sec1_match:
        heading = sec1_match.group(1).strip().rstrip('.:-')
        body = sec1_match.group(2).strip()
        # Clean out redundant prefix
        body = re.sub(r'^(?:Policy|Purpose|Background|Findings|General Policy|Scope)[\.\:\-]?\s*', '', body, flags=re.IGNORECASE)
        sentences = [s.strip() for s in re.split(r'(?<=[.!?])\s+', body) if s.strip()]
        res = ' '.join(sentences[:3])
        if len(res) > 420:
            res = res[:417].rsplit(' ', 1)[0] + '...'
        if len(res) > 40:
            if heading.lower() not in ['sec', 'section', 'policy', 'purpose'] and len(heading) < 30:
                return f"{heading}: {res}"
            return res

    # 3. Look for 'in order to ... it is hereby ordered'
    in_order_m = re.search(
        r'(?:and\s+)?in order to\s+(.+?)(?:,\s*it is hereby ordered|\.\s*It is hereby ordered)',
        cleaned,
        re.IGNORECASE
    )
    if in_order_m:
        goal = in_order_m.group(1).strip()
        goal = goal[0].upper() + goal[1:]
        # Also grab what is ordered
        after_order = re.search(r'it is hereby ordered(?:\s+that|\s+as follows)?:?\s*(.+?)(?=(?:Sec\.\s*2|Section\s*2|\Z))', cleaned, re.IGNORECASE)
        directive = ''
        if after_order:
            dir_sent = after_order.group(1).strip().split('.')[0].strip()
            if 15 < len(dir_sent) < 200:
                directive = f" Directs that {dir_sent.lower()}."
        res = f"In order to {goal.lower()}.{directive}"
        if len(res) > 400:
            res = res[:397].rsplit(' ', 1)[0] + '...'
        if len(res) > 40:
            return res

    # 4. Look for direct text following 'it is hereby ordered as follows:'
    hereby_m = re.search(
        r'it is hereby ordered(?:\s+as follows)?:\s*(.+?)(?=(?:Sec\.\s*2|Section\s*2|\Z))',
        cleaned,
        re.IGNORECASE
    )
    if hereby_m:
        body = hereby_m.group(1).strip()
        body = re.sub(r'^(?:Section\s*1|Sec\.\s*1)[\.\:\-]?\s*', '', body, flags=re.IGNORECASE)
        sentences = [s.strip() for s in re.split(r'(?<=[.!?])\s+', body) if s.strip()]
        res = ' '.join(sentences[:3])
        if len(res) > 420:
            res = res[:417].rsplit(' ', 1)[0] + '...'
        if len(res) > 40:
            return res

    return None

def fetch_order_text(eo):
    url = eo.get('url', '')
    m = re.search(r'/documents/(\d{4}/\d{2}/\d{2})/([^/]+)/', url)
    if not m:
        return None
    date_path, doc_num = m.group(1), m.group(2)
    txt_url = f"https://www.federalregister.gov/documents/full_text/text/{date_path}/{doc_num}.txt"
    
    for attempt in range(3):
        try:
            req = urllib.request.Request(txt_url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=12) as response:
                if response.status == 200:
                    return response.read().decode('utf-8', errors='ignore')
        except urllib.error.HTTPError as e:
            if e.code == 404:
                # Try JSON API endpoint as fallback
                try:
                    json_url = f"https://www.federalregister.gov/api/v1/documents/{doc_num}.json"
                    jreq = urllib.request.Request(json_url, headers=HEADERS)
                    with urllib.request.urlopen(jreq, timeout=10) as jres:
                        jdata = json.loads(jres.read().decode('utf-8', errors='ignore'))
                        body_html_url = jdata.get('body_html_url')
                        if body_html_url:
                            hreq = urllib.request.Request(body_html_url, headers=HEADERS)
                            with urllib.request.urlopen(hreq, timeout=10) as hres:
                                return hres.read().decode('utf-8', errors='ignore')
                except Exception:
                    pass
                return None
            time.sleep(1.0)
        except Exception:
            time.sleep(1.0)
            
    return None

def process_order(eo):
    title = eo.get('title', '')
    order_num = eo.get('orderNumber', '')
    raw_text = fetch_order_text(eo)
    if raw_text:
        summary = extract_summary(raw_text, title, order_num)
        if summary and len(summary) > 40:
            return eo['id'], summary
    return eo['id'], None

def main():
    if not os.path.exists(DATA_FILE):
        print(f"Error: Could not find {DATA_FILE}")
        sys.exit(1)

    with open(DATA_FILE, 'r', encoding='utf-8') as f:
        orders = json.load(f)

    print(f"Loaded {len(orders)} executive orders from {DATA_FILE}")
    print("Starting automated extraction from Federal Register...")

    order_map = {eo['id']: eo for eo in orders}
    updated_count = 0
    start_time = time.time()

    # Process using thread pool
    max_workers = 12
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_id = {executor.submit(process_order, eo): eo['id'] for eo in orders}
        total = len(orders)
        completed = 0

        for future in as_completed(future_to_id):
            completed += 1
            eo_id = future_to_id[future]
            try:
                result_id, new_summary = future.result()
                if new_summary:
                    order_map[result_id]['summary'] = new_summary
                    updated_count += 1
            except Exception as e:
                pass

            if completed % 50 == 0 or completed == total:
                elapsed = time.time() - start_time
                print(f"Progress: {completed}/{total} processed ({updated_count} summaries extracted) [{elapsed:.1f}s]")
                # Periodic save
                with open(DATA_FILE, 'w', encoding='utf-8') as f:
                    json.dump(orders, f, indent=2)

    # Final write
    with open(DATA_FILE, 'w', encoding='utf-8') as f:
        json.dump(orders, f, indent=2)

    print(f"\nCompleted! Successfully extracted authentic summaries for {updated_count}/{len(orders)} orders.")
    print(f"Updated dataset saved to {DATA_FILE}")

if __name__ == '__main__':
    main()
