"""Run the replacement storyline with isolated settings/saves; never use user progress."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/story_rebuild_integration"
parser = argparse.ArgumentParser()
parser.add_argument("mode", choices=["headless", "capture"], nargs="?", default="headless")
options = parser.parse_args()
OUT.mkdir(parents=True, exist_ok=True)
godot = next(path for path in [Path(os.environ.get("GODOT_BIN", "godot")), Path(r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"), Path(r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")] if path.is_file())
profile = OUT / ("runtime_" + str(os.getpid()))
env = os.environ.copy()
for variable in ["APPDATA", "LOCALAPPDATA"]:
    folder = profile / variable.lower()
    folder.mkdir(parents=True, exist_ok=True)
    env[variable] = str(folder)

def originals():
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in (ROOT / "MyArt").rglob("*") if path.is_file()}

before = originals()
args = [str(godot), "--path", str(ROOT), "--log-file", str(OUT / (options.mode + ".engine.log")), "--script", "res://Scenes/Campaign/verify_rebuilt_story.gd"]
args += ["--headless"] if options.mode == "headless" else ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--capture"]
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
log_path = OUT / (options.mode + ".log")
with log_path.open("w", encoding="utf-8") as log:
    process = subprocess.Popen(args, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, env=env, startupinfo=startup)
    try:
        process.wait(timeout=100)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
log = log_path.read_text(encoding="utf-8", errors="replace")
assert originals() == before, "Protected originals changed"
print("\n".join(line for line in log.splitlines() if any(token in line for token in ["ERROR", ": FAIL", "COMPLETE"])))
unexpected_errors = [line for line in log.splitlines() if line.startswith("ERROR:") and line != "ERROR: Failed to read the root certificate store."]
passed = process.returncode == 0 and "REBUILT COMPLETE" in log and "failures=0" in log and "SCRIPT ERROR" not in log and not unexpected_errors
report = dict(passed=passed, mode=options.mode, checks=log.count(": PASS"), exit_code=process.returncode, protected_originals=len(before), myart_unchanged=True)
(OUT / (options.mode + ".json")).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report))
raise SystemExit(0 if passed else 1)
