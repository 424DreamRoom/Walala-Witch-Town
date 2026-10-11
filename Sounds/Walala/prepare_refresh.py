"""Extract selected original CC0 audio; retain the previous selection for comparison."""
import hashlib
import json
from pathlib import Path
import zipfile

from acquire_refresh import PACKS

BASE = Path(__file__).resolve().parent
LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"


def entry(file, data, member, pack, author, title, **extra):
    page, url = PACKS[pack]
    return dict(file=file, title=title, author=author, source=page, download=url,
                archive=pack + ".zip", archive_member=member,
                license="CC0 1.0 Universal", license_url=LICENSE,
                changes="Original audio bytes; renamed, runtime gain/loop only",
                sha256=hashlib.sha256(data).hexdigest(), bytes=len(data), **extra)


def save(file, data):
    target = BASE / file
    target.parent.mkdir(exist_ok=True)
    if target.exists() and target.read_bytes() != data:
        raise FileExistsError(target)
    target.write_bytes(data)


def main():
    music = []
    with zipfile.ZipFile(BASE / "Archives/jrpg_calm.zip") as pack:
        for name, member, context in [
            ("title", "Calm1 - A Place I Call Home.ogg", "title"),
            ("day", "Calm3 - Peaceful Days.ogg", "day_town"),
            ("night", "Calm5 - Summer Memories.ogg", "night_town3"),
        ]:
            data = pack.read(member)
            save("Music/" + name + ".ogg", data)
            music.append(entry(name + ".ogg", data, member, "jrpg_calm",
                               "Juhani Junkala / SubspaceAudio", member[8:-4],
                               context=context, gain_db=-6.0))
        save("Music/LICENSE.txt", pack.read("INFO.txt"))
    (BASE / "Music/manifest.json").write_text(json.dumps(
        dict(checked="2026-10-11", assets=music), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    manifest_path = BASE / "UI/manifest.json"
    old_manifest = BASE / "UI/manifest_20261010.json"
    if not old_manifest.exists():
        old_manifest.write_bytes(manifest_path.read_bytes())
    old = json.loads(old_manifest.read_text(encoding="utf-8"))
    assets = []
    with zipfile.ZipFile(BASE / "Archives/organic_ui.zip") as pack:
        for name, member, gain in [
            ("hover", "rollover2.wav", -2.0), ("click", "click1.wav", 3.0),
            ("open", "switch7.wav", -5.0), ("close", "switch8.wav", 0.0),
            ("toggle", "switch12.wav", 2.0), ("slider", "click5.wav", 8.0),
        ]:
            data = pack.read(member)
            save("UI/Organic/" + name + ".wav", data)
            assets.append(entry("Organic/" + name + ".wav", data, member,
                                "organic_ui", "Kenney Vleugels / Kenney", member,
                                event="ui_" + name, gain_db=gain))
        save("UI/Organic/LICENSE.txt", pack.read("readme.txt"))
    with zipfile.ZipFile(BASE / "Archives/interface.zip") as pack:
        for name, member, gain in [
            ("confirm", "Audio/confirmation_003.ogg", -12.0),
            ("error", "Audio/error_004.ogg", -15.0),
        ]:
            data = pack.read(member)
            save("UI/Organic/" + name + ".ogg", data)
            assets.append(dict(file="Organic/" + name + ".ogg", event="ui_" + name,
                title=member, author="Kenney", source="https://kenney.nl/assets/interface-sounds",
                download="https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
                archive="interface.zip", archive_member=member, license="CC0 1.0 Universal",
                license_url=LICENSE, changes="Original OGG bytes; runtime gain only", gain_db=gain,
                sha256=hashlib.sha256(data).hexdigest(), bytes=len(data)))
    assets.extend(a for a in old["assets"] if a["event"] in ["ui_page", "ui_book_open", "ui_book_close"])
    manifest_path.write_text(json.dumps(dict(checked="2026-10-11", assets=assets),
                                       ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Prepared 3 music tracks and 8 replacement UI cues; 3 book cues retained")


if __name__ == "__main__":
    main()
