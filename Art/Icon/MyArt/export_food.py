"""Read-only Aseprite export. All generated files stay outside MyArt/."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "MyArt"
OUTPUT = Path(__file__).resolve().parent / "Food"
IDS = ("bread", "egg", "tomato")


def snapshot():
    return {
        path.relative_to(SOURCE).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(SOURCE.rglob("*")) if path.is_file()
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aseprite", default=os.environ.get("ASEPRITE_BIN"))
    options = parser.parse_args()
    candidates = [options.aseprite, shutil.which("aseprite"),
                  r"C:\steam\steamapps\common\Aseprite\Aseprite.exe"]
    binary = next((str(p) for p in candidates if p and Path(p).is_file()), None)
    if binary is None:
        parser.error("Set ASEPRITE_BIN or pass --aseprite PATH")
    assert not OUTPUT.resolve().is_relative_to(SOURCE.resolve())
    before = snapshot()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    try:
        for item_id in IDS:
            source = SOURCE / "Icon/Food" / (item_id + ".aseprite")
            output = OUTPUT / (item_id + ".png")
            raw = source.read_bytes()
            size, magic, frames, width, height, depth = struct.unpack_from("<IHHHHH", raw)
            assert size == len(raw) and magic == 0xA5E0 and frames == 1
            subprocess.run([binary, "--batch", "--oneframe", str(source),
                            "--save-as", str(output)], check=True, timeout=30)
            with Image.open(output) as image:
                assert image.size == (width, height) and image.convert("RGBA").getbbox()
                pixels = image.convert("RGBA").tobytes()
            manifest[item_id] = {
                "source": "res://" + source.relative_to(ROOT).as_posix(),
                "source_sha256": hashlib.sha256(raw).hexdigest(),
                "texture": "res://" + output.relative_to(ROOT).as_posix(),
                "size": [width, height], "source_depth": depth,
                "rgba_sha256": hashlib.sha256(pixels).hexdigest(),
            }
        (OUTPUT.parent / "manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    finally:
        assert snapshot() == before, "MyArt contents changed during export"
    print("MYART EXPORT: 3 food icons; original canvas and all source hashes unchanged")


if __name__ == "__main__":
    main()
