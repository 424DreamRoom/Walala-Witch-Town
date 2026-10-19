"""Import only non-MyArt runtime dependencies in a small disposable project."""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/wand_modes"
FIXTURE = OUT / "runtime_import"
GODOT = Path(r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe")

def myart_hashes():
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (ROOT / "MyArt").rglob("*") if p.is_file()}

before = myart_hashes()
(OUT / "myart_before.json").write_text(json.dumps(before, indent=2), encoding="utf-8")
FIXTURE.mkdir(parents=True, exist_ok=True)
(FIXTURE / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Wand Dependency Import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
sources = [p for folder in [ROOT / "Sounds", ROOT / "Art/Fonts"] for p in folder.rglob("*")
           if p.suffix.lower() in [".ogg", ".wav", ".mp3", ".ttf", ".otf", ".woff", ".woff2"]]
for source in sources:
    target = FIXTURE / source.relative_to(ROOT)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    sidecar = source.with_name(source.name + ".import")
    if sidecar.exists(): shutil.copy2(sidecar, target.with_name(sidecar.name))
extension = ROOT / "addons/fmod/fmod.gdextension"
native = [extension] + list((extension.parent / "libs/windows").glob("*.dll"))
for source in native:
    target = FIXTURE / source.relative_to(ROOT)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
log = OUT / "runtime_import.log"
with log.open("w", encoding="utf-8") as out:
    child = subprocess.Popen([str(GODOT), "--headless", "--path", str(FIXTURE), "--editor", "--import", "--quit", "--log-file", str(OUT / "runtime_import.engine.log")], stdout=out, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        code = child.wait(timeout=60)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        raise
assert code == 0, code
missing = []
for source in sources:
    sidecar = source.with_name(source.name + ".import")
    text = sidecar.read_text(encoding="utf-8")
    for resource in set(re.findall(r'res://(\.godot/imported/[^"\]]+)', text)):
        target = ROOT / resource
        imported = FIXTURE / resource
        if not imported.exists(): missing.append(resource); continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(imported, target)
assert not missing, missing
cache = ROOT / ".godot/extension_list.cfg"
existing = cache.read_text(encoding="utf-8") if cache.exists() else ""
resource = "res://addons/fmod/fmod.gdextension"
if resource not in existing: cache.write_text(existing + resource + "\n", encoding="utf-8")
assert myart_hashes() == before, "MyArt changed"
print("RUNTIME DEPENDENCIES", len(sources), "MYART UNCHANGED", len(before))
