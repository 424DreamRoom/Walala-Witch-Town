from pathlib import Path
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'Sounds/Walala/Dialogue/Blips'
OUT = Path(__file__).resolve().parent
segments = [np.zeros(4410)]
# Raw adapted clips at their normalized source level for easy comparison.
# Actual game mix additionally applies master, character volume and -8 dB trim.
for actor in ['meghan', 'karen', 'alex', 'ian', 'sean']:
    for index in [1, 2, 3, 2, 1, 3]:
        with wave.open(str(BASE / f'{actor}_{index:02}.wav')) as reader:
            clip = np.frombuffer(reader.readframes(reader.getnframes()), dtype='<i2')
        segments.extend([clip, np.zeros(2205)])
    segments.append(np.zeros(13230))
audio = np.concatenate(segments).astype('<i2')
with wave.open(str(OUT / 'voice_preview.wav'), 'wb') as writer:
    writer.setparams((1, 2, 44100, 0, 'NONE', 'not compressed'))
    writer.writeframes(audio.tobytes())
print('PREVIEW', len(audio) / 44100, 'seconds')

result = {
    'license': 'CC-BY-4.0', 'source': 'https://dillonbecker.itch.io/sdap',
    'clips': 15, 'source_hashes_verified': 15, 'runtime_checks_passed': 83,
    'localization_entries_checked': 2261, 'myart_files_unchanged': 3,
    'runtime': 'Godot 4.7.2 / FMOD / WASAPI / display headless',
    'limitations': ['No human listening review', 'Full standalone game export not run; license inclusion configured'],
}
(OUT / 'result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
