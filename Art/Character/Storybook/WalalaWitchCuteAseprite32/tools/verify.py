"""Godot checks with isolated preferences, save paths and OS user data."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[5]
OUT = ROOT / "output/witch-cute-aseprite32"
GODOT = "C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
MODE = sys.argv[1]
if MODE not in ("lane", "render"):
    raise SystemExit("Usage: verify.py lane|render")
OUT.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
for name in ("APPDATA", "LOCALAPPDATA"):
    profile = OUT / "profile" / MODE / name
    profile.mkdir(parents=True, exist_ok=True)
    env[name] = str(profile)
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
args = [GODOT, "--path", str(ROOT)]
if MODE == "lane":
    args += ["--headless", "--script", "res://Art/Character/Storybook/WalalaWitchCuteAseprite32/tools/verify_lane.gd", "--", "--lane-test"]
else:
    args += ["--script", "res://Art/Character/Storybook/WalalaWitchCuteAseprite32/tools/verify_render.gd",
             "--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility",
             "--rendering-driver", "opengl3", "--", "--no-loop"]
log = OUT / (MODE + ".log")
with log.open("w", encoding="utf-8") as stream:
    result = subprocess.run(args, cwd=ROOT, env=env, startupinfo=startup, stdout=stream,
                            stderr=subprocess.STDOUT, timeout=180)
text = log.read_text(encoding="utf-8", errors="replace")
print(MODE, "exit=", result.returncode, "PASS=", text.count(": PASS"), "FAIL=", text.count(": FAIL"))
for line in text.splitlines():
    if any(word in line for word in ("ERROR", "FAIL", "VERIFY END", "TEST END", "RENDER END")):
        print(line)
print("log:", log)
sys.exit(result.returncode or (1 if "SCRIPT ERROR" in text else 0))
