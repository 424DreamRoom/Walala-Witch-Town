"""Acquire the selected CC0 audio candidates without changing runtime audio."""
import concurrent.futures
import hashlib
import json
from pathlib import Path, PurePosixPath
import ssl
import time
import urllib.request
import urllib.parse
import wave
import zipfile

BASE = Path(__file__).resolve().parent
LIMIT = 64 * 1024 * 1024
CC0 = "https://creativecommons.org/publicdomain/zero/1.0/"
FETCH_URLS = {}
PRIOR_URLS = {}
if (BASE / "manifest.json").exists():
    prior_manifest = json.loads((BASE / "manifest.json").read_text(encoding="utf-8"))
    PRIOR_URLS = {a["id"]: a.get("actual_download_url", a["url"]) for a in prior_manifest["assets"]}
ASSETS = [
    dict(id="forest_whisper", title="Forest Whisper Theme", author="Cleyton Kauffman",
         source="https://opengameart.org/content/forest-whisper-theme",
         url="https://opengameart.org/sites/default/files/forest_whisper_theme.zip",
         file="Archives/forest_whisper_theme.zip", extract="Music/ForestWhisperTheme"),
    dict(id="gone_fishin", title="Gone Fishin'", author="iamoneabe",
         source="https://opengameart.org/content/gone-fishin-0",
         url="https://opengameart.org/sites/default/files/gonefishin.wav",
         file="Music/GoneFishin/gonefishin.wav"),
    dict(id="cave_theme", title="Mysterious Cave Theme Loop", author="beardalaxy",
         source="https://opengameart.org/content/mysterious-cave-theme-loop",
         url="https://opengameart.org/sites/default/files/cave_in_game.ogg",
         file="Music/MysteriousCaveTheme/cave_in_game.ogg"),
    dict(id="water_splash", title="40 CC0 water / splash / slime SFX", author="rubberduck",
         source="https://opengameart.org/content/40-cc0-water-splash-slime-sfx",
         url="https://opengameart.org/sites/default/files/water-splash-slime-sfx.zip",
         file="Archives/water-splash-slime-sfx.zip", extract="SFX/WaterSplashSlime"),
    dict(id="kenney_impact", title="Impact Sounds", author="Kenney",
         source="https://kenney.nl/assets/impact-sounds",
         url="https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
         file="Archives/kenney_impact-sounds.zip", extract="SFX/KenneyImpactSounds"),
    dict(id="chopping_wood", title="chopping wood with axe.wav", author="21100495",
         source="https://freesound.org/people/21100495/sounds/655325/",
         url="https://cdn.freesound.org/previews/655/655325_13723333-hq.mp3",
         file="SFX/FreesoundPreviews/chopping_wood_655325_hq.mp3", preview=True),
    dict(id="fishing_reel", title="FishingReel.wav", author="Harrisando",
         source="https://freesound.org/people/Harrisando/sounds/466205/",
         url="https://cdn.freesound.org/previews/466/466205_9855691-hq.mp3",
         file="SFX/FreesoundPreviews/fishing_reel_466205_hq.mp3", preview=True),
    dict(id="pickaxe", title="Pickaxe", author="CaptainYulef",
         source="https://freesound.org/people/CaptainYulef/sounds/638696/",
         url="https://cdn.freesound.org/previews/638/638696_13383190-hq.mp3",
         file="SFX/FreesoundPreviews/pickaxe_638696_hq.mp3", preview=True),
]


def fetch(url):
    last_error = None
    variants = [url]
    parsed = urllib.parse.urlsplit(url)
    is_file = parsed.path.lower().endswith((".zip", ".wav", ".ogg", ".mp3"))
    if is_file:
        variants.append(url + ("&" if parsed.query else "?") + "download=1")
        if parsed.netloc in {"opengameart.org", "kenney.nl"}:
            variants.append(urllib.parse.urlunsplit(parsed._replace(netloc="www." + parsed.netloc)))
        elif parsed.netloc == "cdn.freesound.org":
            variants.append(url.replace("https://cdn.freesound.org/previews/", "https://freesound.org/data/previews/"))
    variants.append(url)
    for attempt, request_url in enumerate(variants):
        try:
            req = urllib.request.Request(request_url, headers={"User-Agent": "Mozilla/5.0"})
            context = None
            if attempt + 1 == len(variants):
                context = ssl.create_default_context()
                context.maximum_version = ssl.TLSVersion.TLSv1_2
            with urllib.request.urlopen(req, timeout=30, context=context) as response:
                data = response.read(LIMIT + 1)
                resolved_url = response.geturl()
            if not data or len(data) > LIMIT:
                raise ValueError("Empty response or response exceeds 64 MiB")
            FETCH_URLS[url] = resolved_url
            return data
        except Exception as exc:
            last_error = exc
            print("RETRY", attempt + 1, request_url, str(exc), flush=True)
            if attempt + 1 < len(variants):
                time.sleep(1)
    raise last_error


def write_once(target, data):
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        if target.read_bytes() != data:
            raise ValueError("Refusing to overwrite a different existing file: " + str(target))
    else:
        with target.open("xb") as stream:
            stream.write(data)


