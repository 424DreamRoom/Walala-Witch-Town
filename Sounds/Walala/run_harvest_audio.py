"""Import only gathering audio, then verify with isolated preferences and saves."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
BASE = Path(__file__).resolve().parent
OUT = ROOT / "output/harvest_audio"
GODOT = os.environ.get("GODOT_BIN") or shutil.which("godot") or str(Path(
    r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"))


def myart_hashes():
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (ROOT / "MyArt").rglob("*") if p.is_file()}


def run(args, name, marker=None, timeout=60):
    log = OUT / (name + "_%d.log" % os.getpid())
    with log.open("w", encoding="utf-8") as output:
        child = subprocess.Popen([GODOT] + args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
        try:
            code = child.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
            code = 124
    text = log.read_text(encoding="utf-8")
    print(text)
    print("LOG", log)
    if code or "ERROR:" in text or "FAIL" in text or (marker and marker not in text):
        raise RuntimeError("Godot verification failed: " + name)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    before = myart_hashes()
    manifest = json.loads((BASE / "Harvest/manifest.json").read_text(encoding="utf-8"))
    for asset in manifest["assets"]:
        data = (BASE / "Harvest" / asset["file"]).read_bytes()
        assert hashlib.sha256(data).hexdigest() == asset["sha256"]
        archive = ROOT / asset["source_archive"]
        assert hashlib.sha256(archive.read_bytes()).hexdigest() == asset["source_archive_sha256"]
        with zipfile.ZipFile(archive) as pack:
            assert data == pack.read(asset["archive_member"])
    print("HARVEST HASHES", len(manifest["assets"]), "original-byte clips verified")
    mode = sys.argv[1] if len(sys.argv) > 1 else "headless"
    if mode == "import":
        # The real project importer could generate .import files in protected MyArt.
        # Use a tiny fixture containing only these 13 sounds at identical res:// paths.
        fixture = OUT / ("import_%d" % os.getpid())
        destination = fixture / "Sounds/Walala/Harvest"
        destination.mkdir(parents=True, exist_ok=True)
        (fixture / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Harvest Audio Import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
        for asset in manifest["assets"]:
            shutil.copy2(BASE / "Harvest" / asset["file"], destination / asset["file"])
        run(["--headless", "--path", str(fixture), "--editor", "--quit"], "import")
        for asset in manifest["assets"]:
            sidecar = destination / (asset["file"] + ".import")
            shutil.copy2(sidecar, BASE / "Harvest" / sidecar.name)
            for resource in set(re.findall(r'res://(\.godot/imported/[^"\]]+)', sidecar.read_text(encoding="utf-8"))):
                target = ROOT / resource
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(fixture / resource, target)
    else:
        scripts = {
            "headless": ("Sounds/Walala/verify_harvest_audio.gd", "HARVEST AUDIO END failures=0"),
            "audio": ("Sounds/Walala/verify_harvest_audio.gd", "HARVEST AUDIO END failures=0"),
            "backend": ("Sounds/Walala/verify_harvest_audio.gd", "HARVEST AUDIO END failures=0"),
            "harvest": ("Scenes/Gameplay/verify_harvest.gd", "HARVEST VERIFY END failures=0"),
            "farm": ("Scenes/Farm/verify_farm.gd", "FARM VERIFY END failures=0"),
            "settings": ("Sounds/Walala/verify_audio_settings.gd", "AUDIO SETTINGS VERIFY END failures=0"),
        }
        if mode not in scripts:
            raise ValueError("Use import, headless, audio, backend, harvest, farm or settings")
        script, marker = scripts[mode]
        if mode in ("harvest", "farm"):
            wrapper = OUT / ("isolated_%s.gd" % mode)
            wrapper.write_text('extends "res://' + script + '"\nfunc _initialize() -> void:\n'
                '\tpreload("res://Scenes/MainMenu/menu_preferences.gd").file_path = "res://output/harvest_audio/regression_%s_%%d.cfg" %% OS.get_process_id()\n' % mode
                + '\tpreload("res://Scenes/Save/save_store.gd").directory = "res://output/harvest_audio/regression_%s_%%d_saves" %% OS.get_process_id()\n' % mode
                + '\tsuper._initialize()\n', encoding="utf-8")
            script = wrapper.relative_to(ROOT).as_posix()
        args = ["--path", str(ROOT), "--script", "res://" + script]
        args += ["--display-driver", "headless", "--audio-driver", "WASAPI"] if mode == "audio" else ["--headless"]
        if mode == "backend": args += ["--", "--audio-only"]
        run(args, mode, marker, timeout=90 if mode in ("harvest", "farm") else 60)
    assert myart_hashes() == before, "Protected MyArt changed"
    baseline = OUT / "myart_before.json"
    if baseline.exists():
        assert before == json.loads(baseline.read_text(encoding="utf-8")), "MyArt differs from task baseline"
    print("MYART HASHES unchanged", len(before))


if __name__ == "__main__":
    main()
