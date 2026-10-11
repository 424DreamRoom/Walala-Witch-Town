"""Run quest progression in the real engine using isolated test preferences/saves."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT_BIN", r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
capture = "--capture" in sys.argv
target = ROOT / "output/quest_pacing"
target.mkdir(parents=True, exist_ok=True)
args = [GODOT, "--path", str(ROOT), "--script", "res://Scenes/Campaign/verify_quest_pacing.gd"]
args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--capture"] if capture else ["--headless"]
startup = subprocess.STARTUPINFO() if os.name == "nt" else None
if startup:
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
log = target / ("capture.log" if capture else "headless.log")
with log.open("w", encoding="utf-8") as output:
    process = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        process.wait(timeout=45)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
text = log.read_text(encoding="utf-8", errors="replace")
print(text)
if process.returncode or "ERROR:" in text or "FAIL" in text or "failures=0" not in text:
    raise SystemExit(1)
