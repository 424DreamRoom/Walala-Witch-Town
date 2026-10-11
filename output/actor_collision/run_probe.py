import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[2]
log = root / 'output/actor_collision/probe.log'
with log.open('w', encoding='utf-8') as out:
    p = subprocess.Popen([r'C:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe', '--headless', '--path', str(root), '--script', 'res://output/actor_collision/probe_routines.gd'], stdout=out, stderr=subprocess.STDOUT)
    try:
        p.wait(timeout=70)
    except subprocess.TimeoutExpired:
        p.kill()
        p.wait()
print(log.read_text(encoding='utf-8'))
print('EXIT', p.returncode)
raise SystemExit(p.returncode)
