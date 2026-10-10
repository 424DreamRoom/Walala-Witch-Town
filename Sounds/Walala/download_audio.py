"""Bounded public HTTP acquisition; all artifacts stay in this new audio directory."""
from pathlib import Path
import urllib.request, re, zipfile, io, hashlib, json
ROOT = Path(__file__).resolve().parent

def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 WalalaAudioLicenseCheck'})
    with urllib.request.urlopen(req, timeout=45) as r:
        data = r.read(24 * 1024 * 1024 + 1)
    if len(data) > 24 * 1024 * 1024: raise ValueError('download limit')
    return data

def page(slug, url):
    data = fetch(url)
    p = ROOT / 'Licenses' / (slug + '.html')
    p.parent.mkdir(parents=True, exist_ok=True)
    if not p.exists(): p.write_bytes(data)
    html = data.decode('utf-8', errors='replace')
    print(slug)
    for field in ('field-name-field-license', 'field-name-field-art-files', 'field-name-field-art-attribution', 'field-name-field-art-author'):
        match = re.search(r'<div class="[^"]*' + field + r'.*?(?=<div class="field field-name|<section|$)', html, re.S)
        if match: print(match.group(0)[:7000])
    print('\n'.join(re.findall(r'href=[\"\']([^\"\']*(?:\.zip|\.ogg|\.mp3|creativecommons)[^\"\']*)', html)))
    return html

if __name__ == '__main__':
    import sys
    for arg in sys.argv[1:]:
        slug, url = arg.split('=', 1)
        page(slug, url)
