"""Run native key capture, gameplay, and fresh-process persistence checks."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Scenes/Input/Verification"
parser = argparse.ArgumentParser()
parser.add_argument("mode", choices=["headless", "capture", "restart"], default="headless", nargs="?")
parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"))
options = parser.parse_args()
candidates = [options.godot, shutil.which("godot"), r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"]
godot = next((str(path) for path in candidates if path and Path(path).is_file()), None)
if not godot:
    sys.exit("Godot not found; use --godot PATH or GODOT_BIN.")
OUT.mkdir(parents=True, exist_ok=True)
startup = None
if os.name == "nt":
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0

def run(name, extra):
    args = [godot, "--path", str(ROOT), "--script", "res://Scenes/Input/verify_bindings.gd"]
    if options.mode == "capture":
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--capture"]
    else:
        args += ["--headless", "--"]
    args += extra
    log = OUT / (name + ".log")
    with log.open("w", encoding="utf-8") as output:
        process = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
        try:
            code = process.wait(timeout=100)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            code = 124
    text = log.read_text(encoding="utf-8", errors="replace")
    if "ERROR:" in text or ": FAIL" in text or "BINDINGS VERIFY END failures=0" not in text:
        code = 1
    for line in text.splitlines():
        if any(token in line for token in ["ERROR", "FAIL", "VERIFY END"]):
            print(line.encode("ascii", errors="backslashreplace").decode("ascii"))
    print("GODOT_EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log)
    return code

if options.mode == "restart":
    config = "--preferences=user://bindings_restart_%d.cfg" % os.getpid()
    code = run("restart_write", [config, "--write-preference"])
    if not code:
        code = run("restart_read", [config, "--read-preference"])
else:
    code = run(options.mode, [])
sys.exit(code)
