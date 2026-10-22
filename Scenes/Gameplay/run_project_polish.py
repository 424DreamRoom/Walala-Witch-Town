"""Run isolated Godot integration and optional rendered multilingual QA."""
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/project_polish'
OUT.mkdir(parents=True,exist_ok=True)
engine=os.environ.get('GODOT_BIN',r'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe')
capture='capture' in sys.argv
mode='capture' if capture else 'headless'
args=[engine,'--path',str(ROOT),'--log-file',str(OUT/(mode+'.engine.log')),'--script','res://Scenes/Gameplay/verify_project_polish.gd']
args+=['--windowed','--resolution','1280x720','--rendering-method','gl_compatibility','--rendering-driver','opengl3','--','--capture'] if capture else ['--headless']
startup=subprocess.STARTUPINFO()
startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow=0
environment=os.environ.copy()
for key in ['APPDATA','LOCALAPPDATA']:
    folder=OUT/('runtime_'+str(os.getpid()))/key.lower()
    folder.mkdir(parents=True,exist_ok=True)
    environment[key]=str(folder)
with (OUT/(mode+'.log')).open('w',encoding='utf-8') as output:
    process=subprocess.Popen(args,cwd=ROOT,stdout=output,stderr=subprocess.STDOUT,startupinfo=startup,env=environment)
    try: code=process.wait(timeout=180)
    except subprocess.TimeoutExpired:
        process.kill();process.wait();code=124
log=(OUT/(mode+'.engine.log')).read_text(encoding='utf-8',errors='replace')
for line in log.splitlines():
    if any(marker in line for marker in ['FAIL','SCRIPT ERROR','Parse Error','COMPLETE']): print(line)
print('PROJECT_POLISH_EXIT',code)
sys.exit(1 if code or 'failures=0' not in log or 'SCRIPT ERROR' in log else 0)
