"""Verify imported UI audio and real menu/HUD input without changing player saves."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

root = Path(__file__).resolve().parents[2]
base = root / "Sounds/Walala"
manifest = json.loads((base / "UI/manifest.json").read_text(encoding="utf-8"))
for asset in manifest["assets"]:
    data = (base / "UI" / asset["file"]).read_bytes()
    assert len(data) == asset["bytes"] and hashlib.sha256(data).hexdigest() == asset["sha256"]
    pack = asset.get("archive") or ("rpg.zip" if asset["source"].endswith("rpg-audio") else "interface.zip")
    with zipfile.ZipFile(base / "Archives" / pack) as archive:
        assert data == archive.read(asset["archive_member"])
print("UI AUDIO original-byte hashes verified:", len(manifest["assets"]))
godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or next(
    (str(p) for p in [
        Path(r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"),
        Path(r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"),
    ] if p.is_file()), None)
if not godot:
    raise SystemExit("Set GODOT_BIN to the Godot executable")
mode = sys.argv[1] if len(sys.argv) > 1 else "headless"
scripts = {
    "headless": ("Sounds/Walala/verify_ui_audio.gd", "UI AUDIO VERIFY END failures=0"),
    "audio": ("Sounds/Walala/verify_ui_audio.gd", "UI AUDIO VERIFY END failures=0"),
    "menu": ("Scenes/MainMenu/verify_menu.gd", "MENU VERIFY END failures=0"),
    "hud": ("Scenes/UI/verify_ui.gd", "HUD VERIFY END failures=0"),
    "saves": ("Scenes/Save/verify_saves.gd", "SAVE VERIFY END failures=0"),
}
if mode not in scripts:
    raise SystemExit("Use headless, audio, menu, hud or saves")
script, marker = scripts[mode]
args = [godot, "--path", str(root), "--script", "res://" + script]
args += ["--display-driver", "headless", "--audio-driver", "WASAPI"] if mode == "audio" else ["--headless"]
log = root / "output" / ("ui_audio_" + mode + "_" + str(os.getpid()) + ".log")
with log.open("w", encoding="utf-8") as output:
    child = subprocess.Popen(args, cwd=root, stdout=output, stderr=subprocess.STDOUT)
    try:
        code = child.wait(timeout=60)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 124
text = log.read_text(encoding="utf-8")
print(text)
print("LOG", log)
print("GODOT_EXIT", code)
if "FAIL" in text or "ERROR:" in text or marker not in text:
    code = 1
sys.exit(code)
