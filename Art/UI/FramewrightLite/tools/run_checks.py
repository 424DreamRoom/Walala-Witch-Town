"""Run the existing interaction suites with isolated Framewright logs/captures."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / "Art/UI/FramewrightLite/Verification"
parser = argparse.ArgumentParser()
parser.add_argument("mode", choices=["menu", "loop", "preview"])
options = parser.parse_args()
candidates = [os.environ.get("GODOT_BIN"), shutil.which("godot"),
              r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe",
              r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"]
godot = next((p for p in candidates if p and Path(p).is_file()), None)
if not godot:
    sys.exit("Godot not found; set GODOT_BIN.")
OUT.mkdir(parents=True, exist_ok=True)
if options.mode == "preview":
    script = "res://Art/UI/FramewrightLite/tools/verify_preview.gd"
    arguments = []
    marker = "UI SKIN VERIFY END failures=0"
else:
    name = "Scenes/MainMenu/verify_menu.gd" if options.mode == "menu" else "Scenes/Gameplay/verify_loop.gd"
    text = (ROOT / name).read_text(encoding="utf-8")
    old = "res://Scenes/MainMenu/Verification/" if options.mode == "menu" else "res://Scenes/Gameplay/Verification/"
    text = text.replace(old, "res://Art/UI/FramewrightLite/Verification/")
    copy = OUT / ("verify_" + options.mode + ".gd")
    copy.write_text(text, encoding="utf-8")
    script = "res://" + copy.relative_to(ROOT).as_posix()
    arguments = ["--menu-capture"] if options.mode == "menu" else ["--loop-render"]
    marker = "MENU VERIFY END failures=0" if options.mode == "menu" else "LOOP VERIFY END failures=0"
args = [godot, "--path", str(ROOT), "--script", script, "--windowed", "--resolution", "1280x720",
        "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--"] + arguments
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
log = OUT / (options.mode + ".log")
with log.open("w", encoding="utf-8") as stream:
    child = subprocess.Popen(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        code = child.wait(timeout=150)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 124
text = log.read_text(encoding="utf-8", errors="replace")
if marker not in text or "ERROR:" in text or ": FAIL" in text:
    code = 1
for line in text.splitlines():
    if any(word in line for word in ["ERROR:", ": FAIL", "VERIFY END"]):
        print(line)
print("GODOT_EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log)
sys.exit(code)
