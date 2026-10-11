"""Save checks run in isolated user-data folders, including a fresh-process load."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Scenes/Save/Verification"
parser = argparse.ArgumentParser()
parser.add_argument("mode", choices=["headless", "capture", "restart", "close", "regression", "harvest", "businesses", "schedule"], nargs="?", default="headless")
parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"))
options = parser.parse_args()
candidates = [options.godot, shutil.which("godot"), r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe", r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"]
godot = next((str(candidate) for candidate in candidates if candidate and Path(candidate).is_file()), None)
if not godot:
    sys.exit("Godot not found; use --godot PATH.")
OUT.mkdir(parents=True, exist_ok=True)
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
modes = ["restart_write", "restart_read"] if options.mode == "restart" else ["close_write", "close_read"] if options.mode == "close" else [options.mode]
exit_code = 0
for mode in modes:
    script = {"schedule": "res://Scenes/Save/verify_autosave_schedule.gd", "regression": "res://Scenes/Gameplay/verify_loop.gd", "harvest": "res://Scenes/Gameplay/verify_harvest.gd", "businesses": "res://Scenes/Businesses/verify_businesses.gd"}.get(mode, "res://Scenes/Save/verify_saves.gd")
    args = [godot, "--path", str(ROOT), "--script", script]
    if mode == "capture":
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--save-capture"]
    else:
        args += ["--headless"]
        if mode.startswith("restart_"):
            args += ["--", "--" + mode.replace("_", "-")]
        elif mode.startswith("close_"):
            args += ["--", "--" + mode.replace("_", "-")]
    log = OUT / (mode + ".log")
    with log.open("w", encoding="utf-8") as output:
        process = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
        try:
            code = process.wait(timeout=90)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            code = 124
    text = log.read_text(encoding="utf-8", errors="replace")
    marker = {"schedule": "AUTOSAVE SCHEDULE VERIFY END failures=0", "regression": "LOOP VERIFY END failures=0", "harvest": "HARVEST VERIFY END failures=0", "businesses": "BUSINESS VERIFY END failures=0", "close_write": "SAVE CLOSE REQUEST SENT"}.get(mode, "SAVE VERIFY END failures=0")
    if "ERROR:" in text or ": FAIL" in text or marker not in text:
        code = 1
    for line in text.splitlines():
        if any(token in line for token in ["ERROR", "FAIL", "VERIFY END"]):
            print(line.encode("ascii", errors="backslashreplace").decode("ascii"))
    print("GODOT_EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log)
    exit_code = exit_code or code
    if code:
        break
sys.exit(exit_code)
