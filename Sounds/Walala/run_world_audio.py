"""Import selected files without scanning MyArt, then run isolated audio checks."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "Sounds/Walala"
OUT = ROOT / "output/audio_world"
GODOT = os.environ.get("GODOT_BIN") or shutil.which("godot") or str(Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"))


def myart_hashes():
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (ROOT / "MyArt").rglob("*") if p.is_file()}


def run(args, name, marker=None, timeout=120):
    log = OUT / (name + "_%d.log" % os.getpid())
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    environment = os.environ.copy()
    for key in ["APPDATA", "LOCALAPPDATA"]:
        folder = OUT / ("runtime_%d" % os.getpid()) / key.lower()
        folder.mkdir(parents=True, exist_ok=True)
        environment[key] = str(folder)
    executable = GODOT
    if "--editor" in args:
        # Steam's portable editor otherwise saves into its installation folder.
        executable = str(OUT / "engine" / "godot.exe")
        Path(executable).parent.mkdir(exist_ok=True)
        if not Path(executable).exists(): shutil.copy2(GODOT, executable)
    with log.open("w", encoding="utf-8") as output:
        child = subprocess.Popen([executable, "--log-file", str(OUT / (name + "_%d.engine.log" % os.getpid()))] + args, cwd=ROOT, stdout=output,
                                 stderr=subprocess.STDOUT, startupinfo=startup, env=environment)
        try:
            code = child.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
            code = 124
    text = log.read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        if any(word in line for word in ["ERROR", "FAIL", "VERIFY END"]):
            print(line)
    print("EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log, flush=True)
    # This sandbox denies Windows' certificate store. No Godot test performs
    # network I/O; retain the diagnostic in the log and reject every other error.
    errors = [line for line in text.splitlines() if "ERROR:" in line
              and line.strip() != "ERROR: Failed to read the root certificate store."]
    if code or errors or ": FAIL" in text or (marker and marker not in text):
        raise RuntimeError("World audio verification failed: " + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["import", "world", "gameplay", "settings", "backpack", "music"])
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / ".gdignore").touch()
    before = myart_hashes()
    baseline = OUT / "myart_before.json"
    if not baseline.exists():
        baseline.write_text(json.dumps(before, indent=2), encoding="utf-8")
    manifest = json.loads((BASE / "World/manifest.json").read_text(encoding="utf-8"))
    try:
        for asset in manifest["assets"]:
            data = (BASE / "World" / asset["file"]).read_bytes()
            assert hashlib.sha256(data).hexdigest() == asset["sha256"]
            original = ROOT / asset["original_file"]
            if asset["archive_member"]:
                with zipfile.ZipFile(original) as pack:
                    source = pack.read(asset["archive_member"])
            else:
                source = original.read_bytes()
            assert hashlib.sha256(source).hexdigest() == asset["source_sha256"]
            if asset["changes"].startswith("Original"):
                assert source == data
            assert (BASE / "World" / asset["license_evidence"]).is_file()
            assert asset["license"] == "CC0-1.0"
        print("WORLD SOURCE HASHES", len(manifest["assets"]), "verified", flush=True)
        if args.mode == "import":
            fixture = OUT / ("import_%d" % os.getpid())
            fixture.mkdir()
            (fixture / "project.godot").write_text('config_version=5\n[application]\nconfig/name="World Audio Import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
            for asset in manifest["assets"]:
                relative = Path("Sounds/Walala/World") / asset["file"]
                target = fixture / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / relative, target)
            run(["--headless", "--path", str(fixture), "--editor", "--import", "--quit"], "import")
            for asset in manifest["assets"]:
                relative = Path("Sounds/Walala/World") / (asset["file"] + ".import")
                sidecar = fixture / relative
                shutil.copy2(sidecar, ROOT / relative)
                for resource in set(re.findall(r'res://(\.godot/imported/[^"\]]+)', sidecar.read_text(encoding="utf-8"))):
                    target = ROOT / resource
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(fixture / resource, target)
        else:
            scripts = {
                "world": ("Sounds/Walala/verify_world_audio.gd", "WORLD AUDIO VERIFY END failures=0"),
                "gameplay": ("Sounds/Walala/verify_world_gameplay.gd", "WORLD GAMEPLAY VERIFY END failures=0"),
                "settings": ("Sounds/Walala/verify_audio_settings.gd", "AUDIO SETTINGS VERIFY END failures=0"),
                "backpack": ("Sounds/Walala/verify_backpack_audio.gd", "PAUSE AUDIO VERIFY END failures=0"),
                "music": ("Sounds/Walala/verify_music_refresh.gd", "MUSIC REFRESH VERIFY END failures=0"),
            }
            script, marker = scripts[args.mode]
            run(["--path", str(ROOT), "--display-driver", "headless", "--audio-driver", "WASAPI",
                 "--script", "res://" + script], args.mode, marker)
    finally:
        assert myart_hashes() == before == json.loads(baseline.read_text(encoding="utf-8")), "Protected MyArt changed"
        print("MYART HASHES unchanged", len(before), flush=True)


if __name__ == "__main__":
    main()
