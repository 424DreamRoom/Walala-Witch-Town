"""Download only the selected public CC0 packs; retain originals and license pages."""
import hashlib
from pathlib import Path
import urllib.request
import zipfile

BASE = Path(__file__).resolve().parent
PACKS = {
    "jrpg_calm": (
        "https://opengameart.org/content/jrpg-pack-4-calm",
        "https://opengameart.org/sites/default/files/JRPG%20Music%20Pack%20%234%20%5BCalm%5D%20by%20Juhani%20Junkala_0.zip",
    ),
    "organic_ui": (
        "https://opengameart.org/content/51-ui-sound-effects-buttons-switches-and-clicks",
        "https://opengameart.org/sites/default/files/UI_SFX_Set.zip?download=1",
    ),
}


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 WalalaAudioRefresh"})
    with urllib.request.urlopen(request, timeout=45) as response:
        data = response.read(24 * 1024 * 1024 + 1)
    if len(data) > 24 * 1024 * 1024:
        raise ValueError("Download exceeds 24 MiB")
    return data


def main():
    for name, (page, download) in PACKS.items():
        evidence = BASE / "Licenses" / (name + "_20261011.html")
        archive = BASE / "Archives" / (name + ".zip")
        if not evidence.exists():
            evidence.write_bytes(fetch(page))
        if not archive.exists():
            data = fetch(download)
            if not data.startswith(b"PK"):
                raise ValueError("Expected ZIP")
            archive.write_bytes(data)
        print(name, hashlib.sha256(archive.read_bytes()).hexdigest(), flush=True)
        with zipfile.ZipFile(archive) as pack:
            for item in pack.infolist():
                print(item.filename, item.file_size)
            for item in pack.namelist():
                if item.lower().endswith(".txt"):
                    print(pack.read(item).decode("utf-8", errors="replace"))


if __name__ == "__main__":
    main()
