"""Acquire CC0 world audio and retain sources, license evidence and file hashes.

Only writes Sounds/Walala/World. Requires numpy and soundfile for PCM analysis
and the two WAV/MP3 -> OGG conversions. Never scans or writes MyArt.
"""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "Sounds/Walala"
OUT = BASE / "World"
CC0 = "https://creativecommons.org/publicdomain/zero/1.0/"
SOURCES = {
    "birds": ("https://opengameart.org/content/ambient-bird-sounds", "https://opengameart.org/sites/default/files/birds-isaiah658_0.ogg", "birds.ogg", "isaiah658"),
    "crickets": ("https://opengameart.org/content/crickets-ambient-noise-loopable", "https://opengameart.org/sites/default/files/crickets_1.mp3", "crickets.mp3", "Wolfgang_ / Ted Kerr"),
    "fire": ("https://opengameart.org/content/fireplace-sound-loop", "https://opengameart.org/sites/default/files/fire.wav", "fire.wav", "PagDev"),
    "cooking": ("https://opengameart.org/content/boiling-water-loops", "https://opengameart.org/sites/default/files/cooking_with_cover_01.ogg", "cooking.ogg", "TinyWorlds"),
    "water": ("https://opengameart.org/content/40-cc0-water-splash-slime-sfx", "https://opengameart.org/sites/default/files/water-splash-slime-sfx.zip", None, "rubberduck"),
    "forest": ("https://opengameart.org/content/forest-whisper-theme", "https://opengameart.org/sites/default/files/forest_whisper_theme.zip", None, "Cleyton Kauffman"),
    "calm": ("https://opengameart.org/content/jrpg-pack-4-calm", "https://opengameart.org/sites/default/files/JRPG%20Music%20Pack%20%234%20%5BCalm%5D%20by%20Juhani%20Junkala_0.zip", None, "Juhani Junkala / SubspaceAudio"),
    "rpg": ("https://kenney.nl/assets/rpg-audio", "https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip", None, "Kenney Vleugels"),
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if path.read_bytes() != data:
            raise FileExistsError("Refusing to overwrite different audio: " + str(path))
    else:
        path.write_bytes(data)


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 WalalaWorldAudio"})
    with urllib.request.urlopen(request, timeout=50) as response:
        data = response.read(24 * 1024 * 1024 + 1)
    if len(data) > 24 * 1024 * 1024:
        raise ValueError("Download too large")
    return data


def acquire(item):
    key, (page, url, filename, _) = item
    evidence = OUT / "Licenses" / (key + "_20261020.html")
    if not evidence.exists():
        data = fetch(page)
        if (b"publicdomain/zero/1.0" not in data and b"Creative Commons CC0" not in data):
            raise ValueError("Missing CC0 declaration: " + page)
        save(evidence, data)
    if filename:
        target = OUT / "Sources" / filename
        if not target.exists():
            save(target, fetch(url))


def main():
    OUT.mkdir(exist_ok=True)
    (OUT / "Sources" / ".gdignore").parent.mkdir(exist_ok=True)
    (OUT / "Sources" / ".gdignore").touch()
    (OUT / "Licenses" / ".gdignore").parent.mkdir(exist_ok=True)
    (OUT / "Licenses" / ".gdignore").touch()
    with ThreadPoolExecutor(max_workers=5) as pool:
        list(pool.map(acquire, SOURCES.items()))
    assets = []

    def add(file, source, data, title, gain, category, original_path, member=None, convert=False):
        original = data
        changes = "Original audio bytes; renamed; runtime gain and loop only"
        if convert:
            pcm, rate = sf.read(io.BytesIO(data), always_2d=True)
            # A short cyclic overlap avoids MP3 padding clicks and hard endpoints.
            n = int(rate * 0.12)
            weights = np.linspace(0.0, 1.0, n, endpoint=False)[:, None]
            seam = pcm[-n:] * (1.0 - weights) + pcm[:n] * weights
            pcm = np.concatenate((seam, pcm[n:-n]))
            buffer = io.BytesIO()
            # Bounded chunks also avoid libsndfile's large-buffer stack usage
            # on Windows when encoding long stereo Vorbis recordings.
            with sf.SoundFile(buffer, mode="w", samplerate=rate, channels=pcm.shape[1], format="OGG", subtype="VORBIS") as encoder:
                for offset in range(0, len(pcm), 8192):
                    encoder.write(pcm[offset:offset + 8192])
            data = buffer.getvalue()
            changes = "Decoded to OGG Vorbis; 120 ms cyclic overlap; no pitch or level change"
            # Vorbis serials can differ between encodes. Keep the first verified
            # conversion and compare decoded content when rebuilding.
            existing = OUT / file
            if existing.exists():
                old, old_rate = sf.read(existing, always_2d=True)
                new, new_rate = sf.read(io.BytesIO(data), always_2d=True)
                if old_rate != new_rate or old.shape != new.shape or not np.allclose(old, new, atol=1e-5):
                    raise ValueError("Converted PCM changed: " + file)
                data = existing.read_bytes()
        save(OUT / file, data)
        pcm, rate = sf.read(io.BytesIO(data), always_2d=True)
        page, download, _, author = SOURCES[source]
        assets.append(dict(file=file, title=title, author=author, source=page, download=download,
            license="CC0-1.0", license_url=CC0, license_evidence="Licenses/" + source + "_20261020.html",
            original_file=original_path, archive_member=member, source_sha256=sha(original),
            sha256=sha(data), bytes=len(data), changes=changes, category=category, gain_db=gain,
            duration_seconds=len(pcm)/rate, sample_rate=rate, channels=pcm.shape[1],
            rms_db=float(20*np.log10(np.sqrt(np.mean(pcm*pcm)))),
            peak_db=float(20*np.log10(np.max(np.abs(pcm))))))

    for key, file, gain in [("birds", "Ambience/birds.ogg", -2.0),
                            ("crickets", "Ambience/crickets.ogg", 1.0),
                            ("fire", "Ambience/fire.ogg", 7.0),
                            ("cooking", "Ambience/cooking.ogg", 13.0)]:
        original = OUT / "Sources" / SOURCES[key][2]
        add(file, key, original.read_bytes(), key, gain, "environment",
            original.relative_to(ROOT).as_posix(), convert=key in ("birds", "fire", "crickets"))
    packs = [
        ("water", "Sounds/HarvestCandidates_20261011/Archives/water-splash-slime-sfx.zip", [("Ambience/water.ogg", "loop_water_02.ogg", "Water loop", -3.0, "environment")]),
        ("forest", "Sounds/HarvestCandidates_20261011/Archives/forest_whisper_theme.zip", [("Music/forest.ogg", "Forest Whisper Theme/Forest Whisper.ogg", "Forest Whisper Theme", 5.0, "music")]),
        ("calm", "Sounds/Walala/Archives/jrpg_calm.zip", [("Music/home.ogg", "Calm2 - Childhood Friends.ogg", "Childhood Friends", -6.0, "music"), ("Music/dock.ogg", "Calm4 - Sand Castles.ogg", "Sand Castles", -6.0, "music")]),
        ("rpg", "Sounds/Walala/Archives/rpg.zip", [("SFX/door_open_01.ogg", "Audio/doorOpen_1.ogg", "Wooden door opening", -10.0, "character"), ("SFX/door_open_02.ogg", "Audio/doorOpen_2.ogg", "Wooden door opening", -10.0, "character"), ("SFX/door_close_01.ogg", "Audio/doorClose_1.ogg", "Wooden door closing", -10.0, "character"), ("SFX/door_close_02.ogg", "Audio/doorClose_2.ogg", "Wooden door closing", -10.0, "character")]),
    ]
    for key, path, selected in packs:
        with zipfile.ZipFile(ROOT / path) as archive:
            for file, member, title, gain, category in selected:
                add(file, key, archive.read(member), title, gain, category, path, member)
            for name in archive.namelist():
                if name.lower().endswith(("readme.txt", "license.txt", "info.txt")):
                    save(OUT / "Licenses" / (key + "_author.txt"), archive.read(name))
    (OUT / "manifest.json").write_text(json.dumps(dict(checked="2026-10-20", assets=assets), ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print("WORLD AUDIO PREPARED",len(assets),sum(a["bytes"] for a in assets),"bytes")
    for a in assets:
        print(a["file"],round(a["duration_seconds"],2),"sec", "default RMS",round(a["rms_db"]+a["gain_db"]+20*np.log10(0.22 if a["category"]=="music" else 0.35),1))


if __name__ == "__main__":
    main()
