"""Run existing isolated game verifiers without replacing their prior captures/logs."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
GODOT = os.environ.get('GODOT_BIN', r'C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe')
mode = sys.argv[1]
args = [GODOT, '--path', str(ROOT), '--log-file', str(OUT/(mode+'_engine.log'))]
marker = None
if mode == 'import':
    args += ['--headless', '--editor', '--import', '--quit']
else:
    area = 'Storage' if mode == 'storage' else 'Equipment'
    source = 'verify_grid.gd' if mode == 'storage' else 'verify_equipment.gd'
    original = ROOT/'Scenes'/area/source
    script = OUT/source
    text = original.read_text(encoding='utf-8')
    text = text.replace('res://Scenes/'+area+'/Verification/', 'res://output/resource_icons_v2/'+area+'/')
    # Retain the verifiers' isolation and cleanup; keep all transient data in this workspace.
    if area == 'Storage':
        text = text.replace('user://storage_%d', 'res://output/resource_icons_v2/storage_profile_%d')
    else:
        text = text.replace('user://equipment_%d', 'res://output/resource_icons_v2/equipment_profile_%d')
        text = text.replace('user://equipment_saves_%d', 'res://output/resource_icons_v2/equipment_saves_%d')
    script.write_text(text,encoding='utf-8')
    args += ['--script', 'res://'+script.relative_to(ROOT).as_posix()]
    if mode in ('storage', 'equipment_headless'):
        args += ['--headless']
    elif mode == 'equipment_native':
        args += ['--windowed','--resolution','1280x720','--','--capture']
    else:
        args += ['--windowed','--resolution','1280x720','--rendering-method','gl_compatibility','--rendering-driver','opengl3','--','--capture']
    marker = ('STORAGE' if area == 'Storage' else 'EQUIPMENT')+' VERIFY END failures=0'

startup = None
if os.name == 'nt':
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
log = OUT/(mode+'.log')
with log.open('w',encoding='utf-8') as output:
    child = subprocess.Popen(args,cwd=ROOT,stdout=output,stderr=subprocess.STDOUT,startupinfo=startup)
    try:
        code = child.wait(timeout=150)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 124
text = log.read_text(encoding='utf-8',errors='replace')
if 'ERROR:' in text or ': FAIL' in text or (marker and marker not in text):
    code = 1
for line in text.splitlines():
    if any(token in line for token in ['ERROR', 'FAIL', 'VERIFY END']):
        print(line.encode('ascii',errors='backslashreplace').decode('ascii'))
print('MODE',mode,'EXIT',code,'PASS_COUNT',text.count(': PASS'),'LOG',log)
sys.exit(code)
