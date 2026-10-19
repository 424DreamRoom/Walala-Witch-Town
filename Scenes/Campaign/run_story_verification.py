"""Story/onboarding regressions with isolated saves, settings and engine logs."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/story_onboarding'
parser = argparse.ArgumentParser()
parser.add_argument('mode', choices=['headless', 'capture'], nargs='?', default='headless')
parser.add_argument('--suite', choices=['all', 'story', 'guide', 'quest', 'opening'], default='all')
options = parser.parse_args()
OUT.mkdir(parents=True, exist_ok=True)

def originals():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (ROOT / 'MyArt').rglob('*') if p.is_file()}

before = originals()
godot = os.environ.get('GODOT_BIN') or shutil.which('godot') or next(
    (str(p) for p in [Path(r'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'),
                      Path(r'C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe')]
     if p.is_file()), None)
if not godot:
    raise SystemExit('Godot executable not found; set GODOT_BIN.')
suites = {'story': 'verify_story.gd', 'guide': 'verify_guide.gd', 'quest': 'verify_quest_pacing.gd', 'opening': 'verify_opening.gd'}
environment = os.environ.copy()
for variable in ['APPDATA', 'LOCALAPPDATA']:
    folder = OUT / ('runtime_' + str(os.getpid())) / variable.lower()
    folder.mkdir(parents=True, exist_ok=True)
    environment[variable] = str(folder)
startup = subprocess.STARTUPINFO() if os.name == 'nt' else None
if startup:
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
passed = True
for suite, script in suites.items():
    if options.suite not in ['all', suite]:
        continue
    name = suite + '.' + options.mode
    args = [godot, '--path', str(ROOT), '--log-file', str(OUT / (name + '.engine.log')),
            '--script', 'res://Scenes/Campaign/' + script]
    args += ['--windowed', '--resolution', '1280x720', '--rendering-method', 'gl_compatibility',
             '--rendering-driver', 'opengl3', '--', '--capture'] if options.mode == 'capture' else ['--headless']
    log_path = OUT / (name + '.log')
    with log_path.open('w', encoding='utf-8') as log:
        process = subprocess.Popen(args, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, startupinfo=startup, env=environment)
        try:
            process.wait(timeout=55)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
    result = log_path.read_text(encoding='utf-8', errors='replace')
    ok = process.returncode == 0 and 'COMPLETE checks=' in result and 'failures=0' in result and not any(
        marker in result for marker in ['ERROR:', 'SCRIPT ERROR', ': FAIL'])
    passed = passed and ok
    print('\n'.join(line for line in result.splitlines() if any(marker in line for marker in ['ERROR', 'FAIL', 'COMPLETE'])))
    print(suite.upper(), options.mode, 'PASS_COUNT', result.count(': PASS'), 'EXIT', process.returncode, flush=True)
    # A script parse failure prevents the engine from quitting; don't repeat it.
    if process.returncode != 0:
        break
assert originals() == before, 'Protected originals changed'
print('MYART_UNCHANGED', len(before))
raise SystemExit(0 if passed else 1)
