"""Isolated controller event, UI, gameplay and persistence verification."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/controller"
parser = argparse.ArgumentParser()
parser.add_argument("mode", choices=["headless", "capture", "restart", "regression"], default="headless", nargs="?")
parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"))
parser.add_argument("--only", choices=["bindings", "menu", "opening", "storage", "building"])
parser.add_argument("--verbose", action="store_true")
options = parser.parse_args()
godot = next((str(p) for p in [options.godot, shutil.which("godot"), r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"] if p and Path(p).is_file()), None)
if not godot:
    sys.exit("Godot not found; use --godot PATH.")
OUT.mkdir(parents=True, exist_ok=True)
startup = None
if os.name == "nt":
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0

def run(name, extra=(), script="res://Scenes/Input/verify_controllers.gd", marker="CONTROLLER VERIFY END failures=0"):
    args = [godot, "--path", str(ROOT), "--script", script]
    if options.verbose:
        args.append("--verbose")
    if options.mode == "capture":
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--capture"]
    else:
        args += ["--headless", "--"]
    args += list(extra)
    log = OUT / (name + ".log")
    with log.open("w", encoding="utf-8") as output:
        process = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
        try:
            code = process.wait(timeout=120)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            code = 124
    text = log.read_text(encoding="utf-8", errors="replace")
    if "ERROR:" in text or ": FAIL" in text or marker not in text:
        code = code or 1
    for line in text.splitlines():
        if any(token in line for token in ["ERROR", "FAIL", "VERIFY END"]):
            print(line.encode("ascii", errors="backslashreplace").decode("ascii"))
    print("GODOT_EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log)
    return code

if options.mode == "restart":
    fixture = "--fixture=restart_%d" % os.getpid()
    code = run("restart_write", [fixture, "--write"])
    if not code:
        code = run("restart_read", [fixture, "--read"])
elif options.mode == "regression":
    code = 0
    scripts = [("bindings", "Scenes/Input/verify_bindings.gd", "BINDINGS VERIFY END failures=0"),
               ("menu", "Scenes/MainMenu/verify_menu.gd", "MENU VERIFY END failures=0"),
               ("opening", "Scenes/Campaign/verify_opening.gd", "OPENING COMPLETE checks="),
               ("storage", "Scenes/Storage/verify_grid.gd", "STORAGE VERIFY END failures=0"),
               ("building", "Scenes/Building/verify_building.gd", "BUILD VERIFY END failures=0")]
    for name, script, marker in scripts:
        if options.only and options.only != name:
            continue
        wrapper = OUT / ("isolated_" + name + ".gd")
        wrapper.write_text('extends "res://' + script + '"\nfunc _initialize() -> void:\n\tPreferences.file_path = "res://output/controller/' + name + '_preferences.cfg"\n\tSaves.directory = "res://output/controller/' + name + '_saves"\n\tsuper()\n', encoding="utf-8")
        code |= run("regression_" + name, script="res://output/controller/" + wrapper.name, marker=marker)
else:
    code = run(options.mode)
sys.exit(code)
