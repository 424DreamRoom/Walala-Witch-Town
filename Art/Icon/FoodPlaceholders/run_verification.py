"""Import and exercise food icons in Godot without accessing player progress."""
from pathlib import Path
import os
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[3]
OUT = PROJECT / "output/food_icons"
GODOT = os.environ.get("GODOT_BIN", r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
mode = sys.argv[1] if len(sys.argv) > 1 else "headless"
OUT.mkdir(parents=True, exist_ok=True)
args = [GODOT, "--path", str(PROJECT)]
if mode == "import":
    args += ["--headless", "--editor", "--import", "--quit"]
else:
    args += ["--script", "res://Scenes/UI/verify_food_icons.gd"]
    if mode == "capture":
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--capture"]
    else:
        args += ["--headless"]
startup = subprocess.STARTUPINFO() if os.name == "nt" else None
if startup:
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
log = OUT / (mode + ".log")
with log.open("w", encoding="utf-8") as output:
    child = subprocess.Popen(args, cwd=PROJECT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        code = child.wait(timeout=90)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 124
text = log.read_text(encoding="utf-8", errors="replace")
for line in text.splitlines():
    if any(token in line for token in ["ERROR", "FAIL", "VERIFY END", "Parse Error"]):
        print(line.encode("ascii", errors="backslashreplace").decode("ascii"))
if "ERROR:" in text or "FAIL" in text or (mode != "import" and "FOOD ICON VERIFY END" not in text):
    code = code or 1
print("GODOT_EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log)
sys.exit(code)
