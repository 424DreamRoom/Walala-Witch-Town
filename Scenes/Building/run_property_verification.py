"""Property checks and screenshots use a bounded Godot process and isolated data."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/property_service"
OUT.mkdir(parents=True, exist_ok=True)
GODOT = os.environ.get("GODOT_BIN", r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")


def originals():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (ROOT / "MyArt").rglob("*") if p.is_file()}


before = originals()
profile = OUT / ("profile_" + str(os.getpid()))
profile.mkdir(exist_ok=True)
env = os.environ.copy()
for key in ("APPDATA", "LOCALAPPDATA"):
    target = profile / key
    target.mkdir(exist_ok=True)
    env[key] = str(target)
mode = sys.argv[1] if len(sys.argv) > 1 else "headless"
script = {
    "housing": "Scenes/Building/verify_housing.gd",
    "restaurant": "Scenes/Gameplay/verify_restaurant_service.gd",
    "localization": "Localization/verify_localization.gd",
    "map": "Scenes/Map/verify_map.gd",
}.get(mode, "Scenes/Building/verify_property.gd")
args = [GODOT, "--path", str(ROOT), "--script", "res://" + script,
        "--log-file", str(profile / "engine.log")]
if mode == "capture":
    args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--property-capture"]
else:
    args += ["--headless"]
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
log = profile / (mode + ".log")
with log.open("w", encoding="utf-8") as output:
    process = subprocess.Popen(args, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        code = process.wait(timeout=90)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
        code = 124
result = log.read_text(encoding="utf-8", errors="replace")
errors = [line for line in result.splitlines() if "ERROR:" in line
          and "Failed to read the root certificate store." not in line]
if errors or ": FAIL" in result or "VERIFY END" not in result:
    code = 1
assert before == originals(), "MyArt source hashes changed"
(OUT / (mode + "_report.json")).write_text(json.dumps({
    "mode": mode, "passed": code == 0, "checks_passed": result.count(": PASS"),
    "summary": [line for line in result.splitlines() if "VERIFY END" in line],
    "log": str(log.relative_to(ROOT)), "script_errors": errors,
    "myart_unchanged": True, "myart_sha256": before,
    "environment_notes": [line for line in result.splitlines()
                          if "Failed to read the root certificate store." in line],
}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
for line in result.splitlines():
    if any(word in line for word in ("ERROR", "FAIL", "VERIFY END")):
        print(line.encode("ascii", errors="backslashreplace").decode("ascii"))
print("EXIT", code, "PASS_COUNT", result.count(": PASS"), "MYART_UNCHANGED", "LOG", log)
sys.exit(code)
