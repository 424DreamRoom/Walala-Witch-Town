"""Check the real editor plugin observes a saved Excel edit, in a fixture."""
import csv
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
FIXTURE = OUT / "editor_fixture"
FIXTURE.mkdir(exist_ok=True)
for relative in ("Localization/build_catalog.py", "Localization/excel_catalog.py", "Localization/watch_catalog.py",
                 "addons/walala_localization/plugin.cfg", "addons/walala_localization/plugin.gd", "Excel/Localization/Localization.xlsx"):
    target = FIXTURE / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / relative, target)
(FIXTURE / "Localization/localized_text.gd").write_text("extends RefCounted\n", encoding="utf-8")
audio = FIXTURE / "Sounds/Walala"
audio.mkdir(parents=True, exist_ok=True)
(audio / "audio_manager.gd").write_text("extends Node\n", encoding="utf-8")
(FIXTURE / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Excel Editor Plugin Verification"\n[editor_plugins]\nenabled=PackedStringArray("res://addons/walala_localization/plugin.cfg")\n[walala]\nlocalization/python_executable="' + str(Path(os.sys.executable)).replace("\\", "/") + '"\n', encoding="utf-8")
profile = OUT / "editor_profile"
profile.mkdir(exist_ok=True)
environment = dict(os.environ)
for variable in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME"):
    environment[variable] = str(profile)
log_path = OUT / "editor.log"
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
target_csv = FIXTURE / "Excel/Localization/Localization.csv"


def wait_for(predicate, message):
    deadline = time.monotonic() + 30
    while not predicate():
        if process.poll() is not None or time.monotonic() >= deadline:
            raise RuntimeError(message + "\n" + log_path.read_text(encoding="utf-8", errors="replace"))
        time.sleep(0.2)


with log_path.open("w", encoding="utf-8") as log:
    process = subprocess.Popen([str(ROOT / "output/audio_world/engine/godot.exe"), "--headless", "--editor", "--path", str(FIXTURE),
                                "--log-file", str(OUT / "editor.engine.log")], cwd=FIXTURE, env=environment,
                               stdout=log, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        wait_for(lambda: target_csv.is_file() and "LOCALIZATION CSV" in log_path.read_text(encoding="utf-8", errors="replace"), "Initial editor export did not finish")
        xlsx = FIXTURE / "Excel/Localization/Localization.xlsx"
        with ZipFile(xlsx) as source:
            members = {name: source.read(name) for name in source.namelist()}
        changed = False
        for name, value in members.items():
            if name.endswith(".xml") and b"Blue wand" in value:
                members[name] = value.replace(b"Blue wand", b"Azure wand", 1)
                changed = True
                break
        assert changed, "Fixture did not contain the expected translation"
        temporary = xlsx.with_suffix(".saved")
        with ZipFile(temporary, "w") as saved:
            for name, value in members.items():
                saved.writestr(name, value)
        temporary.replace(xlsx)
        wait_for(lambda: "Azure wand" in target_csv.read_text(encoding="utf-8-sig"), "Saved workbook edit was not exported by editor plugin")
        with target_csv.open(encoding="utf-8-sig", newline="") as source:
            rows = list(csv.DictReader(source))
        assert rows[0]["English"] == "Azure wand", rows[0]
        errors = [line for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines()
                  if "ERROR:" in line and line != "ERROR: Failed to read the root certificate store."]
        assert not errors, errors
        report = {"passed": True, "entries": len(rows), "saved_workbook_exported_automatically": True}
        (OUT / "editor_report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report))
    finally:
        process.terminate()
        process.wait(timeout=10)
