import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[2]
overlay = (root / 'output/actor_collision/isolated_integration.gd').read_text(encoding='utf-8')
failed = False
for label, resource in [('residents', 'Scenes/Campaign/verify_residents.gd'), ('depth', 'Scenes/Gameplay/verify_depth.gd')]:
    wrapper = root / ('output/actor_collision/' + label + '_isolated.gd')
    wrapper.write_text(overlay.replace('Scenes/Gameplay/verify_actor_collision.gd', resource), encoding='utf-8')
    log = root / ('output/actor_collision/' + label + '.log')
    with log.open('w', encoding='utf-8') as out:
        p = subprocess.Popen([r'C:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe', '--headless', '--path', str(root), '--script', 'res://' + wrapper.relative_to(root).as_posix()], stdout=out, stderr=subprocess.STDOUT)
        try:
            p.wait(timeout=75)
        except subprocess.TimeoutExpired:
            p.kill()
            p.wait()
    text = log.read_text(encoding='utf-8')
    print(label, 'EXIT', p.returncode)
    print('\n'.join(line for line in text.splitlines() if any(key in line for key in ['FAIL', 'ERROR:', 'WARNING:', 'COMPLETE', 'VERIFY END'])))
    failed = failed or bool(p.returncode or 'ERROR:' in text or 'FAIL' in text)
raise SystemExit(int(failed))
