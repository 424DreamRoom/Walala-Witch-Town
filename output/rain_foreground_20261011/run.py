from pathlib import Path
import os
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
method = sys.argv[1] if len(sys.argv) > 1 else "headless"
args = [r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe", "--path", str(root), "--fixed-fps", "60", "--quit-after", "1800", "--script", "res://output/rain_foreground_20261011/verify_rain_foreground.gd"]
if method == "headless":
    args += ["--headless"]
else:
    args += ["--windowed", "--resolution", "1280x720", "--rendering-method", method, "--rendering-driver", "opengl3" if method == "gl_compatibility" else "d3d12", "--", "--capture"]
log = Path(__file__).with_name(method + ".log")
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
with log.open("w", encoding="utf-8") as out:
    child = subprocess.Popen(args, cwd=root, stdout=out, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        code = child.wait(timeout=60)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 124
text = log.read_text(encoding="utf-8")
print(text)
print("GODOT_EXIT", code)
sys.exit(code or int("FAIL" in text or "ERROR:" in text or "failures=0" not in text))
