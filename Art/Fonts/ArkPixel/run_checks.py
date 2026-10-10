"""Bounded Godot verification; only our subprocess, never desktop capture."""
from pathlib import Path
import subprocess, sys
ROOT = Path(__file__).resolve().parents[3]
GODOT = r'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
OUT = ROOT / 'Art/Fonts/ArkPixel/Verification'
OUT.mkdir(exist_ok=True)
mode = sys.argv[1] if len(sys.argv) > 1 else 'font'
args = [GODOT, '--path', str(ROOT)]
if mode == 'import':
    args += ['--headless', '--editor', '--quit']
else:
    scripts = {'font': 'Art/Fonts/ArkPixel/verify_font.gd', 'capture': 'Art/Fonts/ArkPixel/verify_font.gd', 'audio': 'Sounds/Walala/verify_audio.gd', 'regression': 'Sounds/Walala/verify_regression.gd'}
    args += ['--script', 'res://' + scripts[mode]]
    if mode in ('font', 'regression'):
        args += ['--headless']
    else:
        args += ['--windowed', '--resolution', '1280x720', '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3']
        if mode == 'capture':
            args += ['--', '--font-capture']
log = OUT / (mode + '.log')
with log.open('w', encoding='utf-8') as f:
    p = subprocess.Popen(args, cwd=ROOT, stdout=f, stderr=subprocess.STDOUT)
    try:
        code = p.wait(timeout=180)
    except subprocess.TimeoutExpired:
        p.kill(); p.wait(); code = 124
text = log.read_text(encoding='utf-8', errors='replace')
print(text.encode('ascii', errors='backslashreplace').decode('ascii'))
print('GODOT_EXIT', code, 'PASS_COUNT', text.count(': PASS'))
if 'ERROR:' in text or (mode != 'import' and (': FAIL' in text or 'VERIFY END failures=0' not in text)): code = 1
sys.exit(code)
