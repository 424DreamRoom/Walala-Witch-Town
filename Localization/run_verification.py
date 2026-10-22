"""Bounded native Godot checks, including persistence across two fresh processes."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Localization/Verification"
parser = argparse.ArgumentParser()
parser.add_argument("mode", choices=["headless", "capture", "restart", "csv"], default="headless", nargs="?")
parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"))
options = parser.parse_args()
candidates = [options.godot, shutil.which("godot"), r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe",
              r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"]
godot = next((str(path) for path in candidates if path and Path(path).is_file()), None)
if not godot:
    sys.exit("Godot not found; use --godot PATH or GODOT_BIN.")
OUT.mkdir(parents=True, exist_ok=True)
profile_directory = OUT / ("profile_%d" % os.getpid())
profile_directory.mkdir(parents=True, exist_ok=True)
test_environment = dict(os.environ)
for variable in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME"):
    test_environment[variable] = str(profile_directory)
startup = None
if os.name == "nt":
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0

def run(name, extra):
    script = "verify_csv_catalog.gd" if options.mode == "csv" else "verify_localization.gd"
    args = [godot, "--path", str(ROOT), "--log-file", str(profile_directory / (name + ".engine.log")),
            "--script", "res://Localization/" + script]
    if options.mode == "capture":
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--capture"]
    else:
        args += ["--headless", "--"]
    args += extra
    log = OUT / (name + ".log")
    with log.open("w", encoding="utf-8") as output:
        process = subprocess.Popen(args, cwd=ROOT, env=test_environment, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
        try:
            code = process.wait(timeout=120)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            code = 124
    text = log.read_text(encoding="utf-8", errors="replace")
    marker = "CSV CATALOG VERIFY END failures=0" if options.mode == "csv" else "LOCALIZATION VERIFY END failures=0"
    # This workstation's sandbox cannot read the Windows certificate store.
    # It is unrelated to offline localization; retain every other engine error.
    errors = [line for line in text.splitlines() if "ERROR:" in line and line != "ERROR: Failed to read the root certificate store."]
    if errors or ": FAIL" in text or marker not in text:
        code = 1
    for line in text.splitlines():
        if any(token in line for token in ["ERROR", "FAIL", "VERIFY END", "MISSING GLYPHS"]):
            print(line.encode("ascii", errors="backslashreplace").decode("ascii"))
    print("GODOT_EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log)
    return code

if options.mode == "restart":
    config = "--preferences=user://localization_restart_%d.cfg" % os.getpid()
    code = run("restart_write", [config, "--write-preference"])
    if not code:
        code = run("restart_read", [config, "--read-preference"])
else:
    code = run(options.mode, [])
sys.exit(code)
