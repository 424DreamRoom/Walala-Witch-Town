"""Run the failing existing UI checks against an unchanged HEAD snapshot."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/wand_modes/baseline"
OUT.mkdir(parents=True, exist_ok=True)
GODOT = r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
for name in ["Art", "Sounds", "addons", "Localization", "MyArt"]:
    target = OUT / name
    if not target.exists():
        subprocess.run(["powershell", "-NoProfile", "-Command", "New-Item -ItemType Junction -Path '" + str(target) + "' -Target '" + str(ROOT / name) + "' | Out-Null"], check=True)
for source in (ROOT / "Scenes").rglob("*"):
    if source.is_file() and source.suffix in [".gd", ".gdshader", ".tscn", ".tres", ".json", ".uid", ".tsv", ".cfg"]:
        target = OUT / source.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
for relative in ["project.godot", "icon.svg.aseprite"]:
    shutil.copy2(ROOT / relative, OUT / relative)
changed = subprocess.check_output(["git", "diff", "--name-only", "--", "Scenes", "project.godot"], cwd=ROOT, text=True).splitlines()
for relative in changed:
    (OUT / relative).write_bytes(subprocess.check_output(["git", "show", "HEAD:" + relative], cwd=ROOT))
(OUT / ".godot").mkdir(exist_ok=True)
if not (OUT / ".godot/imported").exists():
    subprocess.run(["powershell", "-NoProfile", "-Command", "New-Item -ItemType Junction -Path '" + str(OUT / ".godot/imported") + "' -Target '" + str(ROOT / ".godot/imported") + "' | Out-Null"], check=True)
shutil.copy2(ROOT / ".godot/extension_list.cfg", OUT / ".godot/extension_list.cfg")
shutil.copy2(ROOT / ".godot/global_script_class_cache.cfg", OUT / ".godot/global_script_class_cache.cfg")

def run(name, source):
    profile = OUT / (name + "_" + str(os.getpid()))
    profile.mkdir(exist_ok=True)
    resource = "res://" + profile.relative_to(OUT).as_posix()
    (profile / "isolated.gd").write_text('extends "res://' + source + '"\nfunc _initialize() -> void:\n\tsuper._initialize()\n\tpreload("res://Scenes/MainMenu/menu_preferences.gd").file_path = "' + resource + '/preferences.cfg"\n\tpreload("res://Scenes/Save/save_store.gd").directory = "' + resource + '/saves"\n\tpreload("res://Scenes/Save/save_store.gd").end_session()\n', encoding="utf-8")
    log = OUT / (name + ".log")
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    with log.open("w", encoding="utf-8") as out:
        child = subprocess.Popen([GODOT, "--headless", "--path", str(OUT), "--script", resource + "/isolated.gd", "--log-file", str(profile / "engine.log")], stdout=out, stderr=subprocess.STDOUT, startupinfo=startup)
        try:
            code = child.wait(timeout=45)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
            code = 124
    text = log.read_text(encoding="utf-8", errors="replace")
    print("BASELINE", name, "EXIT", code, "PASS_COUNT", text.count(": PASS"), flush=True)
    for line in text.splitlines():
        if ": FAIL" in line or "SCRIPT ERROR:" in line: print(line, flush=True)

with ThreadPoolExecutor(max_workers=2) as pool:
    list(pool.map(lambda entry: run(*entry), [("equipment", "Scenes/Equipment/verify_equipment.gd"), ("saves", "Scenes/Save/verify_saves.gd")]))
