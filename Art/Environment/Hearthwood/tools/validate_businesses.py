"""Pixel integrity, furniture access, rebuild hashes and actual window scaling."""
from collections import deque
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from PIL import Image, ImageChops

OUT = Path(__file__).resolve().parents[1]
manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
assets = {n: s for n, s in manifest["assets"].items() if n.startswith(("blacksmith_", "smith_", "store_"))}
assert len(assets) == 21, len(assets)
for name, size in assets.items():
    with Image.open(OUT / name) as im:
        im.load()
        assert im.mode == "RGBA" and list(im.size) == size, name
        assert set(im.getchannel("A").tobytes()) <= {0, 120, 255}, name
print("PIXEL ASSETS PASS", len(assets))

for kind in ("blacksmith", "store"):
    layout = json.loads((OUT / (kind + "_layout.json")).read_text(encoding="utf-8"))
    solids = layout["walls"] + [[p["x"] - p["w"] / 2, p["y"] - p["h"], p["w"], p["h"]] for p in layout["furniture"]]

    def clear(x, y):
        return 5 <= x <= 635 and 6 <= y <= 479 and not any(x + 5 > sx and x - 5 < sx + w and y > sy and y - 6 < sy + h for sx, sy, w, h in solids)

    # One-pixel connectivity uses the actual 10x6 foot box, not visual bounds.
    start = tuple(layout["spawn"])
    queue = deque([start])
    seen = {start}
    while queue:
        x, y = queue.popleft()
        for point in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if point not in seen and clear(*point):
                seen.add(point)
                queue.append(point)
    goals = [tuple(layout["exit"]), tuple(layout["service"])] + [(p["x"], p["y"] + 14) for p in layout["furniture"]]
    for goal in goals:
        assert goal in seen, (kind, "unreachable", goal)
    print("FURNITURE ACCESS PASS", kind, len(goals))

with Image.open(OUT / "smith_fire.png") as sheet:
    first = sheet.crop((0, 0, 112, 140))
    for i in range(1, 4):
        frame = sheet.crop((i * 112, 0, (i + 1) * 112, 140))
        box = ImageChops.difference(first, frame).convert("RGB").getbbox()
        assert box is not None and box[0] >= 34 and box[1] >= 94 and box[2] <= 78 and box[3] <= 128, box
print("LOCAL FIRE ANIMATION PASS")

if "--rebuild" in sys.argv:
    paths = [OUT / n for n in assets] + [OUT / (k + "_layout.json") for k in ("blacksmith", "store")]
    before = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    subprocess.run([sys.executable, "-B", str(OUT / "tools/build_businesses.py")], check=True)
    after = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    assert before == after, "Rebuild differs"
    print("DETERMINISTIC REBUILD PASS", len(paths))

if "--screens" in sys.argv:
    screens = OUT / "Verification/Businesses"
    images = sorted(p for p in screens.glob("*.png") if not p.stem.endswith("_window"))
    assert len(images) == 8, len(images)
    for image in images:
        with Image.open(image) as native, Image.open(screens / (image.stem + "_window.png")) as window:
            assert native.size == (640, 360) and window.size == (1280, 720), image.name
            enlarged = native.convert("RGB").resize(window.size, Image.Resampling.NEAREST)
            assert ImageChops.difference(enlarged, window.convert("RGB")).getbbox() is None, image.name
    print("ACTUAL WINDOW NEAREST SCALING PASS", len(images))
    preview = Image.new("RGBA", (1280, 720))
    for i, name in enumerate(("blacksmith_exterior_full", "store_exterior_full", "blacksmith_room", "store_room")):
        with Image.open(screens / (name + ".png")) as picture:
            preview.alpha_composite(picture.convert("RGBA"), ((i % 2) * 640, (i // 2) * 360))
    preview.save(OUT / "Verification/businesses_preview.png")
    print("RUNTIME PREVIEW SAVED")
