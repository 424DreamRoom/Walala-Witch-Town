import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[2]
log = root / 'output/actor_collision/integration.log'
with log.open('w', encoding='utf-8') as out:
    p = subprocess.Popen([r'C:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe', '--headless', '--path', str(root), '--script', 'res://output/actor_collision/isolated_integration.gd'], stdout=out, stderr=subprocess.STDOUT)
    try:
        p.wait(timeout=60)
    except subprocess.TimeoutExpired:
        p.kill()
        p.wait()
text = log.read_text(encoding='utf-8')
print(text)
print('EXIT', p.returncode)
raise SystemExit(p.returncode or int('ERROR:' in text or 'FAIL' in text or 'failures=0' not in text))
