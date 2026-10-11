"""Move existing back-view hair cels without redrawing or resampling any pixels."""
from pathlib import Path
import hashlib
import json
import shutil
import struct
import subprocess
import sys
import zlib

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / "Art/Character/Storybook/WalalaWitchAseprite32"
OUT = Path(__file__).resolve().parent
SOURCE = ASSET / "walala-witch.aseprite"


def protected_hashes():
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (ROOT / "MyArt").rglob("*") if p.is_file()}


def main():
    assert ASSET.relative_to(ROOT).as_posix() == "Art/Character/Storybook/WalalaWitchAseprite32"
    backup = OUT / "before"
    if backup.exists():
        protected = json.loads((OUT / "myart-before.json").read_text(encoding="utf-8"))
        assert protected_hashes() == protected
    else:
        backup.mkdir()
        protected = protected_hashes()
        (OUT / "myart-before.json").write_text(json.dumps(protected, indent=2), encoding="utf-8")
        for item in ASSET.iterdir():
            if item.is_file():
                shutil.copy2(item, backup / item.name)
    before = (backup / SOURCE.name).read_bytes()
    after = bytearray(before)
    assert struct.unpack_from("<HHHH", before, 4) == (0xA5E0, 152, 32, 32)
    layers = []
    moved = []
    position = 128
    for frame in range(152):
        frame_end = position + struct.unpack_from("<I", before, position)[0]
        chunks = struct.unpack_from("<I", before, position + 12)[0] or struct.unpack_from("<H", before, position + 6)[0]
        position += 16
        for _ in range(chunks):
            size, kind = struct.unpack_from("<IH", before, position)
            data = position + 6
            if kind == 0x2004:
                length = struct.unpack_from("<H", before, data + 16)[0]
                layers.append(before[data + 18:data + 18 + length].decode())
            elif kind == 0x2005:
                layer, x, y = struct.unpack_from("<Hhh", before, data)
                if 38 <= frame < 76 and layers[layer] in ("hair_back", "hair_front"):
                    assert x == 0
                    assert struct.unpack_from("<H", before, data + 7)[0] == 2
                    width, height = struct.unpack_from("<HH", before, data + 16)
                    raw = zlib.decompress(before[data + 20:position + size])
                    image = Image.frombytes("RGBA", (width, height), raw)
                    bounds = image.getbbox()
                    assert bounds and x + bounds[2] + 1 <= 32 and y + bounds[3] <= 32
                    struct.pack_into("<h", after, data + 2, x + 1)
                    moved.append((frame, layers[layer], data + 2))
            position += size
        assert position == frame_end
    assert len(moved) == 76
    allowed = {offset for _, _, origin in moved for offset in (origin, origin + 1)}
    assert all(a == b or i in allowed for i, (a, b) in enumerate(zip(before, after)))
    try:
        assert SOURCE.read_bytes() in (before, bytes(after)), "Source changed since the saved backup"
        SOURCE.write_bytes(after)
        result = subprocess.run([sys.executable, str(ASSET / "tools/build.py")], cwd=ROOT,
                                capture_output=True, text=True, timeout=150)
        (OUT / "export.log").write_text(result.stdout + result.stderr, encoding="utf-8")
        assert result.returncode == 0, result.stdout + result.stderr
        assert SOURCE.read_bytes() == after, "Export must preserve the editable source"
        old_sheet = Image.open(backup / "walala-witch.png").convert("RGBA")
        new_sheet = Image.open(ASSET / "walala-witch.png").convert("RGBA")
        changed = []
        for frame in range(152):
            x, y = frame % 8 * 32, frame // 8 * 32
            box = (x, y, x + 32, y + 32)
            old, new = old_sheet.crop(box), new_sheet.crop(box)
            if old.tobytes() != new.tobytes():
                changed.append(frame)
        assert changed == list(range(38, 76)), changed
        old_data = json.loads((backup / "walala-witch.json").read_text(encoding="utf-8"))
        new_data = json.loads((ASSET / "walala-witch.json").read_text(encoding="utf-8"))
        assert old_data == new_data, "Frame sizes, tags, timings and layers must remain identical"
        comparison = Image.new("RGB", (576, 356), "#302b40")
        draw = ImageDraw.Draw(comparison)
        font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 16)
        draw.text((12, 8), "BACK VIEW / HAIR ALIGNED +1 PX", fill="#f5e3c5", font=font)
        for column, (label, frame) in enumerate(zip(("IDLE", "WALK", "RUN", "CAST"), (38, 42, 52, 62))):
            draw.text((column * 144 + 12, 34), label, fill="#a1e1d3", font=font)
            x, y = frame % 8 * 32, frame // 8 * 32
            for row, (sheet, title) in enumerate(((old_sheet, "BEFORE"), (new_sheet, "AFTER"))):
                tile = sheet.crop((x, y, x + 32, y + 32)).resize((128, 128), Image.Resampling.NEAREST)
                target = (column * 144 + 8, row * 152 + 70)
                comparison.paste(tile, target, tile)
                draw.text((column * 144 + 12, row * 152 + 52), title, fill="#f5e3c5", font=font)
        comparison.save(OUT / "before-after.png")
        report = {"status": "PASS", "direction": "up", "offset_pixels": [1, 0],
                  "changed_frames": changed, "translated_cels": len(moved),
                  "layers": ["hair_back", "hair_front"], "only_cel_positions_changed": True,
                  "source_pixel_bytes_unchanged": True, "other_directions_unchanged": True,
                  "hat_body_and_effect_layers_unchanged": True, "canvas_tags_and_timings_unchanged": True,
                  "myart_hashes_unchanged": protected_hashes() == protected,
                  "source_before_sha256": hashlib.sha256(before).hexdigest(),
                  "source_after_sha256": hashlib.sha256(after).hexdigest()}
        (OUT / "alignment-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(result.stdout)
        print("PASS: 76 hair cels moved +1 px across 38 back-view frames; all other source bytes preserved")
    finally:
        assert protected_hashes() == protected, "Protected MyArt hashes changed"


if __name__ == "__main__":
    main()
