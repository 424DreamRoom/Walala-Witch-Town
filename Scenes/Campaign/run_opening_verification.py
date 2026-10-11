"""Doorstep opening checks with isolated settings/saves and protected-art hashes."""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/doorstep_opening"
parser = argparse.ArgumentParser()
parser.add_argument("mode", choices=["headless", "capture"], nargs="?", default="headless")
options = parser.parse_args()
OUT.mkdir(parents=True, exist_ok=True)

def originals():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (ROOT / "MyArt").rglob("*") if p.is_file()}

before = originals()
godot = os.environ.get("GODOT_BIN", r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")
args = [godot, "--path", str(ROOT), "--script", "res://Scenes/Campaign/verify_opening.gd"]
args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--capture"] if options.mode == "capture" else ["--headless"]
startup = subprocess.STARTUPINFO() if os.name == "nt" else None
if startup:
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
log_path = OUT / (options.mode + ".log")
with log_path.open("w", encoding="utf-8") as log:
    process = subprocess.Popen(args, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        process.wait(timeout=55)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
text = log_path.read_text(encoding="utf-8", errors="replace")
assert originals() == before, "Protected originals changed"
print("\n".join(line for line in text.splitlines() if any(token in line for token in ["ERROR", "FAIL", "COMPLETE"])))
print("OPENING", options.mode, "PASS_COUNT", text.count(": PASS"), "EXIT", process.returncode, "MYART_UNCHANGED", len(before))
ok = process.returncode == 0 and "OPENING COMPLETE" in text and " failures=0" in text and not any(token in text for token in ["ERROR:", "SCRIPT ERROR", ": FAIL"])
raise SystemExit(0 if ok else 1)
