"""Prepare the two CC0 archives. No decoder or network access is needed at runtime.

Usage: python Sounds/Walala/prepare_footsteps.py --sndfile PATH_TO_LIBSNDFILE_DLL
Requires 7-Zip for the snow archive; ctypes uses libsndfile only for conversion.
Existing selected files must match their expected bytes and are never overwritten.
"""
import argparse
import array
import ctypes
import hashlib
import io
import json
from pathlib import Path
import subprocess
import wave
import zipfile

ROOT = Path(__file__).resolve().parent
LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"


class SoundInfo(ctypes.Structure):
    _fields_ = [("frames", ctypes.c_int64), ("samplerate", ctypes.c_int),
                ("channels", ctypes.c_int), ("format", ctypes.c_int),
                ("sections", ctypes.c_int), ("seekable", ctypes.c_int)]


def decode_flac(decoder, filename):
    info = SoundInfo()
    handle = decoder.sf_open(str(filename).encode("utf-8"), 0x10, ctypes.byref(info))
    if not handle:
        raise ValueError("Cannot decode " + str(filename))
    try:
        if not 0 < info.frames <= 480000 or not 0 < info.channels <= 2:
            raise ValueError("Unexpected source dimensions")
        samples = (ctypes.c_short * (info.frames * info.channels))()
        count = decoder.sf_readf_short(handle, samples, info.frames)
        if count != info.frames:
            raise ValueError("Incomplete FLAC decode")
        mono = [round(sum(samples[i:i + info.channels]) / info.channels)
                for i in range(0, len(samples), info.channels)]
        peak = max(abs(v) for v in mono)
        if peak == 0:
            raise ValueError("Silent snow source")
        # Remove lead-in and bound the crunch tail to suit walking/running steps.
        start = next(i for i, v in enumerate(mono) if abs(v) >= peak * 0.025)
        mono = mono[start:start + round(info.samplerate * 0.38)]
        scale = 0.55 * 32767 / max(abs(v) for v in mono)
        fade_in = max(1, round(info.samplerate * 0.003))
        fade_out = max(1, round(info.samplerate * 0.015))
        pcm = array.array("h", [round(v * scale * min(1, i / fade_in, (len(mono) - 1 - i) / fade_out))
                                for i, v in enumerate(mono)])
        output = io.BytesIO()
        with wave.open(output, "wb") as writer:
            writer.setparams((1, 2, info.samplerate, len(pcm), "NONE", "not compressed"))
            writer.writeframes(pcm.tobytes())
        return output.getvalue()
    finally:
        decoder.sf_close(handle)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sndfile", type=Path, required=True)
    parser.add_argument("--sevenzip", default=r"C:\Program Files\7-Zip\7z.exe")
    args = parser.parse_args()
    decoder = ctypes.CDLL(str(args.sndfile.resolve()))
    decoder.sf_open.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.POINTER(SoundInfo)]
    decoder.sf_open.restype = ctypes.c_void_p
    decoder.sf_readf_short.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_short), ctypes.c_int64]
    decoder.sf_readf_short.restype = ctypes.c_int64
    decoder.sf_close.argtypes = [ctypes.c_void_p]
    output = ROOT / "Footsteps"
    output.mkdir(exist_ok=True)
    entries = []

    def save(name, data, original, member, source, download, author, changes):
        target = output / name
        if target.exists():
            if target.read_bytes() != data:
                raise FileExistsError(target)
        else:
            target.write_bytes(data)
        entries.append(dict(file="Footsteps/" + name, title=member, author=author,
                            source=source, download=download, archive_member=member,
                            license="CC0 1.0 Universal", license_url=LICENSE, changes=changes,
                            source_sha256=hashlib.sha256(original).hexdigest(),
                            sha256=hashlib.sha256(data).hexdigest(), bytes=len(data)))

    with zipfile.ZipFile(ROOT / "Archives/footsteps.zip") as archive:
        for name, member in [("wood_01.ogg", "wood01.ogg"), ("wood_02.ogg", "wood02.ogg"),
                             ("wood_03.ogg", "wood03.ogg"), ("stone_01.ogg", "stone01.ogg"),
                             ("grass_01.ogg", "leaves01.ogg"), ("grass_02.ogg", "leaves02.ogg"),
                             ("dirt_01.ogg", "mud02.ogg")]:
            data = archive.read(member)
            save(name, data, data, member,
                 "https://opengameart.org/content/different-steps-on-wood-stone-leaves-gravel-and-mud",
                 "https://opengameart.org/sites/default/files/%5Bkdd%5DDifferentSteps_0.zip",
                 "TinyWorlds", "Original bytes; renamed, leaves used for grass, mud used for dirt")

    # Extract named files only. Archive paths never determine output paths.
    snow_archive = ROOT / "Archives/snow_steps.7z"
    work = ROOT.parents[1] / "output/audio-tools"
    work.mkdir(parents=True, exist_ok=True)
    for i in range(1, 7):
        member = "Corsica_S-Walking_in_Snow/Corsica_S-Walking_on_snow_covered_gravel_%02d.flac" % i
        original = subprocess.check_output([args.sevenzip, "e", "-so", str(snow_archive), member])
        flac = work / ("snow_%02d.flac" % i)
        flac.write_bytes(original)
        data = decode_flac(decoder, flac)
        save("snow_%02d.wav" % i, data, original, member,
             "https://opengameart.org/content/42-snow-and-gravel-footsteps",
             "https://opengameart.org/sites/default/files/corsica_s-walking_in_snow.7z",
             "Corsica_S; extracted and released CC0 by Iwan Gabovitch (qubodup)",
             "FLAC decoded to mono PCM16 WAV; lead-in trimmed, max 0.38s, peak 0.55, 3ms/15ms edge fades")
        flac.unlink()
    readme = subprocess.check_output([args.sevenzip, "e", "-so", str(snow_archive),
                                     "Corsica_S-Walking_in_Snow/readme.txt"])
    (ROOT / "Licenses/snow_steps_readme.txt").write_bytes(readme)
    manifest_path = ROOT / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    selected = {entry["file"] for entry in entries}
    manifest["assets"] = [e for e in manifest["assets"] if e["file"] not in selected] + entries
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Prepared", len(entries), "CC0 footsteps;", sum(e["bytes"] for e in entries), "bytes")


if __name__ == "__main__":
    main()
