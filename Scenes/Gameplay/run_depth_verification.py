"""Isolated occlusion audit; --capture also verifies real GPU compositing pixels."""
from pathlib import Path
import os
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
godot = os.environ.get('GODOT_BIN', r'C:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe')
capture = '--capture' in sys.argv
harvest = '--harvest' in sys.argv
args = [godot, '--path', str(root), '--script', 'res://Scenes/Gameplay/verify_depth_harvest.gd' if harvest else 'res://Scenes/Gameplay/verify_depth.gd']
args += ['--windowed', '--resolution', '1280x720', '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--', '--capture'] if capture else ['--headless']
dest = root/'Scenes/Gameplay/Verification/Depth'
dest.mkdir(parents=True, exist_ok=True)
log_path = dest/('harvest.log' if harvest else 'capture.log' if capture else 'headless.log')
startup = subprocess.STARTUPINFO() if os.name == 'nt' else None
if startup:
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
with log_path.open('w', encoding='utf-8') as output:
    child = subprocess.Popen(args, cwd=root, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        child.wait(timeout=180)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
log = log_path.read_text(encoding='utf-8', errors='replace')
print('\n'.join(line for line in log.splitlines() if any(word in line for word in ('FAIL', 'ERROR:', 'WARNING:', 'COMPLETE', 'VERIFY END'))))
marker = 'HARVEST VERIFY END failures=0' if harvest else 'DEPTH COMPLETE'
if child.returncode or 'FAIL' in log or 'ERROR:' in log or marker not in log:
    raise SystemExit(1)
