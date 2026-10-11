"""Bounded five-channel audio checks with isolated preferences and save paths."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("mode", choices=["headless", "audio", "capture"], default="headless", nargs="?")
parser.add_argument("--verbose", action="store_true")
parser.add_argument("--pause", action="store_true", help="Verify background playback in paused menus")
parser.add_argument("--backpack", action="store_true", help="Verify real backpack audio with an isolated world")
options = parser.parse_args()
if options.pause and options.backpack:
    parser.error("Choose --pause or --backpack")
if (options.pause or options.backpack) and options.mode == "capture":
    parser.error("--pause and --backpack support headless or audio modes")
godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or next(
    (str(path) for path in [
        Path(r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"),
        Path(r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"),
    ] if path.is_file()), None)
if not godot:
    sys.exit("Set GODOT_BIN to the Godot executable")
script = "verify_backpack_audio.gd" if options.backpack else "verify_pause_audio.gd" if options.pause else "verify_audio_settings.gd"
args = [godot, "--path", str(root), "--script", "res://Sounds/Walala/" + script]
if options.verbose:
    args.append("--verbose")
if options.mode == "capture":
    args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--audio-settings-capture"]
elif options.mode == "audio":
    args += ["--display-driver", "headless", "--audio-driver", "WASAPI"]
else:
    args += ["--headless"]
out = root / "output/audio_settings"
out.mkdir(parents=True, exist_ok=True)
log = out / (("backpack_" if options.backpack else "pause_" if options.pause else "") + options.mode + ".log")
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
with log.open("w", encoding="utf-8") as output:
    child = subprocess.Popen(args, cwd=root, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        code = child.wait(timeout=60)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 124
text = log.read_text(encoding="utf-8", errors="replace")
for line in text.splitlines():
    if any(token in line for token in ["ERROR", "FAIL", "VERIFY END"]):
        print(line.encode("ascii", errors="backslashreplace").decode("ascii"))
marker = "PAUSE AUDIO VERIFY END failures=0" if options.pause or options.backpack else "AUDIO SETTINGS VERIFY END failures=0"
if "ERROR:" in text or ": FAIL" in text or marker not in text:
    code = 1
print("GODOT_EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log)
sys.exit(code)
