"""Check the new town's geometry, preserved art, deterministic rebuild and captures."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from PIL import Image, ImageChops
from validate_outdoors import reachable

OUT = Path(__file__).resolve().parents[1]
plan = json.loads((OUT / "town_layout.json").read_text(encoding="utf-8"))
assert plan["revision"] == 3 and len(plan["buildings"]) == 8
assert len({b["x"] for b in plan["buildings"]}) == 8
assert len({b["y"] for b in plan["buildings"]}) == 8
assert plan["gates"]["farm"] == [8, 364] and "home" not in plan["gates"]
assert all(b["role"] != "witch_home" for b in plan["buildings"])
assert len(plan["paths"]) == 16 and len(plan["districts"]) == 5
for i, a in enumerate(plan["buildings"]):
    for b in plan["buildings"][i + 1:]:
        assert abs(a["x"] - b["x"]) >= 192 or abs(a["y"] - b["y"]) >= 192, (a["name"], b["name"], "overlapping roofs")
for key, role in [("restaurant", "restaurant"), ("blacksmith", "blacksmith"), ("store", "store"), ("furniture_store", "furniture_store")]:
    house = next(b for b in plan["buildings"] if b["role"] == role)
    assert plan["gates"][key] == [house["x"], house["y"] + 26], key
water = [dict(x=x + w / 2, y=y + h, w=w, h=h) for x, y, w, h in plan["barriers"]]
targets = list(plan["gates"].values()) + [[b["x"], b["y"] + 26] for b in plan["buildings"]]
targets += [d["point"] for d in plan["districts"]] + [[1190, 652]]
result = reachable(plan["size"], plan["buildings"] + plan["props"] + water, plan["spawn"], targets, (0, 0, 1280, 960))
print("TOWN GEOMETRY AND NAVIGATION PASS", result["targets"], "destinations")

if "--rebuild" in sys.argv:
    changed = [OUT / name for name in ("town_ground.png", "town_overview.png", "town_fountain.png", "town_layout.json")]
    protected = sorted(OUT.glob("home_*.png")) + sorted(OUT.glob("smith_*.png")) + sorted(OUT.glob("store_*.png")) + [OUT / "field_background.png", OUT / "restaurant_background.png"]
    def hashes(paths):
        return {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    before, originals = hashes(changed), hashes(protected)
    subprocess.run([sys.executable, "-B", str(OUT / "tools/build_town_layout.py")], check=True)
    assert before == hashes(changed), "Town rebuild is not deterministic"
    assert originals == hashes(protected), "Interior or field art changed"
    print("DETERMINISTIC TOWN REBUILD PASS; PROTECTED ART UNCHANGED", len(protected))

if "--screens" in sys.argv:
    folder = OUT / "Verification/TownPlan"
    screenshots = sorted(p for p in folder.glob("*.png") if not p.stem.endswith("_window"))
    assert len(screenshots) == 11, len(screenshots)
    for path in screenshots:
        with Image.open(path) as native, Image.open(path.with_name(path.stem + "_window.png")) as window:
            assert native.size == (640, 360) and window.size == (1280, 720), path.name
            expected = native.convert("RGB").resize(window.size, Image.Resampling.NEAREST)
            assert ImageChops.difference(expected, window.convert("RGB")).getbbox() is None, path.name
    print("TOWN WINDOW PIXEL SCALING PASS", len(screenshots))
