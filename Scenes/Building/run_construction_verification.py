"""Run bounded construction checks using workspace-only settings and save profiles."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/construction'
GODOT = os.environ.get('GODOT_BIN', r'C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe')
mode = sys.argv[1] if len(sys.argv) > 1 else 'headless'
OUT.mkdir(parents=True, exist_ok=True)
startup = subprocess.STARTUPINFO() if os.name == 'nt' else None
if startup:
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0


def run(tag, extra):
    args = [GODOT, '--path', str(ROOT), '--script', 'res://Scenes/Building/verify_construction.gd']
    if mode == 'capture':
        args += ['--windowed', '--resolution', '1280x720', '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3']
    else:
        args += ['--headless']
    args += ['--', '--profile=res://output/construction/profile_%d' % os.getpid()] + extra
    log = OUT / (tag + '.log')
    with log.open('w', encoding='utf-8') as output:
        process = subprocess.Popen(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
        deadline = time.monotonic() + 120
        while process.poll() is None and time.monotonic() < deadline:
            try:
                process.wait(timeout=0.5)
            except subprocess.TimeoutExpired:
                if 'SCRIPT ERROR:' in log.read_text(encoding='utf-8', errors='replace'):
                    process.kill()
                    process.wait()
                    break
        if process.poll() is None:
            process.kill(); process.wait(); code = 124
        else:
            code = process.returncode
    text = log.read_text(encoding='utf-8', errors='replace')
    if 'ERROR:' in text or ': FAIL' in text or ' failures=0' not in text: code = 1
    for line in text.splitlines():
        if any(token in line for token in ['ERROR', 'FAIL', 'VERIFY END']): print(line.encode('ascii', errors='backslashreplace').decode('ascii'))
    print('GODOT_EXIT', code, 'PASS_COUNT', text.count(': PASS'), 'LOG', log)
    return code


if mode == 'restart':
    code = run('restart_write', ['--write'])
    if not code: code = run('restart_read', ['--read'])
else:
    code = run(mode, ['--capture'] if mode == 'capture' else [])
baseline = json.loads((OUT / 'myart_before.json').read_text(encoding='utf-8')) if (OUT / 'myart_before.json').exists() else None
current = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT / 'MyArt').rglob('*') if p.is_file()}
if baseline is not None and current != baseline: raise SystemExit('Protected MyArt hashes changed')
print('MYART_HASHES_UNCHANGED', len(current))
sys.exit(code)
