"""Check real FMOD playback; optionally export and run an isolated release fixture."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("mode", nargs="?", choices=["native", "export"], default="native")
options = parser.parse_args()
godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or next(
    (str(p) for p in [
        Path(r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"),
        Path(r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"),
    ] if p.is_file()), None)
if not godot:
    sys.exit("Set GODOT_BIN to the Godot executable")
OUT = ROOT / "output/fmod"
OUT.mkdir(parents=True, exist_ok=True)
(OUT / ".gdignore").touch()

def run(args, log, cwd, marker=None, timeout=55):
    startup = None
    if os.name == "nt":
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
    with log.open("w", encoding="utf-8") as output:
        child = subprocess.Popen(args, cwd=cwd, stdout=output,
                                 stderr=subprocess.STDOUT, startupinfo=startup)
        try:
            code = child.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
            code = 124
    text = log.read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        if any(token in line for token in ["ERROR", "FAIL", "VERIFY END"]):
            print(line.encode("ascii", errors="backslashreplace").decode("ascii"))
    print("GODOT_EXIT", code, "PASS_COUNT", text.count(": PASS"), "LOG", log)
    if code or "ERROR:" in text or ": FAIL" in text or (marker and marker not in text):
        sys.exit(code or 1)

if options.mode == "native":
    run([godot, "--headless", "--path", str(ROOT), "--script",
         "res://Sounds/Walala/verify_fmod.gd"], OUT / "native.log", ROOT,
        "FMOD VERIFY END failures=0", timeout=90)
else:
    if os.name != "nt":
        sys.exit("The release fixture currently targets Windows x86_64")
    fixture = OUT / ("fixture_%d" % os.getpid())
    build = OUT / ("release_%d" % os.getpid())
    fixture.mkdir()
    build.mkdir()
    shutil.copytree(ROOT / "addons/fmod", fixture / "addons/fmod",
                    ignore=shutil.ignore_patterns("linux", "macos", "android", "ios", "*.lib", "*.exp"))
    shutil.copytree(ROOT / "addons/walala_fmod", fixture / "addons/walala_fmod")
    for name in ["fmod_voice.gd", "fmod_runtime.gd", "music_library.gd", "verify_fmod_export.gd"]:
        target = fixture / "Sounds/Walala" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "Sounds/Walala" / name, target)
    for name in ["Music/title.ogg", "Music/day.ogg", "Music/night.ogg", "UI/Organic/hover.wav"]:
        target = fixture / "Sounds/Walala" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "Sounds/Walala" / name, target)
    for name in ["home", "dock", "forest"]:
        target = fixture / "Sounds/Walala/World/Music" / (name + ".ogg")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "Sounds/Walala/World/Music" / (name + ".ogg"), target)
    (fixture / "project.godot").write_text('''config_version=5
[application]
config/name="Walala FMOD release verification"
run/main_scene="res://verify.tscn"
[Fmod]
General/is_live_update_enabled=false
[autoload]
WalalaFmod="*res://Sounds/Walala/fmod_runtime.gd"
[editor_plugins]
enabled=PackedStringArray("res://addons/walala_fmod/plugin.cfg")
[rendering]
renderer/rendering_method="gl_compatibility"
''', encoding="utf-8")
    (fixture / "verify.tscn").write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://Sounds/Walala/verify_fmod_export.gd" id="1"]
[node name="Verify" type="Node"]
script = ExtResource("1")
''', encoding="utf-8")
    (fixture / "export_presets.cfg").write_text('''[preset.0]
name="FMOD Windows verification"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path=""
[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=false
''', encoding="utf-8")
    run([godot, "--headless", "--path", str(fixture), "--editor", "--import", "--quit"],
        OUT / "export_import.log", fixture)
    executable = build / "fmod_verify.exe"
    run([godot, "--headless", "--path", str(fixture), "--export-release",
         "FMOD Windows verification", str(executable)], OUT / "export_build.log", fixture)
    # Running in a separate folder prevents raw sources or editor DLLs from
    # masking missing PCK audio or missing FMOD release dependencies.
    run([str(executable), "--headless"], OUT / "export_runtime.log", build,
        "FMOD EXPORT VERIFY END failures=0")
