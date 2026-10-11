"""Run isolated Godot map input checks and optional native UI captures."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Scenes/Map/Verification"
GODOT = os.environ.get("GODOT_BIN", r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
mode = sys.argv[1] if len(sys.argv) > 1 else "headless"
OUT.mkdir(parents=True, exist_ok=True)
args = [GODOT, "--path", str(ROOT), "--script", "res://Scenes/Map/verify_map.gd"]
if mode == "capture":
    args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--capture"]
else:
    args += ["--headless"]
startup = None
if os.name == "nt":
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
log = OUT / (mode + ".log")
with log.open("w", encoding="utf-8") as output:
    process = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        code = process.wait(timeout=80)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
        code = 124
text = log.read_text(encoding="utf-8", errors="replace")
if "ERROR:" in text or ": FAIL" in text or "MAP VERIFY END failures=0" not in text:
    code = 1
for line in text.splitlines():
    if any(token in line for token in ["ERROR", "FAIL", "VERIFY END"]):
        print(line.encode("ascii", errors="backslashreplace").decode("ascii"))
print("GODOT_EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log)
sys.exit(code)
