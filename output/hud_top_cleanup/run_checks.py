"""Run existing HUD/map checks with isolated preferences, saves and outputs."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / str(os.getpid())
OUT.mkdir(parents=True, exist_ok=True)
GODOT = r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
failed = False
for name, source, marker in [
    ("hud", "Scenes/UI/verify_ui.gd", "HUD VERIFY END failures=0"),
    ("map", "Scenes/Map/verify_map.gd", "MAP VERIFY END failures=0"),
]:
    profile = OUT / name
    profile.mkdir()
    resource = "res://" + profile.relative_to(ROOT).as_posix()
    code = (ROOT / source).read_text(encoding="utf-8")
    code = code.replace('const OUT := "res://Scenes/UI/Verification/"', 'const OUT := "' + resource + '/"')
    code = code.replace('const OUT := "res://Scenes/Map/Verification/"', 'const OUT := "' + resource + '/"')
    code = code.replace('Saves.directory = "user://hud_verification"', 'Saves.directory = "' + resource + '/saves"')
    code = code.replace('Preferences.file_path = "user://hud_verification_preferences.cfg"', 'Preferences.file_path = "' + resource + '/preferences.cfg"')
    code = code.replace('Preferences.file_path = "user://map_verification_%d.cfg" % OS.get_process_id()', 'Preferences.file_path = "' + resource + '/preferences.cfg"')
    code = code.replace('func _initialize() -> void:\n', 'func _initialize() -> void:\n\tPreferences.file_path = "' + resource + '/preferences.cfg"\n\tSaves.directory = "' + resource + '/saves"\n\tSaves.end_session()\n', 1)
    script = profile / "verify.gd"
    script.write_text(code, encoding="utf-8")
    log = profile / "verification.log"
    args = [GODOT, "--path", str(ROOT), "--headless", "--log-file", str(profile / "engine.log"), "--script", resource + "/verify.gd"]
    with log.open("w", encoding="utf-8") as output:
        child = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
        try:
            exit_code = child.wait(timeout=90)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
            exit_code = 124
    result = log.read_text(encoding="utf-8", errors="replace")
    passed = exit_code == 0 and marker in result and "ERROR:" not in result and ": FAIL" not in result
    failed = failed or not passed
    print(name, "PASS" if passed else "FAIL", "checks=" + str(result.count(": PASS")), "log=" + str(log), flush=True)
    for line in result.splitlines():
        if any(token in line for token in ["ERROR", ": FAIL", "VERIFY END"]):
            print(line.encode("ascii", errors="backslashreplace").decode("ascii"), flush=True)
sys.exit(1 if failed else 0)
