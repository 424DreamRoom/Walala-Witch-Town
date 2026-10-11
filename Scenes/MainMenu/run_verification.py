"""Run the menu checks using a local Godot executable, with bounded lifetime."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Scenes/MainMenu/Verification"
parser = argparse.ArgumentParser()
parser.add_argument("mode", choices=["import", "headless", "capture", "motion", "exit", "startup", "startup_capture", "delete", "delete_capture"], default="headless", nargs="?")
parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"))
parser.add_argument("--verbose", action="store_true")
parser.add_argument("--menu-only", action="store_true", help="Check the menu without loading gameplay.")
options = parser.parse_args()
candidates = [options.godot, shutil.which("godot"), r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe", r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"]
godot = next((str(candidate) for candidate in candidates if candidate and Path(candidate).is_file()), None)
if not godot:
    sys.exit("Godot not found; use --godot PATH or GODOT_BIN.")
OUT.mkdir(parents=True, exist_ok=True)
args = [godot, "--path", str(ROOT)]
if options.verbose:
    args.append("--verbose")
if options.mode == "import":
    args += ["--headless", "--editor", "--quit"]
elif options.mode in ("startup", "startup_capture"):
    args += ["--script", "res://Scenes/MainMenu/verify_startup.gd"]
    if options.mode == "startup_capture":
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--startup-capture"]
    else:
        args += ["--headless"]
elif options.mode in ("delete", "delete_capture"):
    args += ["--script", "res://Scenes/MainMenu/verify_save_deletion.gd"]
    if options.mode == "delete_capture":
        args += ["--windowed", "--resolution", "1920x1080", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--delete-capture"]
    else:
        args += ["--headless"]
elif options.mode == "exit":
    args += ["--headless", "--script", "res://Scenes/MainMenu/verify_exit.gd"]
elif options.mode == "motion":
    args += ["--script", "res://Scenes/MainMenu/capture_motion.gd", "--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--fixed-fps", "12"]
else:
    args += ["--script", "res://Scenes/MainMenu/verify_menu.gd"]
    if options.mode == "capture":
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--menu-capture"]
    else:
        args += ["--headless"]
if options.menu_only:
    args += ["--menu-only"] if "--" in args else ["--", "--menu-only"]
log = OUT / (options.mode + ("_menu_only" if options.menu_only else "") + ".log")
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
with log.open("w", encoding="utf-8") as output:
    process = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        code = process.wait(timeout=90)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
        code = 124
text = log.read_text(encoding="utf-8", errors="replace")
marker = {"delete": "SAVE DELETE VERIFY END failures=0", "delete_capture": "SAVE DELETE VERIFY END failures=0", "exit": "MENU EXIT CONFIRMED", "motion": "MENU MOTION CAPTURE END", "startup": "STARTUP VERIFY END failures=0", "startup_capture": "STARTUP VERIFY END failures=0"}.get(options.mode, "MENU VERIFY END failures=0")
if "ERROR:" in text or ": FAIL" in text or (options.mode != "import" and marker not in text):
    code = 1
for line in text.splitlines():
    if any(token in line for token in ["ERROR", "FAIL", "VERIFY END", "EXIT CONFIRMED"]):
        print(line.encode("ascii", errors="backslashreplace").decode("ascii"))
print("GODOT_EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log)
sys.exit(code)
