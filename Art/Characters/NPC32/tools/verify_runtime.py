"""Import only NPC32 runtime PNGs, then use isolated real-engine checks."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ART = Path(__file__).resolve().parents[1]
ROOT = ART.parents[2]
OUT = ROOT / "output/npc32"
GODOT = "C:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
STARTUP = subprocess.STARTUPINFO()
STARTUP.dwFlags |= subprocess.STARTF_USESHOWWINDOW
STARTUP.wShowWindow = 0


def originals():
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (ROOT / "MyArt").rglob("*") if p.is_file()}


def engine(args, name, timeout=65):
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA"):
        profile = OUT / "profiles" / name / key
        profile.mkdir(parents=True, exist_ok=True)
        env[key] = str(profile)
    log = OUT / (name + ".log")
    with log.open("w", encoding="utf-8") as stream:
        try:
            result = subprocess.run([GODOT, *map(str, args)], cwd=ROOT, env=env, startupinfo=STARTUP,
                                    stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
            exit_code = result.returncode
        except subprocess.TimeoutExpired:
            exit_code = -1
    text = log.read_text(encoding="utf-8", errors="replace")
    failures = [line for line in text.splitlines() if any(t in line for t in ("ERROR:", "SCRIPT ERROR", ": FAIL"))]
    passed = exit_code == 0 and not failures
    print(name, "PASS" if passed else "FAIL", "checks", text.count(": PASS"), "exit", exit_code, flush=True)
    for line in failures:
        print(line, flush=True)
    return dict(name=name, passed=passed, checks=text.count(": PASS"), exit=exit_code, failures=failures, log=log.relative_to(ROOT).as_posix())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["import", "test", "capture", "baseline", "art"], default="art", nargs="?")
    mode = parser.parse_args().mode
    OUT.mkdir(parents=True, exist_ok=True)
    before = originals()
    if mode == "import":
        project = OUT / "texture_import"
        project.mkdir(exist_ok=True)
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="NPC32 texture import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/default_filters/use_nearest_mipmap_filter=false\n', encoding="utf-8")
        assets = []
        for folder in ("residents", "customers", "guides", "portraits"):
            for png in (ART / folder).glob("*.png"):
                rel = png.relative_to(ROOT)
                target = project / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(png, target)
                assets.append(rel)
        report = engine(["--path", project, "--headless", "--editor", "--import", "--quit"], "import")
        assert report["passed"], report
        for rel in assets:
            shutil.copy2(Path(str(project / rel) + ".import"), Path(str(ROOT / rel) + ".import"))
        (ROOT / ".godot/imported").mkdir(parents=True, exist_ok=True)
        for cache in (project / ".godot/imported").iterdir():
            if cache.is_file():
                shutil.copy2(cache, ROOT / ".godot/imported" / cache.name)
        report["runtime_textures"] = len(assets)
    elif mode == "art":
        report = [engine(["--path", ROOT, "--script", "res://Art/Characters/NPC32/tools/verify_npc32.gd", "--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"], "art")]
    else:
        scripts = {
            "residents": "Scenes/Campaign/verify_residents.gd",
            "guide": "Scenes/Campaign/verify_guide.gd",
            "businesses": "Scenes/Businesses/verify_businesses.gd",
            "restaurant": "Scenes/Gameplay/verify_restaurant_service.gd",
            "depth": "Scenes/Gameplay/verify_depth.gd",
        }
        def check(item):
            name, script = item
            if mode == "baseline":
                # Change loaded resources only in this test process; files stay untouched.
                source = (ROOT / script).read_text(encoding="utf-8")
                injection = '\n\tvar old_actor: GDScript = load("res://Scenes/Campaign/resident_actor.gd")\n\told_actor.source_code = old_actor.source_code.replace("Art/Characters/NPC32/residents/", "Art/Campaign/npcs/").replace("Vector2.ZERO, 32)", "Vector2.ZERO, 48)")\n\tassert(old_actor.reload() == OK)\n'
                source = source.replace("func _initialize() -> void:", "func _initialize() -> void:" + injection)
                source = source.replace("Vector2(0,-16)", "Vector2(0,-24)") if name == "residents" else source
                generated = OUT / ("baseline_" + name + ".gd")
                generated.write_text(source, encoding="utf-8")
                script = generated.relative_to(ROOT).as_posix()
            args = ["--path", ROOT, "--script", "res://" + script]
            if mode == "capture":
                args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--capture"]
            else:
                args += ["--headless"]
            result = engine(args, mode + "_" + name)
            log = (ROOT / result["log"]).read_text(encoding="utf-8", errors="replace")
            result["completed"] = any(marker in log for marker in ("COMPLETE", "VERIFY END"))
            if not result["completed"]:
                result["passed"] = False
            return result
        if mode == "baseline":
            report = [check(("residents", scripts["residents"])), check(("businesses", scripts["businesses"]))]
        elif mode == "capture":
            report = [check(("residents", scripts["residents"])), check(("guide", scripts["guide"]))]
        else:
            with ThreadPoolExecutor(max_workers=3) as pool:
                report = list(pool.map(check, scripts.items()))
    assert before == originals(), "MyArt changed during engine verification"
    (ART / ("runtime-" + mode + ".json")).write_text(json.dumps(dict(results=report, myart_unchanged=True, isolated_profiles=True), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if isinstance(report, list):
        assert all(result["passed"] for result in report)


if __name__ == "__main__":
    main()
