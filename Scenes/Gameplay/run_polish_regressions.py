"""Run existing suites in process-specific copies, preserving their prior outputs."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/project_polish/regressions'
OUT.mkdir(parents=True,exist_ok=True)
engine=os.environ.get('GODOT_BIN',r'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe')
suites={
    'story':'Scenes/Campaign/verify_rebuilt_story.gd',
    'service':'Scenes/Gameplay/verify_restaurant_service.gd',
    'farm':'Scenes/Farm/verify_farm.gd',
    'save':'Scenes/Save/verify_saves.gd',
    'map':'Scenes/Map/verify_map.gd',
    'hotbar':'Scenes/UI/verify_hotbar.gd',
    'equipment':'Scenes/Equipment/verify_equipment.gd',
    'ambient':'Scenes/Gameplay/verify_ambient.gd',
    'residents':'Scenes/Campaign/verify_residents.gd',
    'seasonal':'Scenes/Gameplay/verify_seasonal_director.gd',
    'cooking':'Scenes/Campaign/verify_cooking_expansion.gd',
    'ui':'Scenes/UI/verify_ui.gd',
}
selected=sys.argv[1:] or list(suites)
environment=os.environ.copy()
for key in ['APPDATA','LOCALAPPDATA']:
    folder=OUT/('runtime_'+str(os.getpid()))/key.lower()
    folder.mkdir(parents=True,exist_ok=True)
    environment[key]=str(folder)
startup=subprocess.STARTUPINFO()
startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow=0
reports=[]
for name in selected:
    folder=OUT/name
    folder.mkdir(parents=True,exist_ok=True)
    source=(ROOT/suites[name]).read_text(encoding='utf-8')
    # Redirect test output and user:// fixtures; references to production resources
    # remain unchanged. The original suites and their recorded results stay intact.
    source=re.sub(r'res://output/[^"\n]*',lambda m:'res://output/project_polish/regressions/'+name+'/'+m.group(0)[len('res://output/'):].replace('/','_'),source)
    source=source.replace('user://','res://output/project_polish/regressions/'+name+'/user_')
    source=source.replace('res://Scenes/Map/Verification/','res://output/project_polish/regressions/map/')
    source=source.replace('res://Scenes/Save/Verification/','res://output/project_polish/regressions/save/')
    source=source.replace('res://Scenes/UI/Verification/','res://output/project_polish/regressions/ui/')
    fixture=folder/'verify.gd'
    fixture.write_text(source,encoding='utf-8')
    args=[engine,'--path',str(ROOT),'--headless','--resolution','1280x720','--log-file',str(folder/'engine.log'),'--script','res://'+str(fixture.relative_to(ROOT)).replace('\\','/')]
    with (folder/'stdout.log').open('w',encoding='utf-8') as output:
        process=subprocess.Popen(args,cwd=ROOT,stdout=output,stderr=subprocess.STDOUT,env=environment,startupinfo=startup)
        try: code=process.wait(timeout=70)
        except subprocess.TimeoutExpired:
            process.kill();process.wait();code=124
    log=(folder/'engine.log').read_text(encoding='utf-8',errors='replace')
    errors=[line for line in log.splitlines() if 'SCRIPT ERROR' in line or ': FAIL' in line or (line.startswith('ERROR:') and 'root certificate store' not in line)]
    reports.append(dict(suite=name,exit_code=code,passed=code==0 and not errors,checks=log.count(': PASS'),errors=errors))
    (folder/'report.json').write_text(json.dumps(reports[-1],ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(name.upper(),json.dumps({**reports[-1],'errors':errors[:8]},ensure_ascii=True),flush=True)
combined=[json.loads(p.read_text(encoding='utf-8')) for p in sorted(OUT.glob('*/report.json'))]
(OUT/'report.json').write_text(json.dumps(combined,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
sys.exit(0 if all(row['passed'] for row in reports) else 1)
