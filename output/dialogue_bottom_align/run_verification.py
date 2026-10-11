"""Run existing isolated UI checks and capture the changed dialogue layout."""
from pathlib import Path
import concurrent.futures
import os
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
GODOT = os.environ.get("GODOT_BIN", r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")

def run(name, script, flags, marker):
    log = OUT / (name + ".log")
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    args = [GODOT, "--path", str(ROOT), "--script", script] + flags
    with log.open("w", encoding="utf-8") as output:
        process = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
        try:
            code = process.wait(timeout=75)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            code = 124
    text = log.read_text(encoding="utf-8", errors="replace")
    okay = code == 0 and marker in text and "ERROR:" not in text and ": FAIL" not in text
    lines = [line for line in text.splitlines() if any(token in line for token in ["ERROR", "FAIL", "VERIFY END", "GUIDE COMPLETE"])]
    return name, okay, text.count(": PASS"), lines

if __name__ == "__main__":
    jobs = [
        ("hud_headless", "res://Scenes/UI/verify_ui.gd", ["--headless"], "HUD VERIFY END failures=0"),
        ("guide_capture", "res://output/dialogue_bottom_align/capture.gd", ["--windowed", "--resolution", "1920x1080", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--capture"], "GUIDE COMPLETE checks="),
    ]
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda job: run(*job), jobs))
    for name, okay, count, lines in results:
        print(name, "PASS" if okay else "FAIL", "checks", count)
        for line in lines:
            print(line.encode("ascii", errors="backslashreplace").decode("ascii"))
    raise SystemExit(0 if all(result[1] for result in results) else 1)
