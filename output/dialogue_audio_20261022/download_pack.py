from pathlib import Path
import http.cookiejar
import json
import re
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
EVIDENCE = ROOT / 'Sounds/Walala/Dialogue/Licenses'
EVIDENCE.mkdir(parents=True, exist_ok=True)
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
source = 'https://dillonbecker.itch.io/sdap'
page = opener.open(source, timeout=30).read()
(EVIDENCE / 'author_page_20261022.html').write_bytes(page)
csrf = re.search(rb'<meta name="csrf_token" value="([^"]+)"', page)
if not csrf:
    csrf = re.search(rb'name="csrf_token" content="([^"]+)"', page)
assert csrf, 'No public download form CSRF token'
data = urllib.parse.urlencode({'csrf_token': csrf[1].decode()}).encode()
request = urllib.request.Request(source + '/file/2138920', data=data, headers={'Referer': source})
result = json.load(opener.open(request, timeout=30))
assert 'url' in result, result
target = OUT / 'Super Dialogue Audio Pack v1.zip'
with opener.open(result['url'], timeout=45) as response, target.open('wb') as output:
    while block := response.read(1024 * 1024):
        output.write(block)
        print(output.tell(), flush=True)
print('DOWNLOADED', target, flush=True)
license_url = 'https://creativecommons.org/licenses/by/4.0/legalcode.txt'
(EVIDENCE / 'CC-BY-4.0.txt').write_bytes(opener.open(license_url, timeout=30).read())
