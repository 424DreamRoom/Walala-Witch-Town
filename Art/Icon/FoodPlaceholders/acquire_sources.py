"""Acquire public CC0 archives; existing downloads are kept. No MyArt writes."""
from pathlib import Path
import ssl
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent / "sources"
FILES = {name: "https://opengameart.org/sites/default/files/" + name for name in ["food_0.zip", "food-bluecarrot16_20201221_0.zip", "food-fleurman_0.zip", "food-7soul1_20201212.zip"]}
FILES.update({
    "HenryFood.png": "https://opengameart.org/sites/default/files/Food.png",
    "16x16-food.html": "https://opengameart.org/content/16x16-food",
    "cc0-food-icons.html": "https://opengameart.org/content/cc0-food-icons",
    "henrysoftware-food.html": "https://henrysoftware.itch.io/pixel-food",
})

for filename, url in FILES.items():
    target = ROOT / filename
    if target.is_file() and (not filename.endswith(".zip") or zipfile.is_zipfile(target)):
        continue
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=20, context=ssl.create_default_context()) as response:
        data = response.read()
    from io import BytesIO
    if filename.endswith(".zip"): assert zipfile.is_zipfile(BytesIO(data)), url
    if filename.endswith(".png"): assert data.startswith(b"\x89PNG\r\n\x1a\n"), url
    target.write_bytes(data)
    print("DOWNLOADED", filename, len(data))
