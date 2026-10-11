"""Run actual Godot UI input, pause, persistence and screenshot checks."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Scenes/UI/Verification"
GODOT = os.environ.get("GODOT_BIN", r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
mode = sys.argv[1] if len(sys.argv) > 1 else "headless"
OUT.mkdir(parents=True, exist_ok=True)
kind = "hotbar" if mode.startswith("hotbar") else "brightness" if mode.startswith("brightness") else "rich-text" if mode.startswith("rich-text") else "hud"
script, marker, flag = {
    "hotbar": ("verify_hotbar.gd", "HOTBAR VERIFY END failures=0", "--hotbar-capture"),
    "brightness": ("verify_brightness.gd", "BRIGHTNESS VERIFY END failures=0", "--brightness-capture"),
    "rich-text": ("verify_rich_text.gd", "RICH TEXT VERIFY END failures=0", "--rich-text-capture"),
    "hud": ("verify_ui.gd", "HUD VERIFY END failures=0", "--hud-capture"),
}[kind]
args = [GODOT, "--path", str(ROOT), "--script", "res://Scenes/UI/" + script]
if "--verbose" in sys.argv:
    args += ["--verbose"]
if mode in ("capture", "hotbar-capture", "rich-text-capture", "brightness-capture", "brightness-forward-capture"):
    args += ["--windowed", "--resolution", "1280x720"]
    if mode == "brightness-forward-capture":
        args += ["--rendering-method", "forward_plus"]
    else:
        args += ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"]
    args += ["--", flag]
else:
    args += ["--headless"]
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
log = OUT / (mode + ".log")
with log.open("w", encoding="utf-8") as output:
    process = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        code = process.wait(timeout=75)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
        code = 124
text = log.read_text(encoding="utf-8", errors="replace")
if "ERROR:" in text or ": FAIL" in text or marker not in text:
    code = 1
for line in text.splitlines():
    if any(token in line for token in ["ERROR", "FAIL", "VERIFY END"]):
        print(line.encode("ascii", errors="backslashreplace").decode("ascii"))
print("GODOT_EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log)
sys.exit(code)
