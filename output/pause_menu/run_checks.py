"""Run existing isolated suites with all generated output in this review folder."""
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
kind = sys.argv[1]
sources = {
    "save": ("Scenes/Save/verify_saves.gd", "SAVE VERIFY END failures=0"),
    "localization": ("Localization/verify_localization.gd", "LOCALIZATION VERIFY END failures=0"),
    "capture": ("output/pause_menu/capture.gd", "PAUSE CAPTURE COMPLETE"),
}
source, marker = sources[kind]
destination = OUT / kind
destination.mkdir(parents=True, exist_ok=True)
script = ROOT / source
if kind != "capture":
    text = script.read_text(encoding="utf-8")
    text = re.sub(r'const OUT := "[^"]+"', 'const OUT := "res://output/pause_menu/' + kind + '/"', text)
    script = destination / "verify.gd"
    script.write_text(text, encoding="utf-8")
godot = os.environ.get("GODOT_BIN", r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
args = [godot, "--path", str(ROOT), "--script", "res://" + script.relative_to(ROOT).as_posix()]
args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"] if kind == "capture" else ["--headless"]
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
log = destination / "run.log"
with log.open("w", encoding="utf-8") as stream:
    process = subprocess.Popen(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        code = process.wait(timeout=55)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
        code = 124
text = log.read_text(encoding="utf-8", errors="replace")
for line in text.splitlines():
    if any(token in line for token in ["ERROR", "FAIL", "VERIFY END", "PAUSE CAPTURE"]):
        print(line.encode("ascii", errors="backslashreplace").decode("ascii"))
print(kind, "PASS_COUNT", text.count(": PASS"), "EXIT", code, "LOG", log)
sys.exit(0 if code == 0 and marker in text and not any(token in text for token in ["ERROR:", ": FAIL"]) else 1)
