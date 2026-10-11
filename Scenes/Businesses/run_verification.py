"""Bounded Godot checks; only the child created here can be terminated."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Art/Environment/Hearthwood/Verification/Businesses"
parser = argparse.ArgumentParser()
parser.add_argument("mode", choices=["import", "headless", "capture", "home", "lane", "loop", "town", "town_capture"], default="headless", nargs="?")
parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"))
options = parser.parse_args()
candidates = [options.godot, shutil.which("godot"), r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe", r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"]
godot = next((str(p) for p in candidates if p and Path(p).is_file()), None)
if not godot:
    sys.exit("Godot not found; set GODOT_BIN or use --godot PATH.")
OUT.mkdir(parents=True, exist_ok=True)
args = [godot, "--path", str(ROOT)]
marker = "BUSINESS VERIFY END failures=0"
if options.mode == "import":
    args += ["--headless", "--editor", "--quit"]
elif options.mode == "lane":
    args += ["--headless", "--scene", "res://Scenes/LanternLane/lantern_lane.tscn", "--", "--lane-test"]
    marker = ""
else:
    script = {"home": "Scenes/WitchHome/verify_home.gd", "loop": "Scenes/Gameplay/verify_loop.gd", "town": "Scenes/LanternLane/verify_town_plan.gd", "town_capture": "Scenes/LanternLane/verify_town_plan.gd"}.get(options.mode, "Scenes/Businesses/verify_businesses.gd")
    args += ["--script", "res://" + script]
    if options.mode in ["capture", "town_capture"]:
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--town-capture" if options.mode == "town_capture" else "--business-capture"]
    else:
        args += ["--headless"]
    marker = {"home": "HOME VERIFY END failures=0", "loop": "LOOP VERIFY END failures=0", "town": "TOWN PLAN VERIFY END failures=0", "town_capture": "TOWN PLAN VERIFY END failures=0"}.get(options.mode, marker)
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
log = OUT / (options.mode + ".log")
with log.open("w", encoding="utf-8") as output:
    child = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        code = child.wait(timeout=150)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 124
text = log.read_text(encoding="utf-8", errors="replace")
if "ERROR:" in text or ": FAIL" in text or (options.mode != "import" and marker not in text):
    code = 1
for line in text.splitlines():
    if any(key in line for key in ["ERROR", "FAIL", "VERIFY END"]):
        print(line.encode("ascii", errors="backslashreplace").decode("ascii"))
print("GODOT_EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log)
sys.exit(code)
