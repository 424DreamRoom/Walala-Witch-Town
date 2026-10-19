"""Run only our own Godot subprocess, wait for GUI completion, retain logs."""
import pathlib
import os
import shutil
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[2]
godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or next(
    (str(p) for p in (
        pathlib.Path(r"C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"),
        pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"),
    ) if p.is_file()), None)
if not godot:
    raise SystemExit("Godot executable not found; set GODOT_BIN to its path.")
mode = sys.argv[1] if len(sys.argv) > 1 else "headless"
args = [godot, "--path", str(root)]
if "--fast" in sys.argv[2:] and mode not in ("town", "town_capture"):
    args += ["--fixed-fps", "60"]
if "--verbose" in sys.argv[2:]:
    args += ["--verbose"]
if mode in ("wand", "wand_capture"):
    args += ["--script", "res://Scenes/Equipment/verify_wand_modes.gd"]
    if mode == "wand":
        args += ["--headless"]
    else:
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--capture"]
elif mode in ("town", "town_capture"):
    args += ["--fixed-fps", "60"]
    args += ["--script", "res://Scenes/LanternLane/verify_town_plan.gd"]
    if mode == "town":
        args += ["--headless"]
    else:
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--town-capture"]
elif mode == "collision":
    args += ["--headless", "--script", "res://Scenes/Gameplay/verify_actor_collision.gd"]
elif mode in ("thoughts", "thoughts_capture"):
    args += ["--script", "res://Scenes/Gameplay/verify_thought_bubble.gd"]
    if mode == "thoughts":
        args += ["--headless"]
    else:
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--capture"]
elif mode in ("farm", "farm_capture"):
    args += ["--script", "res://Scenes/Farm/verify_farm.gd"]
    if mode == "farm":
        args += ["--headless"]
    else:
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--farm-capture"]
elif mode == "map":
    args += ["--headless", "--script", "res://Scenes/Map/verify_map.gd"]
elif mode in ("fade", "fade_capture"):
    args += ["--script", "res://Scenes/Gameplay/verify_scene_fade.gd"]
    if mode == "fade":
        args += ["--headless"]
    else:
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--fade-capture"]
elif mode in ("transitions", "roads_capture"):
    args += ["--script", "res://Scenes/Gameplay/verify_scene_transitions.gd"]
    if mode == "transitions":
        args += ["--headless"]
    else:
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--road-capture"]
elif mode in ("restaurant", "restaurant_capture"):
    args += ["--script", "res://Scenes/Gameplay/verify_restaurant_service.gd"]
    if mode == "restaurant":
        args += ["--headless"]
    else:
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--restaurant-capture"]
elif mode in ("daynight", "daynight_capture"):
    args += ["--script", "res://Scenes/Gameplay/verify_day_night.gd"]
    if mode == "daynight":
        args += ["--headless"]
    else:
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--daynight-capture"]
elif mode in ("dock", "dock_capture"):
    args += ["--script", "res://Scenes/Dock/verify_dock.gd"]
    if mode == "dock":
        args += ["--headless"]
    else:
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--dock-capture"]
elif mode in ("harvest", "harvest_capture"):
    args += ["--script", "res://Scenes/Gameplay/verify_harvest.gd"]
    if mode == "harvest":
        args += ["--headless"]
    else:
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--harvest-capture"]
elif mode == "customer_eat":
    args += ["--script", "res://Scenes/Gameplay/verify_loop.gd", "--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--customer-eat-test"]
elif mode == "lane":
    args += ["--headless", "--scene", "res://Scenes/LanternLane/lantern_lane.tscn", "--", "--lane-test"]
elif mode == "weather":
    args += ["--headless", "--script", "res://Scenes/LanternLane/Effect/Weather/verify_weather.gd", "--", "--no-loop"]
else:
    args += ["--script", "res://Scenes/Gameplay/verify_loop.gd"]
    if mode == "headless":
        args += ["--headless"]
    else:
        args += ["--windowed", "--resolution", "1280x720", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--", "--loop-render"]
log_tag = next((arg.split("=", 1)[1] for arg in sys.argv[2:] if arg.startswith("--log-tag=")), "")
if mode == "harvest_capture" and "--wand-capture" in sys.argv[2:]:
    args += ["--wand-capture"]
if log_tag and not log_tag.replace("-", "").replace("_", "").isalnum():
    raise SystemExit("Log tag must contain only letters, digits, hyphens or underscores.")
log = root / "output" / ("loop_" + mode + ("_" + log_tag if log_tag else "") + ".log")
args[1:1] = ["--log-file", str(log.with_suffix(".engine.log"))]
# Set isolated paths before the verifier instantiates gameplay or reads settings.
if "--script" in args:
    index = args.index("--script") + 1
    profile = root / "output" / "verification_profiles" / (mode + "_" + str(os.getpid()))
    profile.mkdir(parents=True, exist_ok=True)
    script = profile / "isolated.gd"
    resource = "res://" + profile.relative_to(root).as_posix()
    script.write_text(
        'extends "' + args[index] + '"\n'
        'const TestPreferences = preload("res://Scenes/MainMenu/menu_preferences.gd")\n'
        'const TestSaves = preload("res://Scenes/Save/save_store.gd")\n'
        'func _initialize() -> void:\n'
        '\tTestPreferences.file_path = "' + resource + '/preferences.cfg"\n'
        '\tTestSaves.directory = "' + resource + '/saves"\n'
        '\tTestSaves.end_session()\n'
        '\tsuper._initialize()\n', encoding="utf-8")
    args[index] = resource + "/isolated.gd"
with log.open("w", encoding="utf-8") as out:
    startup = subprocess.STARTUPINFO() if os.name == "nt" else None
    if startup:
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
    child = subprocess.Popen(args, cwd=root, stdout=out, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        code = child.wait(timeout=150)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 124
print(log.read_text(encoding="utf-8"))
print("GODOT_EXIT", code)
text = log.read_text(encoding="utf-8")
end_marker = "THOUGHT VERIFY END failures=0" if mode in ("thoughts", "thoughts_capture") else "FARM VERIFY END failures=0" if mode in ("farm", "farm_capture") else "SCENE EXIT VERIFY END failures=0" if mode == "transitions" else "DAY NIGHT VERIFY END failures=0" if mode in ("daynight", "daynight_capture") else "DOCK VERIFY END failures=0" if mode in ("dock", "dock_capture") else "HARVEST VERIFY END failures=0" if mode in ("harvest", "harvest_capture") else "CUSTOMER EAT VERIFY END failures=0" if mode == "customer_eat" else "LOOP VERIFY END failures=0"
if mode in ("wand", "wand_capture"):
    end_marker = "WAND MODES VERIFY END failures=0"
elif mode in ("fade", "fade_capture"):
    end_marker = "SCENE FADE VERIFY END failures=0"
elif mode in ("town", "town_capture"):
    end_marker = "TOWN PLAN VERIFY END failures=0"
elif mode in ("restaurant", "restaurant_capture"):
    end_marker = "RESTAURANT VERIFY END checks="
elif mode == "roads_capture":
    end_marker = "SCENE EXIT VERIFY END failures=0"
elif mode == "map":
    end_marker = "MAP VERIFY END failures=0"
elif mode == "collision":
    end_marker = "ACTOR COLLISION VERIFY END checks="
if code == 0 and ("FAIL" in text or "ERROR:" in text or (mode not in ("lane", "weather") and end_marker not in text)):
    code = 1
sys.exit(code)
