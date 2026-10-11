"""Wait for our own hidden Godot importer before starting game verification."""
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[2]
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
log = root / "output/town_expansion/import_waited.log"
with log.open("w", encoding="utf-8") as stream:
    result = subprocess.run([
        r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe",
        "--headless", "--path", str(root), "--editor", "--import",
    ], stdout=stream, stderr=subprocess.STDOUT, startupinfo=startup, timeout=180)
print(log.read_text(encoding="utf-8")[-3500:])
raise SystemExit(result.returncode)
