"""Run the isolated MyArt shop check, screenshot capture, or interactive preview."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/myart_shop"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("mode", choices=["headless", "capture", "preview"], default="headless", nargs="?")
parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"))
options = parser.parse_args()
candidates = [options.godot, shutil.which("godot"), r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"]
godot = next((str(p) for p in candidates if p and Path(p).is_file()), None)
if not godot:
    sys.exit("Godot not found; set GODOT_BIN or pass --godot PATH.")
OUT.mkdir(parents=True, exist_ok=True)
args = [godot, "--path", str(ROOT), "--script", "res://Scenes/Businesses/verify_myart_shop.gd"]
if options.mode == "headless":
    args.append("--headless")
else:
    args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--myart-" + options.mode]
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0 if options.mode != "preview" else 1
log = OUT / (options.mode + ".log")
with log.open("w", encoding="utf-8") as output:
    child = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
    if options.mode == "preview":
        print("MYART PREVIEW PID", child.pid, "LOG", log)
        sys.exit(0)
    try:
        code = child.wait(timeout=120)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 124
text = log.read_text(encoding="utf-8", errors="replace")
if "ERROR:" in text or ": FAIL" in text or "MYART SHOP VERIFY END failures=0" not in text:
    code = 1
for line in text.splitlines():
    if any(key in line for key in ["ERROR", "FAIL", "VERIFY END"]): print(line)
print("GODOT_EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log)
sys.exit(code)