def describe(target):
    data = target.read_bytes()
    record = dict(file=target.relative_to(BASE).as_posix(), bytes=len(data),
                  sha256=hashlib.sha256(data).hexdigest())
    suffix = target.suffix.lower()
    if suffix == ".wav":
        with wave.open(str(target), "rb") as audio:
            record.update(format="WAV", duration_seconds=round(audio.getnframes() / audio.getframerate(), 4),
                          sample_rate=audio.getframerate(), channels=audio.getnchannels())
            if len(audio.readframes(audio.getnframes())) != audio.getnframes() * audio.getnchannels() * audio.getsampwidth():
                raise ValueError("Truncated WAV: " + str(target))
    elif suffix == ".ogg":
        if not data.startswith(b"OggS"):
            raise ValueError("Invalid OGG signature: " + str(target))
        record["format"] = "OGG"
    elif suffix == ".mp3":
        if not (data.startswith(b"ID3") or (data[0] == 255 and data[1] & 224 == 224)):
            raise ValueError("Invalid MP3 signature: " + str(target))
        record["format"] = "MP3"
    return record


def acquire(asset):
    record = dict(asset, license="CC0-1.0", license_url=CC0, downloaded_on="2026-10-11")
    try:
        target = BASE / asset["file"]
        if not target.exists():
            write_once(target, fetch(asset["url"]))
        record["download"] = describe(target)
        record["actual_download_url"] = FETCH_URLS.get(asset["url"], PRIOR_URLS.get(asset["id"], asset["url"]))
        files = []
        if "extract" in asset:
            with zipfile.ZipFile(target) as pack:
                if sum(item.file_size for item in pack.infolist()) > 256 * 1024 * 1024:
                    raise ValueError("Archive expansion exceeds 256 MiB")
                bad = pack.testzip()
                if bad:
                    raise ValueError("ZIP CRC failure: " + bad)
                for item in pack.infolist():
                    if item.is_dir():
                        continue
                    relative = PurePosixPath(item.filename.replace("\\", "/"))
                    if relative.is_absolute() or ".." in relative.parts or any(":" in p for p in relative.parts):
                        raise ValueError("Unsafe archive path")
                    if relative.suffix.lower() not in {".wav", ".ogg", ".mp3", ".txt", ".md", ".pdf"}:
                        continue
                    if any(p.startswith(".") or p == "__MACOSX" for p in relative.parts):
                        continue
                    output = BASE / asset["extract"] / Path(*relative.parts)
                    if BASE not in output.resolve().parents:
                        raise ValueError("Archive path outside download directory")
                    write_once(output, pack.read(item))
                    entry = describe(output)
                    entry["archive_member"] = item.filename
                    files.append(entry)
            record["archive_crc_verified"] = True
        else:
            files.append(record["download"])
        record["files"] = files
        record["status"] = "downloaded_public_preview" if asset.get("preview") else "downloaded_original"
        print("OK", asset["id"], len(files), "files", record["download"]["bytes"], "bytes", flush=True)
    except Exception as exc:
        record.update(status="failed", error=str(exc))
        print("FAILED", asset["id"], str(exc), flush=True)
    return record


def evidence(asset):
    target = BASE / "Licenses" / (asset["id"] + "_source.html")
    try:
        if not target.exists():
            write_once(target, fetch(asset["source"]))
        return dict(id=asset["id"], status="saved", file=target.relative_to(BASE).as_posix())
    except Exception as exc:
        return dict(id=asset["id"], status="failed", error=str(exc))


def main():
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        records = list(pool.map(acquire, ASSETS))
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        evidence_records = list(pool.map(evidence, ASSETS))
    license_path = BASE / "Licenses" / "CC0-1.0.html"
    try:
        if not license_path.exists():
            write_once(license_path, fetch(CC0))
    except Exception as exc:
        print("LICENSE PAGE", str(exc), flush=True)
    manifest = dict(downloaded_on="2026-10-11", assets=records, source_evidence=evidence_records,
                    note="Freesound files are the openly published high-quality MP3 previews, not original WAV downloads. Original WAV downloads require login. No runtime audio references were changed.")
    (BASE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    credits = ["Walala - harvest audio candidates (2026-10-11)",
               "All selected source pages identify these assets as CC0-1.0.", CC0,
               "Freesound files: public high-quality MP3 previews; original WAV downloads require login.",
               "Music/ contains background music; SFX/ contains sound effects; Archives/ retains source ZIPs.",
               "Licenses/ retains source HTML for evidence only; do not execute archived HTML.",
               "No runtime mapping, settings, or saves were changed. Files retain original downloaded bytes.",
               "manifest.json records source URLs, download URLs, file sizes and SHA-256 hashes.", ""]
    for asset in records:
        credits.extend([asset["title"] + " - " + asset["author"], "Source: " + asset["source"],
                        "Download: " + asset["url"], "Status: " + asset["status"], ""])
    (BASE / "SOURCE_CREDITS.txt").write_text("\n".join(credits), encoding="utf-8")
    audio = [f for a in records for f in a.get("files", []) if f.get("format")]
    summary = dict(assets_downloaded=sum(a["status"] != "failed" for a in records),
                   assets_failed=sum(a["status"] == "failed" for a in records),
                   audio_files=len(audio), audio_bytes=sum(f["bytes"] for f in audio),
                   evidence_saved=sum(e["status"] == "saved" for e in evidence_records))
    print(json.dumps(summary), flush=True)
    if summary["assets_failed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
