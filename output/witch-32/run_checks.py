"""Run character integration checks with hidden windows and isolated user data."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/witch-32"
GODOT = "C:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
MODE = sys.argv[1]
env = os.environ.copy()
for name in ("APPDATA", "LOCALAPPDATA"):
    profile = OUT / "profile" / MODE / name
    profile.mkdir(parents=True, exist_ok=True)
    env[name] = str(profile)
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
args = [GODOT, "--path", str(ROOT)]
if MODE == "import":
    args += ["--headless", "--editor", "--import"]
elif MODE == "lane":
    args += ["--headless", "--scene", "res://Scenes/LanternLane/lantern_lane.tscn", "--", "--lane-test"]
else:
    script = "capture_harvest.gd" if MODE == "harvest" else "capture.gd"
    args += ["--script", "res://output/witch-32/" + script, "--windowed", "--resolution", "1280x720",
             "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"]
    if MODE != "harvest":
        args += ["--", "--no-loop"]
log = OUT / (MODE + ".log")
with log.open("w", encoding="utf-8") as stream:
    result = subprocess.run(args, cwd=ROOT, env=env, startupinfo=startup, stdout=stream,
                            stderr=subprocess.STDOUT, timeout=180)
text = log.read_text(encoding="utf-8", errors="replace")
lines = text.splitlines()
print(MODE, "exit=", result.returncode, "PASS=", text.count(": PASS"), "FAIL=", text.count(": FAIL"))
for line in lines:
    if any(word in line for word in ("ERROR", "FAIL", "VERIFY END", "TEST END", "RENDER END")):
        print(line)
print("log:", log)
sys.exit(result.returncode or (1 if "SCRIPT ERROR" in text else 0))
