"""Bounded regression runs with settings, saves and engine logs inside output."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/wand_modes/regressions"
GODOT = r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
SCRIPTS = {
    "farm": ("Scenes/Farm/verify_farm.gd", "FARM VERIFY END failures=0"),
    "harvest": ("Scenes/Gameplay/verify_harvest.gd", "HARVEST VERIFY END failures=0"),
    "equipment": ("Scenes/Equipment/verify_equipment.gd", "EQUIPMENT VERIFY END failures=0"),
    "hotbar": ("Scenes/UI/verify_hotbar.gd", "HOTBAR VERIFY END failures=0"),
    "saves": ("Scenes/Save/verify_saves.gd", "SAVE VERIFY END failures=0"),
    "campaign": ("Scenes/Campaign/verify_campaign.gd", "CAMPAIGN COMPLETE checks="),
}

def run(name):
    script, marker = SCRIPTS[name]
    profile = OUT / (name + "_" + str(os.getpid()))
    profile.mkdir(parents=True, exist_ok=True)
    resource = "res://" + profile.relative_to(ROOT).as_posix()
    (profile / "isolated.gd").write_text(
        'extends "res://' + script + '"\n'
        'const TestPreferences = preload("res://Scenes/MainMenu/menu_preferences.gd")\n'
        'const TestSaves = preload("res://Scenes/Save/save_store.gd")\n'
        'func _initialize() -> void:\n'
        '\tsuper._initialize()\n'
        '\tTestPreferences.file_path = "' + resource + '/preferences.cfg"\n'
        '\tTestSaves.directory = "' + resource + '/saves"\n'
        '\tTestSaves.end_session()\n', encoding="utf-8")
    log = OUT / (name + ".log")
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    with log.open("w", encoding="utf-8") as output:
        child = subprocess.Popen([GODOT, "--headless", "--path", str(ROOT), "--script", resource + "/isolated.gd", "--log-file", str(profile / "engine.log")], cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
        try:
            code = child.wait(timeout=95)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
            code = 124
    text = log.read_text(encoding="utf-8", errors="replace")
    errors = [line for line in text.splitlines() if "ERROR:" in line or ": FAIL" in line]
    ok = code == 0 and not errors and marker in text
    print(name, "PASS" if ok else "FAIL", "CHECKS", text.count(": PASS"), "EXIT", code, flush=True)
    for line in errors[:10]: print(line, flush=True)
    return ok

names = sys.argv[1:] or list(SCRIPTS)
with ThreadPoolExecutor(max_workers=3) as pool:
    results = list(pool.map(run, names))
sys.exit(0 if all(results) else 1)
