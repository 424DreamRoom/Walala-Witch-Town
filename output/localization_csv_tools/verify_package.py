"""Export an isolated fixture with the production CSV runtime and export preset."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
FIXTURE = OUT / "package_fixture"
FIXTURE.mkdir(exist_ok=True)
GODOT = ROOT / "output/audio_world/engine/godot.exe"
profile = OUT / "package_profile"
profile.mkdir(exist_ok=True)
environment = dict(os.environ)
for variable in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME"):
    environment[variable] = str(profile)
for relative in ("Localization/csv_catalog.gd", "Localization/localization.gd", "export_presets.cfg",
                 "Excel/Localization/Localization.csv", "Excel/Localization/Localization.csv.import"):
    target = FIXTURE / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / relative, target)
preferences = FIXTURE / "Scenes/MainMenu/menu_preferences.gd"
preferences.parent.mkdir(parents=True, exist_ok=True)
preferences.write_text('extends RefCounted\nstatic func value(_section, _key, fallback): return fallback\nstatic func set_value(_section, _key, _value): pass\n', encoding="utf-8")
(FIXTURE / "project.godot").write_text('config_version=5\n[application]\nconfig/name="CSV Package Verification"\n[autoload]\nLocalization="*res://Localization/localization.gd"\n[internationalization]\nlocale/fallback="zh_CN"\n', encoding="utf-8")
(FIXTURE / "verify_pack.gd").write_text('''extends SceneTree
func _initialize() -> void:
    run.call_deferred()
func run() -> void:
    var runtime = root.get_node("Localization")
    var failures := 0
    if runtime.catalog_rows.is_empty(): failures += 1
    if FileAccess.file_exists("res://Localization/catalog.gd"): failures += 1
    if FileAccess.file_exists("res://Excel/Localization/Localization.xlsx"): failures += 1
    for index in range(runtime.LOCALES.size()):
        runtime.set_language(runtime.LOCALES[index], false)
        for row in runtime.catalog_rows:
            if String(TranslationServer.translate(row[0])) != row[index + 1]: failures += 1
    print("CSV PACKAGE VERIFY END entries=", runtime.catalog_rows.size(), " failures=", failures)
    quit(failures)
''', encoding="utf-8")
pack = OUT / "localization_fixture.pck"
startup = None
if os.name == "nt":
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0


def run(name, arguments, cwd):
    with (OUT / (name + ".log")).open("w", encoding="utf-8") as log:
        result = subprocess.run([str(GODOT), "--headless", "--log-file", str(OUT / (name + ".engine.log")), *arguments],
                                cwd=cwd, env=environment, stdout=log, stderr=subprocess.STDOUT,
                                startupinfo=startup, timeout=60)
    text = (OUT / (name + ".log")).read_text(encoding="utf-8", errors="replace")
    errors = [line for line in text.splitlines() if "ERROR:" in line and line != "ERROR: Failed to read the root certificate store."]
    print(name, "exit", result.returncode, "errors", errors)
    if result.returncode or errors:
        raise RuntimeError(text)
    return text


run("package_export", ["--path", str(FIXTURE), "--export-pack", "Windows Desktop", str(pack)], FIXTURE)
empty = OUT / "empty_runtime"
empty.mkdir(exist_ok=True)
text = run("package_runtime", ["--main-pack", str(pack), "--script", "res://verify_pack.gd"], empty)
assert "failures=0" in text and "CSV PACKAGE VERIFY END" in text, text
report = {"passed": True, "pack_bytes": pack.stat().st_size, "runtime_requires_excel": False,
          "runtime_requires_python": False, "runtime_requires_catalog_gd": False}
(OUT / "package_report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(text)
