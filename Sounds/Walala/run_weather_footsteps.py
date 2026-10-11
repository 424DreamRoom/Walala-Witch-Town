"""Run bounded integration checks; 'audio' uses WASAPI without a game window."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or next(
    (str(p) for p in [
        Path(r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"),
        Path(r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"),
    ] if p.is_file()), None)
if not godot:
    raise SystemExit("Set GODOT_BIN to the Godot executable")
mode = sys.argv[1] if len(sys.argv) > 1 else "headless"
if mode not in ("headless", "audio"):
    raise SystemExit("Use headless or audio")
args = [godot, "--path", str(root), "--script", "res://Sounds/Walala/verify_weather_footsteps.gd"]
args += ["--display-driver", "headless", "--audio-driver", "WASAPI"] if mode == "audio" else ["--headless"]
log = root / "output" / ("weather_footsteps_" + mode + ".log")
log.parent.mkdir(exist_ok=True)
with log.open("w", encoding="utf-8") as output:
    child = subprocess.Popen(args, cwd=root, stdout=output, stderr=subprocess.STDOUT)
    try:
        code = child.wait(timeout=45)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 124
text = log.read_text(encoding="utf-8")
print(text)
print("GODOT_EXIT", code)
if "FAIL" in text or "ERROR:" in text or "WEATHER FOOTSTEPS VERIFY END failures=0" not in text:
    code = 1
sys.exit(code)
