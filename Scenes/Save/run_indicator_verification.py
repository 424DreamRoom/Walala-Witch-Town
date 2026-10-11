"""Run isolated saving feedback checks and optional native pixel captures."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('mode', choices=['headless', 'capture'], nargs='?', default='headless')
parser.add_argument('--godot', default=os.environ.get('GODOT_BIN'))
options = parser.parse_args()
candidates = [options.godot, shutil.which('godot'), r'C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe']
godot = next((str(p) for p in candidates if p and Path(p).is_file()), None)
if not godot:
    sys.exit('Godot not found; use --godot PATH.')
args = [godot, '--path', str(ROOT), '--script', 'res://Scenes/Save/verify_saving_indicator.gd']
if options.mode == 'capture':
    args += ['--windowed', '--resolution', '1280x720', '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--', '--indicator-capture']
else:
    args += ['--headless']
out = ROOT / 'output/saving_indicator'
out.mkdir(parents=True, exist_ok=True)
(out / '.gdignore').touch()
startup = None
if os.name == 'nt':
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
log = out / (options.mode + '.log')
with log.open('w', encoding='utf-8') as f:
    child = subprocess.Popen(args, cwd=ROOT, stdout=f, stderr=subprocess.STDOUT, startupinfo=startup)
    try:
        code = child.wait(timeout=65)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 124
text = log.read_text(encoding='utf-8', errors='replace')
print(text)
sys.exit(code or int('SAVING INDICATOR VERIFY END failures=0' not in text or 'ERROR:' in text))
