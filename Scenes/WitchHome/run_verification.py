"""Bounded verification using only the Godot process created by this runner."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GODOT = r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
OUT = ROOT / "Art/Environment/Hearthwood/Verification"
OUT.mkdir(parents=True, exist_ok=True)
mode = sys.argv[1] if len(sys.argv) > 1 else "headless"
args = [GODOT, "--path", str(ROOT)]
if mode == "import":
    args += ["--headless", "--editor", "--quit"]
elif mode == "lane":
    args += ["--headless", "--scene", "res://Scenes/LanternLane/lantern_lane.tscn", "--", "--lane-test"]
elif mode in ("ambient", "ambient_capture"):
    args += ["--script", "res://Scenes/Gameplay/verify_ambient.gd"]
    if mode == "ambient_capture":
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--ambient-capture"]
    else:
        args += ["--headless"]
elif mode in ("outdoors", "outdoors_capture"):
    args += ["--script", "res://Scenes/LanternLane/verify_outdoors.gd"]
    if mode == "outdoors_capture":
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--outdoor-capture"]
    else:
        args += ["--headless"]
else:
    args += ["--script", "res://Scenes/WitchHome/verify_home.gd"]
    if mode == "capture":
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--home-capture"]
    else:
        args += ["--headless"]
if "--verbose" in sys.argv[2:]:
    args.append("--verbose")
log = OUT / (mode + ".log")
with log.open("w", encoding="utf-8") as out:
    child = subprocess.Popen(args, cwd=ROOT, stdout=out, stderr=subprocess.STDOUT)
    try:
        code = child.wait(timeout=120)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 124
text = log.read_text(encoding="utf-8", errors="replace")
end_marker = "AMBIENT VERIFY END failures=0" if mode in ("ambient", "ambient_capture") else "OUTDOOR VERIFY END failures=0" if mode in ("outdoors", "outdoors_capture") else "HOME VERIFY END failures=0"
if "ERROR:" in text or ": FAIL" in text or (mode not in ("import", "lane") and end_marker not in text):
    code = 1
lines = [line for line in text.splitlines() if "ERROR" in line or "FAIL" in line or "VERIFY END" in line]
print("\n".join(lines).encode("ascii", errors="backslashreplace").decode("ascii"))
print("GODOT_EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log)
sys.exit(code)
