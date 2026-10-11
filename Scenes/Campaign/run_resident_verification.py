"""Real-engine resident regression using only output/resident_verification settings."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT_BIN", r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
capture = "--capture" in sys.argv
destination = ROOT / "output" / "resident_verification"
destination.mkdir(parents=True, exist_ok=True)
args = [GODOT, "--path", str(ROOT), "--script", "res://Scenes/Campaign/verify_residents.gd"]
args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--capture"] if capture else ["--headless"]
log_path = destination / ("capture.log" if capture else "headless.log")
startup = subprocess.STARTUPINFO() if os.name == "nt" else None
if startup:
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
with log_path.open("w", encoding="utf-8") as output:
    child = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        child.wait(timeout=75)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
log = log_path.read_text(encoding="utf-8", errors="replace")
print(log)
if child.returncode or "FAIL" in log or "SCRIPT ERROR" in log or "ERROR:" in log or "failures=0" not in log:
    raise SystemExit(1)
