"""Run only our own Godot subprocess, wait for GUI completion, retain logs."""
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[2]
godot = r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
mode = sys.argv[1] if len(sys.argv) > 1 else "headless"
args = [godot, "--path", str(root)]
if mode in ("harvest", "harvest_capture"):
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
log = root / "output" / ("loop_" + mode + ".log")
with log.open("w", encoding="utf-8") as out:
    child = subprocess.Popen(args, cwd=root, stdout=out, stderr=subprocess.STDOUT)
    try:
        code = child.wait(timeout=150)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 124
print(log.read_text(encoding="utf-8"))
print("GODOT_EXIT", code)
text = log.read_text(encoding="utf-8")
end_marker = "HARVEST VERIFY END failures=0" if mode in ("harvest", "harvest_capture") else "CUSTOMER EAT VERIFY END failures=0" if mode == "customer_eat" else "LOOP VERIFY END failures=0"
if code == 0 and ("FAIL" in text or "ERROR:" in text or (mode not in ("lane", "weather") and end_marker not in text)):
    code = 1
sys.exit(code)
