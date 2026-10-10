import subprocess, pathlib, sys
root=pathlib.Path(__file__).resolve().parents[2]
mode=sys.argv[1] if len(sys.argv)>1 else 'audio'
godot=r'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
args=[godot,'--path',str(root)]
if mode=='lane': args+=['--headless','--scene','res://Scenes/LanternLane/lantern_lane.tscn','--','--lane-test']
elif mode=='weather': args+=['--headless','--script','res://Scenes/LanternLane/Effect/Weather/verify_weather.gd','--','--no-loop']
else:
    args+=['--script','res://Sounds/Walala/'+('verify_regression.gd' if mode in ('regression','gui') else 'verify_audio.gd')]
    if mode=='regression': args+=['--headless']
    else: args+=['--windowed','--resolution','1280x720','--rendering-method','gl_compatibility','--rendering-driver','opengl3','--','--loop-render']
log=root/'Sounds/Walala/Verification'/(mode+'.log'); log.parent.mkdir(exist_ok=True)
with log.open('w',encoding='utf-8') as f:
    p=subprocess.Popen(args,cwd=root,stdout=f,stderr=subprocess.STDOUT)
    try: code=p.wait(timeout=150)
    except subprocess.TimeoutExpired: p.kill(); p.wait(); code=124
text=log.read_text(encoding='utf-8'); print(text); print('EXIT',code)
if 'FAIL' in text or 'SCRIPT ERROR' in text or (mode not in ('lane',) and 'END failures=0' not in text): code=1
sys.exit(code)
