"""Refresh only four generated map textures and capture the real Godot viewport."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
ART = Path("Art/Environment/Hearthwood")
NAMES = ["town_ground.png", "town_overview.png", "farm_ground.png", "farm_overview.png"]
GODOT = next(p for p in [Path(r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"), Path(r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")] if p.is_file())
STARTUP = subprocess.STARTUPINFO()
STARTUP.dwFlags |= subprocess.STARTF_USESHOWWINDOW
STARTUP.wShowWindow = 0


def run(args, name):
    log = OUT / (name + ".log")
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run([str(GODOT)] + [str(arg) for arg in args], cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, startupinfo=STARTUP, timeout=60)
    text = log.read_text(encoding="utf-8")
    assert result.returncode == 0 and not any(token in text for token in ("ERROR:", "SCRIPT ERROR", ": FAIL")), text
    print(name, "PASS")


fixture = OUT / "texture_import"
(fixture / ART).mkdir(parents=True, exist_ok=True)
(fixture / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Map art texture import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
for name in NAMES:
    shutil.copy2(ROOT / ART / name, fixture / ART / name)
    shutil.copy2(ROOT / ART / (name + ".import"), fixture / ART / (name + ".import"))
run(["--path", fixture, "--headless", "--editor", "--import", "--quit"], "import")
for name in NAMES:
    # Preserve source-side UIDs and parameters; only refresh generated caches.
    assert (ROOT / ART / (name + ".import")).read_bytes() == (fixture / ART / (name + ".import")).read_bytes(), name
for cache in (fixture / ".godot/imported").iterdir():
    if cache.is_file():
        shutil.copy2(cache, ROOT / ".godot/imported" / cache.name)
run(["--path", ROOT, "--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--script", "res://output/map_art_pass/capture.gd", "--", "--no-loop"], "capture")
for stage in ["before", "after"]:
    folder = OUT / stage / "captures"
    native_paths = sorted(p for p in folder.glob("*.png") if not p.stem.endswith("_window"))
    assert len(native_paths) == 7
    for path in native_paths:
        with Image.open(path) as native, Image.open(path.with_stem(path.stem + "_window")) as window:
            assert native.size == (640, 360) and window.size == (1280, 720)
            assert ImageChops.difference(native.convert("RGB").resize(window.size, Image.Resampling.NEAREST), window.convert("RGB")).getbbox() is None, path.name
print("NATIVE AND WINDOW PIXELS MATCH", 14, "views")
comparison = Image.new("RGB", (1280, 1080))
for row, name in enumerate(["arrival", "square", "windmill"]):
    for col, stage in enumerate(["before", "after"]):
        with Image.open(OUT / stage / "captures" / (name + ".png")) as image:
            comparison.paste(image.convert("RGB"), (col * 640, row * 360))
comparison.save(OUT / "comparison.png")
plan = json.loads((ROOT / ART / "town_layout.json").read_text(encoding="utf-8"))
print("LANDSCAPE GROUPS", len({p["composition_group"] for p in plan["props"] if "composition_group" in p}), "NEW PROPS", sum("composition_group" in p for p in plan["props"]))
