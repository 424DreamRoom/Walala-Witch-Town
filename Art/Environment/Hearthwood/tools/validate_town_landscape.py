"""Check road-centre clearance and the landscape pass's preservation contract.

Run after build_town_layout.py. --baseline accepts the pre-edit protected hash
manifest, covering MyArt and every environment sprite outside generated maps.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1]
ROOT = OUT.parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path)
    args = parser.parse_args()
    plan = json.loads((OUT / "town_layout.json").read_text(encoding="utf-8"))
    plaza = Image.new("L", tuple(plan["size"]))
    for item in plan["plazas"]:
        ImageDraw.Draw(plaza).polygon([tuple(p) for p in item["points"]], fill=255)
    # The fountain is an intentional central obstacle in a broad walkable plaza.
    # Outside it every road centre must fit the player's 10x6 ground footprint.
    samples = 0
    for index, route in enumerate(plan["paths"]):
        for (ax, ay), (bx, by) in zip(route["points"], route["points"][1:]):
            steps = max(1, math.ceil(math.hypot(bx - ax, by - ay)))
            for step in range(steps + 1):
                x, y = ax + (bx - ax) * step / steps, ay + (by - ay) * step / steps
                if not (0 <= x < plan["size"][0] and 0 <= y < plan["size"][1]):
                    continue
                if plaza.getpixel((min(round(x), plaza.width - 1), min(round(y), plaza.height - 1))):
                    continue
                for prop in plan["props"]:
                    if not prop.get("solid", True):
                        continue
                    left, right = prop["x"] - prop["w"] / 2, prop["x"] + prop["w"] / 2
                    top, bottom = prop["y"] - prop["h"], prop["y"]
                    assert not (x + 5 > left and x - 5 < right and y > top and y - 6 < bottom), ("road blocked", index, prop["kind"], prop["x"], prop["y"])
                samples += 1
    print("ROAD CENTRE FOOTPRINT PASS", samples, "samples across", len(plan["paths"]), "roads")
    farm = json.loads((OUT / "farm_layout.json").read_text(encoding="utf-8"))
    for name in ("town_ground.png", "town_overview.png", "farm_ground.png", "farm_overview.png"):
        with Image.open(OUT / name) as image:
            assert image.size == tuple(farm["size"] if name.startswith("farm_") else plan["size"])
            assert image.mode == "RGBA" and image.getchannel("A").getextrema() == (255, 255)
    print("NATIVE MAP CANVAS AND OPACITY PASS")
    if args.baseline:
        protected = json.loads(args.baseline.read_text(encoding="utf-8"))
        map_outputs = {"Art/Environment/Hearthwood/" + name for name in ("town_ground.png", "town_overview.png", "farm_ground.png", "farm_overview.png")}
        for name, digest in protected.items():
            if name in map_outputs:
                continue
            path = ROOT / name
            assert path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == digest, ("protected asset changed", name)
        current = {p.relative_to(ROOT).as_posix() for p in (ROOT / "MyArt").rglob("*") if p.is_file()}
        assert current == {name for name in protected if name.startswith("MyArt/")}, "Original asset file set changed"
        print("PROTECTED ORIGINALS AND SPRITES PASS", len(set(protected) - map_outputs), "hashes")
    print("TOWN LANDSCAPE PASS")


if __name__ == "__main__":
    main()
