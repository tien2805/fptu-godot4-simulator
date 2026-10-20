import urllib.request
import urllib.parse
import re
import json

headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}

def search_ddg_images(query):
    # Step 1: get vqd
    url = f"https://duckduckgo.com/?q={urllib.parse.quote(query)}&iax=images&ia=images"
    req = urllib.request.Request(url, headers=headers)
    html = urllib.request.urlopen(req, timeout=10).read().decode('utf-8', 'ignore')
    match = re.search(r'vqd=([0-9-]+)', html)
    if not match:
        match = re.search(r'vqd="([^"]+)"', html)
    if not match:
        print("Could not find vqd")
        return []
    vqd = match.group(1)
    print("Found vqd:", vqd)
    
    # Step 2: call i.js
    api_url = f"https://duckduckgo.com/i.js?l=us-en&o=json&q={urllib.parse.quote(query)}&vqd={vqd}&f=,,,&p=1"
    req2 = urllib.request.Request(api_url, headers=headers)
    resp = urllib.request.urlopen(req2, timeout=10).read().decode('utf-8', 'ignore')
    data = json.loads(resp)
    results = [r['image'] for r in data.get('results', [])[:5]]
    return results

if __name__ == "__main__":
    imgs = search_ddg_images("FPT University Ho Chi Minh Vo Trong Nghia")
    print("Images found:", len(imgs))
    for u in imgs:
        print(" ->", u)
