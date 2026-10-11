"""Yingluo integration checks; imports and progress stay outside MyArt/user saves."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/guide_npc"
ART = Path("Art/Characters/Yingluo")
parser = argparse.ArgumentParser()
parser.add_argument("mode", choices=["import", "headless", "capture"], nargs="?", default="headless")
options = parser.parse_args()
OUT.mkdir(parents=True, exist_ok=True)
godot = os.environ.get("GODOT_BIN", r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")

def originals():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (ROOT / "MyArt").rglob("*") if p.is_file()}

before = originals()
startup = subprocess.STARTUPINFO() if os.name == "nt" else None
if startup:
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0

if options.mode == "import":
    # Only runtime guide textures enter this tiny project. No original directory is scanned.
    project = OUT / "texture_import"
    (project / ART).mkdir(parents=True, exist_ok=True)
    (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Yingluo texture import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
    for name in ["yingluo.png", "yingluo_world_32.png"]:
        shutil.copy2(ROOT / ART / name, project / ART / name)
    args = [godot, "--path", str(project), "--headless", "--editor", "--import", "--quit"]
else:
    args = [godot, "--path", str(ROOT), "--script", "res://Scenes/Campaign/verify_guide.gd"]
    args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--capture"] if options.mode == "capture" else ["--headless"]

log_path = OUT / (options.mode + ".log")
with log_path.open("w", encoding="utf-8") as log:
    process = subprocess.Popen(args, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        process.wait(timeout=55)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
text = log_path.read_text(encoding="utf-8", errors="replace")
ok = process.returncode == 0 and not any(token in text for token in ["ERROR:", "SCRIPT ERROR", ": FAIL"])
if options.mode == "import" and ok:
    for imported in (project / ART).glob("*.png.import"):
        shutil.copy2(imported, ROOT / ART / imported.name)
    target = ROOT / ".godot/imported"
    target.mkdir(parents=True, exist_ok=True)
    for imported in (project / ".godot/imported").glob("yingluo*"):
        shutil.copy2(imported, target / imported.name)
elif options.mode != "import":
    ok = ok and "GUIDE COMPLETE" in text and " failures=0" in text
assert originals() == before, "Protected originals changed"
print("\n".join(line for line in text.splitlines() if any(token in line for token in ["ERROR", "FAIL", "COMPLETE"])))
print("GUIDE", options.mode, "PASS_COUNT", text.count(": PASS"), "EXIT", process.returncode, "MYART_UNCHANGED", len(before))
raise SystemExit(0 if ok else 1)
