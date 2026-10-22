"""Build short speech blips from the licensed pack; writes only this directory.

Usage: python prepare_dialogue_audio.py "path/to/Super Dialogue Audio Pack v1.zip"
Requires numpy. Does not read, generate, clean or modify MyArt.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct
import wave
from zipfile import ZipFile

import numpy as np

BASE = Path(__file__).resolve().parent
ACTORS = {'alex': 'Alex Brodie', 'ian': 'Ian Lampert', 'sean': 'Sean Lenhart',
          'karen': 'Karen Cenon', 'meghan': 'Meghan Christian'}
TAKES = ['greeting_5', 'miscellaneous_2', 'miscellaneous_3']  # Hm?, Hmm..., Huh?


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read_float_wav(data):
    assert data[:4] == b'RIFF' and data[8:12] == b'WAVE'
    chunks = {}
    offset = 12
    while offset + 8 <= len(data):
        tag, size = struct.unpack_from('<4sI', data, offset)
        chunks[tag] = data[offset + 8:offset + 8 + size]
        offset += 8 + size + (size & 1)
    encoding, channels, rate = struct.unpack_from('<HHI', chunks[b'fmt '])
    assert encoding == 3 and channels == 1, 'Expected original mono IEEE float WAV'
    pcm = np.frombuffer(chunks[b'data'], dtype='<f4').astype(np.float64)
    assert np.isfinite(pcm).all()
    return rate, pcm


def build_clip(data):
    rate, pcm = read_float_wav(data)
    # Find voiced energy with a 10 ms RMS window; omit breaths and leading silence.
    window = max(1, rate // 100)
    energy = np.convolve(pcm * pcm, np.ones(window) / window, mode='same')
    start = int(np.flatnonzero(energy >= energy.max() * 0.18)[0])
    start = max(0, start - int(rate * 0.008))
    clip = pcm[start:start + int(rate * 0.125)].copy()
    clip -= clip.mean()
    # All outputs use PCM16 / mono / 44.1 kHz. Source rate is retained in manifest.
    clip = np.interp(np.arange(5512) * rate / 44100.0, np.arange(len(clip)), clip)
    clip[:353] *= np.linspace(0, 1, 353)
    clip[-1103:] *= np.linspace(1, 0, 1103)
    gain = min(0.14 / max(float(np.sqrt(np.mean(clip * clip))), 1e-9),
               0.70 / max(float(np.abs(clip).max()), 1e-9))
    clip *= gain
    payload = np.rint(clip * 32767).astype('<i2').tobytes()
    output = io.BytesIO()
    with wave.open(output, 'wb') as writer:
        writer.setparams((1, 2, 44100, 0, 'NONE', 'not compressed'))
        writer.writeframes(payload)
    return output.getvalue(), {'source_rate': rate, 'start_frame': start,
                               'source_frames': int(rate * 0.125), 'gain': gain}


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_bytes() != data:
        raise FileExistsError('Refusing to replace a different asset: ' + str(path))
    path.write_bytes(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    args = parser.parse_args()
    manifest = {'title': 'Super Dialogue Audio Pack v1', 'author': 'Dillon Becker',
                'source': 'https://dillonbecker.itch.io/sdap', 'itch_upload_id': 2138920,
                'license': 'CC-BY-4.0', 'license_url': 'https://creativecommons.org/licenses/by/4.0/',
                'verified': '2026-10-22', 'archive_sha256': sha(args.archive.read_bytes()),
                'changes': '125 ms voiced excerpts; DC removal; 44.1 kHz mono PCM16; '
                           '8 ms fade in / 25 ms fade out; RMS target 0.14, peak <=0.70. '
                           'Runtime pitch and volume variation.', 'assets': []}
    with ZipFile(args.archive) as pack:
        for actor, name in ACTORS.items():
            for index, take in enumerate(TAKES, 1):
                member = next(n for n in pack.namelist() if not n.startswith('__MACOSX')
                              and n.endswith('/' + take + '_' + actor + '.wav'))
                source = pack.read(member)
                filename = f'{actor}_{index:02}.wav'
                original = 'Originals/' + take + '_' + actor + '.wav'
                save(BASE / original, source)
                clip, conversion = build_clip(source)
                save(BASE / 'Blips' / filename, clip)
                manifest['assets'].append({'file': 'Blips/' + filename, 'actor': name,
                                          'archive_member': member, 'original': original,
                                          'source_sha256': sha(source), 'sha256': sha(clip),
                                          'bytes': len(clip), **conversion})
        for name in ['License.pdf', 'Reference Sheet.pdf']:
            member = next(n for n in pack.namelist() if not n.startswith('__MACOSX')
                          and n.endswith('/' + name))
            save(BASE / 'Licenses' / name, pack.read(member))
    save(BASE / 'Originals/.gdignore', b'')
    (BASE / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('DIALOGUE ASSETS', len(manifest['assets']), 'verified and converted')


if __name__ == '__main__':
    main()
