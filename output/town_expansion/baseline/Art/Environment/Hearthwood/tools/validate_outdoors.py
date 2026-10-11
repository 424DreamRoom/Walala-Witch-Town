"""Validate outdoor assets and navigability with the game's foot collision box."""
from collections import deque
import argparse
import json
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parents[1]


def reachable(size, props, start, targets, bounds):
    step = 4
    width, height = size
    solids = [(p["x"] - p["w"] / 2, p["y"] - p["h"], p["x"] + p["w"] / 2, p["y"]) for p in props if p.get("solid", True)]
    x0, y0, x1, y1 = bounds
    def free(x, y):
        if not (x0 + 5 <= x <= x1 - 5 and y0 + 6 <= y <= y1):
            return False
        return not any(x + 5 > a and x - 5 < c and y > b and y - 6 < d for a, b, c, d in solids)
    first = (round(start[0] / step) * step, round(start[1] / step) * step)
    assert free(*first), ("blocked spawn", first)
    visited, queue = {first}, deque([first])
    while queue:
        x, y = queue.popleft()
        for point in ((x + step, y), (x - step, y), (x, y + step), (x, y - step)):
            xx, yy = point
            if 0 <= xx <= width and 0 <= yy <= height and point not in visited and free(xx, yy):
                visited.add(point)
                queue.append(point)
    for x, y in targets:
        assert free(x, y), ("blocked destination", x, y)
        assert any(abs(px - x) <= step and abs(py - y) <= step for px, py in visited), ("unreachable destination", x, y)
    return {"targets": len(targets), "reachable_cells": len(visited), "foot_collision": [10, 6], "status": "PASS"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--screens", action="store_true")
    args = parser.parse_args()
    manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
    town = json.loads((OUT / "town_layout.json").read_text(encoding="utf-8"))
    field = json.loads((OUT / "field_layout.json").read_text(encoding="utf-8"))
    names = sorted(OUT.glob("outdoor_*.png"))
    for path in names:
        image = Image.open(path).convert("RGBA")
        assert list(image.size) == manifest["assets"][path.name]
        assert image.getbbox() is not None
        assert set(image.getchannel("A").get_flattened_data()) <= {0, 80, 255}
    for layout in (town, field):
        for p in layout["props"]:
            assert (OUT / (p["kind"] + ".png")).is_file()
            if p.get("solid", True):
                assert p["w"] > 0 and p["h"] > 0
    destinations = list(town.get("gates", {}).values()) or [(408, 334), (448, 384), (224, 314)]
    destinations += [(b["x"], b["y"] + 26) for b in town["buildings"]]
    destinations += [(408, 684), (808, 364), (808, 684)]
    water = [dict(x=x + w/2, y=y+h, w=w, h=h) for x, y, w, h in town.get("barriers", [])]
    town_check = reachable(town["size"], town["buildings"] + town["props"] + water, (408, 364), destinations, (0, 0, 1280, 960))
    field_targets = [(105 + x * 135, 115 + y * 66) for y in range(3) for x in range(3)] + [field["spawn"], field["exit"]]
    field_check = reachable(field["size"], field["props"], field["spawn"], field_targets, (8, 72, 432, 360))
    report = {"status": "PASS", "native_sprites": len(names), "town_decorations": manifest["outdoors"]["town_decorations"], "town_navigation": town_check, "field_navigation": field_check, "method": "4px cardinal flood fill against expanded solid footprints; excludes decorative foliage"}
    if args.screens:
        screenshots = ["town_entry", "home_garden", "pond_street", "south_street", "field_entry", "field_gathering", "field_behind_tree", "field_front_tree"]
        for name in screenshots:
            path = OUT / "Verification" / ("outdoor_" + name)
            image = Image.open(path.with_suffix(".png")).convert("RGB")
            window = Image.open(path.with_name(path.name + "_window.png")).convert("RGB")
            assert image.size == (640, 360) and window.size == (1280, 720)
            assert image.resize(window.size, Image.Resampling.NEAREST).tobytes() == window.tobytes(), name
        report["window_scaling"] = {"status": "PASS", "screenshots": len(screenshots), "scale": 2, "method": "Exact rendered PNG comparison"}
    (OUT / "outdoor-validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("OUTDOOR VALIDATION PASS", len(names), "sprites;", town_check["targets"], "town destinations;", field_check["targets"], "field destinations")
    if args.screens:
        print("OUTDOOR WINDOW VALIDATION PASS", len(screenshots), "screenshots")


if __name__ == "__main__":
    main()
