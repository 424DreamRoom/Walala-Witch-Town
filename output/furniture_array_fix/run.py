import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[2]
tag = sys.argv[1] if len(sys.argv) > 1 else "after"
log = root / "output/furniture_array_fix" / (tag + ".log")
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
with log.open("w", encoding="utf-8") as output:
    result = subprocess.run([
        r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe",
        "--headless", "--path", str(root), "--script",
        "res://output/furniture_array_fix/verify.gd", "--quit-after", "120",
    ], cwd=root, stdout=output, stderr=subprocess.STDOUT,
        startupinfo=startup, timeout=30)
text = log.read_text(encoding="utf-8")
print(text)
passed = result.returncode == 0 and "ERROR:" not in text and ": FAIL" not in text and "FURNITURE SAVE VERIFY END failures=0" in text
print("GODOT_EXIT", result.returncode, "PASS_COUNT", text.count(": PASS"), "LOG", log)
sys.exit(0 if passed else 1)
