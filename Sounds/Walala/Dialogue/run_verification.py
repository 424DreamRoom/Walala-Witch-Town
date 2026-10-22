"""Import selected WAVs in isolation, verify provenance, then exercise real HUD/FMOD.

Uses a separate settings/save profile and never imports or writes MyArt.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import wave
from array import array

ROOT = Path(__file__).resolve().parents[3]
BASE = Path(__file__).resolve().parent
OUT = ROOT / 'output/dialogue_audio_20261022'
GODOT = os.environ.get('GODOT_BIN', r'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe')


def hashes(folder):
    return {p.relative_to(folder).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in folder.rglob('*') if p.is_file()}


def run(executable, args, label, marker=None):
    env = os.environ.copy()
    for variable in ['APPDATA', 'LOCALAPPDATA']:
        target = OUT / 'profile' / variable.lower()
        target.mkdir(parents=True, exist_ok=True)
        env[variable] = str(target)
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    log = OUT / (label + '.log')
    with log.open('w', encoding='utf-8') as output:
        result = subprocess.run([str(executable), '--log-file', str(OUT / (label + '.engine.log')), *args],
                                cwd=ROOT, env=env, startupinfo=startup, stdout=output,
                                stderr=subprocess.STDOUT, timeout=100)
    text = log.read_text(encoding='utf-8', errors='replace')
    errors = [line for line in text.splitlines() if 'ERROR:' in line
              and line.strip() != 'ERROR: Failed to read the root certificate store.']
    print(label, 'exit', result.returncode, 'passes', text.count(': PASS'), 'log', log, flush=True)
    if result.returncode or errors or ': FAIL' in text or (marker and marker not in text):
        print(text)
        raise RuntimeError('Dialogue verification failed: ' + label)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / '.gdignore').touch()
    before = hashes(ROOT / 'MyArt')
    try:
        manifest = json.loads((BASE / 'manifest.json').read_text(encoding='utf-8'))
        assert manifest['license'] == 'CC-BY-4.0'
        for asset in manifest['assets']:
            assert hashlib.sha256((BASE / asset['file']).read_bytes()).hexdigest() == asset['sha256']
            assert hashlib.sha256((BASE / asset['original']).read_bytes()).hexdigest() == asset['source_sha256']
            with wave.open(str(BASE / asset['file'])) as reader:
                assert reader.getnchannels() == 1 and reader.getsampwidth() == 2
                assert reader.getframerate() == 44100 and reader.getnframes() == 5512
                samples = array('h', reader.readframes(reader.getnframes()))
                assert samples[0] == samples[-1] == 0
                assert 1000 < max(abs(v) for v in samples) <= 22937
        license_path = 'Sounds/Walala/Dialogue/LICENSE.txt'
        assert license_path in (ROOT / 'export_presets.cfg').read_text(encoding='utf-8')
        assert 'CC BY 4.0' in (ROOT / license_path).read_text(encoding='utf-8')
        print('DIALOGUE SOURCE HASHES', len(manifest['assets']), 'verified', flush=True)
        fixture = OUT / 'import_fixture'
        fixture.mkdir(exist_ok=True)
        (fixture / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Dialogue Import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
        for asset in manifest['assets']:
            relative = Path('Sounds/Walala/Dialogue') / asset['file']
            target = fixture / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        editor = OUT / 'engine/godot.exe'
        editor.parent.mkdir(exist_ok=True)
        if not editor.exists(): shutil.copy2(GODOT, editor)
        run(editor, ['--headless', '--path', str(fixture), '--editor', '--import', '--quit'], 'import')
        for asset in manifest['assets']:
            relative = Path('Sounds/Walala/Dialogue') / (asset['file'] + '.import')
            sidecar = fixture / relative
            shutil.copy2(sidecar, ROOT / relative)
            for resource in set(re.findall(r'res://(\.godot/imported/[^"\]]+)', sidecar.read_text(encoding='utf-8'))):
                target = ROOT / resource
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(fixture / resource, target)
        run(GODOT, ['--path', str(ROOT), '--display-driver', 'headless', '--audio-driver', 'WASAPI',
                    '--script', 'res://Sounds/Walala/Dialogue/verify_dialogue_audio.gd'],
            'dialogue', 'DIALOGUE VERIFY END failures=0')
    finally:
        assert hashes(ROOT / 'MyArt') == before, 'Protected MyArt changed'
        print('MYART HASHES unchanged', len(before), flush=True)


if __name__ == '__main__':
    main()
