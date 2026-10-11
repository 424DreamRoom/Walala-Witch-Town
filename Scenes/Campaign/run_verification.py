"""Bounded real-engine verification; only isolated res://output test progress is used."""
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
GODOT=os.environ.get('GODOT_BIN',r'C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe')
capture='--capture' in sys.argv
args=[GODOT,'--path',str(ROOT),'--script','res://Scenes/Campaign/verify_campaign.gd']
args+=['--windowed','--resolution','1280x720','--rendering-method','gl_compatibility','--rendering-driver','opengl3','--','--capture'] if capture else ['--headless']
dest=ROOT/'Scenes/Campaign/Verification';dest.mkdir(exist_ok=True)
log_path=dest/('capture.log' if capture else 'headless.log')
with log_path.open('w',encoding='utf-8') as output:
    result=subprocess.Popen(args,stdout=output,stderr=subprocess.STDOUT)
    try: result.wait(timeout=75)
    except subprocess.TimeoutExpired:
        result.kill();result.wait()
log=log_path.read_text(encoding='utf-8',errors='replace')
interesting=[line for line in log.splitlines() if any(word in line for word in ('FAIL','SCRIPT ERROR','ERROR:','WARNING:','COMPLETE'))]
print('\n'.join(interesting) if interesting else log[-2000:])
if result.returncode or 'FAIL' in log or 'SCRIPT ERROR' in log or 'ERROR:' in log or 'CAMPAIGN COMPLETE' not in log:
    raise SystemExit(1)
