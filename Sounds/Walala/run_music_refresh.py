"""Verify original music bytes and actual Godot playback with isolated preferences."""
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
godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or next(
    (str(p) for p in [
        Path(r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"),
        Path(r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"),
    ] if p.is_file()), None)
if not godot:
    raise SystemExit("Set GODOT_BIN to the Godot executable")

manifest = json.loads((base / "Music/manifest.json").read_text(encoding="utf-8"))
with zipfile.ZipFile(base / "Archives/jrpg_calm.zip") as archive:
    for asset in manifest["assets"]:
        data = (base / "Music" / asset["file"]).read_bytes()
        assert data == archive.read(asset["archive_member"])
        assert len(data) == asset["bytes"] and hashlib.sha256(data).hexdigest() == asset["sha256"]
print("MUSIC REFRESH original-byte hashes verified:", len(manifest["assets"]))
mode = sys.argv[1] if len(sys.argv) > 1 else "audio"
args = [godot, "--path", str(root), "--script", "res://Sounds/Walala/verify_music_refresh.gd"]
args += ["--display-driver", "headless", "--audio-driver", "WASAPI"] if mode == "audio" else ["--headless"]
log = root / "output" / ("music_refresh_" + mode + "_" + str(os.getpid()) + ".log")
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
if "FAIL" in text or "ERROR:" in text or "MUSIC REFRESH VERIFY END failures=0" not in text:
    code = 1
sys.exit(code)
