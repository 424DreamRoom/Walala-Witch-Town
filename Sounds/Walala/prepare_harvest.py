"""Extract verified CC0 gathering clips from retained original downloads.

Only writes Sounds/Walala/Harvest. Existing, different audio is never overwritten.
The original downloads and MyArt are read-only inputs.
"""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[2]
BASE = Path(__file__).resolve().parent
OUT = BASE / "Harvest"
CANDIDATES = ROOT / "Sounds/HarvestCandidates_20261011"
CC0 = "https://creativecommons.org/publicdomain/zero/1.0/"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(name, data):
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if path.read_bytes() != data:
            raise FileExistsError("Refusing to overwrite different audio: " + str(path))
    else:
        path.write_bytes(data)


def main():
    prior = json.loads((CANDIDATES / "manifest.json").read_text(encoding="utf-8"))
    sources = {a["id"]: a for a in prior["assets"]}
    old = json.loads((BASE / "manifest.json").read_text(encoding="utf-8"))
    leaves = next(a for a in old["assets"] if a["file"] == "Footsteps/grass_01.ogg")
    packs = {
        "impact": (CANDIDATES / sources["kenney_impact"]["file"], sources["kenney_impact"]),
        "water": (CANDIDATES / sources["water_splash"]["file"], sources["water_splash"]),
        "leaves": (BASE / "Archives/footsteps.zip", leaves),
    }
    for key in ["impact", "water"]:
        path, source = packs[key]
        assert sha(path.read_bytes()) == source["download"]["sha256"], path
        assert source["license"] == "CC0-1.0"
    selections = [
        ("gather", "leaves", ["leaves01.ogg", "leaves02.ogg"], 16.0),
        ("chop", "impact", ["Audio/impactWood_medium_%03d.ogg" % i for i in range(3)], -6.0),
        ("mine", "impact", ["Audio/impactMining_%03d.ogg" % i for i in range(3)], -8.0),
        ("cast", "water", ["splash_02.ogg", "splash_03.ogg"], -3.0),
        ("bite", "water", ["bubble_02.ogg"], -5.0),
        ("catch", "water", ["splash_06.ogg", "splash_08.ogg"], -5.0),
    ]
    assets = []
    for event, key, members, gain in selections:
        path, source = packs[key]
        with zipfile.ZipFile(path) as pack:
            assert pack.testzip() is None, path
            for i, member in enumerate(members):
                data = pack.read(member)
                assert data.startswith(b"OggS"), member
                name = "%s_%02d.ogg" % (event, i + 1)
                save(name, data)
                assets.append(dict(file=name, event=event, title=member,
                    author=source["author"], source=source["source"],
                    download=source.get("actual_download_url", source.get("url", source.get("download"))),
                    source_archive=path.relative_to(ROOT).as_posix(), archive_member=member,
                    source_archive_sha256=sha(path.read_bytes()),
                    license="CC0 1.0 Universal", license_url=CC0,
                    changes="Original OGG bytes; renamed; runtime gain and pitch only",
                    gain_db=(16.0 + i * 6.0) if event == "gather" else gain,
                    sha256=sha(data), bytes=len(data)))
            if key == "impact":
                save("Licenses/Kenney_Impact_LICENSE.txt", pack.read("License.txt"))
    save("Licenses/impact_source.html", (CANDIDATES / "Licenses/kenney_impact_source.html").read_bytes())
    save("Licenses/water_source.html", (CANDIDATES / "Licenses/water_splash_source.html").read_bytes())
    save("Licenses/leaves_source.html", (BASE / "Licenses/footsteps.html").read_bytes())
    # The source page and author attribution for the leaf recordings are also in the base manifest.
    manifest = dict(checked="2026-10-11", license=CC0, selection="13 clips / 6 gathering events",
                    assets=assets, unused_previous=["gather.ogg", "chop.wav", "mine.wav", "cast.wav", "bite.wav", "catch.wav"])
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("HARVEST PREPARED", len(assets), "original-byte clips", sum(a["bytes"] for a in assets), "bytes")


if __name__ == "__main__":
    main()
