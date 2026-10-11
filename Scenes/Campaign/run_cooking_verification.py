"""Import and check cooking expansion with hidden Godot processes and isolated progress."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/cooking_expansion'
GODOT = os.environ.get('GODOT_BIN', r'C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe')
mode = sys.argv[1] if len(sys.argv) > 1 else 'headless'
assert mode in ('import', 'headless', 'capture', 'campaign', 'restaurant')
OUT.mkdir(parents=True, exist_ok=True)
args = [GODOT, '--path', str(ROOT)]
if mode == 'import':
    args += ['--headless', '--editor', '--import', '--quit']
else:
    script = 'res://Scenes/Campaign/verify_campaign.gd' if mode == 'campaign' else 'res://Scenes/Gameplay/verify_restaurant_service.gd' if mode == 'restaurant' else 'res://Scenes/Campaign/verify_cooking_expansion.gd'
    args += ['--script', script]
    if mode == 'capture':
        args += ['--windowed', '--resolution', '1280x720', '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--', '--capture']
    else:
        args += ['--headless']
startup = subprocess.STARTUPINFO() if os.name == 'nt' else None
if startup:
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
log_path = OUT / (mode + '.log')
with log_path.open('w', encoding='utf-8') as log:
    child = subprocess.Popen(args, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        code = child.wait(timeout=110)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 124
text = log_path.read_text(encoding='utf-8', errors='replace')
for line in text.splitlines():
    if any(word in line for word in ('ERROR', 'FAIL', 'COMPLETE', 'WARNING')):
        print(line)
marker = 'CAMPAIGN COMPLETE' if mode == 'campaign' else 'RESTAURANT VERIFY END' if mode == 'restaurant' else 'COOKING COMPLETE'
if 'ERROR' in text or 'FAIL' in text or (mode != 'import' and marker not in text):
    code = code or 1
print('GODOT_EXIT', code, 'PASS_COUNT', text.count(': PASS'), 'LOG', log_path)
sys.exit(code)
