"""Export the new 32x32 witch, pixel rig animation, and existing wand actions.

All writes stay in WalalaWitch32 and WalalaTools32. MyArt is read-only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import zlib

from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
import build_characters as legacy
import build_tools as wand

ART = Path(__file__).resolve().parents[1]
PROJECT = ART.parents[2]
HERO = ART / "WalalaWitch32"
TOOLS = ART / "WalalaTools32"
CELL = (32, 32)
DIRECTIONS = ("down", "up", "right", "left")
LAYERS = legacy.LAYERS


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def hashes():
    return {p.relative_to(PROJECT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (PROJECT / "MyArt").rglob("*") if p.is_file()}


def prepare_keys():
    source = Image.open(HERO / "generated-character.png").convert("RGBA")
    sheet = Image.new("RGBA", (64, 64))
    for i in range(4):
        x, y = i % 2, i // 2
        part = source.crop((x * source.width // 2, y * source.height // 2,
                            (x + 1) * source.width // 2, (y + 1) * source.height // 2))
        alpha = part.getchannel("A").point(lambda a: 255 if a >= 160 else 0)
        part.putalpha(alpha)
        part = part.crop(alpha.getbbox()).resize((25, 30), Image.Resampling.NEAREST)
        sheet.alpha_composite(part, (x * 32 + 4, y * 32 + 2))
    alpha = sheet.getchannel("A")
    sheet = sheet.quantize(colors=32, method=Image.Quantize.FASTOCTREE,
                           dither=Image.Dither.NONE).convert("RGBA")
    sheet.putalpha(alpha)
    sheet.save(HERO / "character-keys.png")


def shifted(image, dx=0, dy=0):
    result = Image.new("RGBA", CELL)
    result.alpha_composite(image, (dx, dy))
    return result


def region(image, box):
    result = Image.new("RGBA", CELL)
    result.paste(image.crop(box), box[:2])
    return result


class Frame:
    def __init__(self):
        self.layers = {name: Image.new("RGBA", CELL) for name in LAYERS}

    def composite(self):
        result = Image.new("RGBA", CELL)
        for name in LAYERS:
            result.alpha_composite(self.layers[name])
        return result


def idle(key):
    frame = Frame()
    frame.layers["hair"] = region(key, (0, 0, 32, 22))
    frame.layers["outfit"] = region(key, (0, 22, 32, 28))
    frame.layers["body"] = region(key, (0, 28, 32, 32))
    assert frame.composite().tobytes() == key.tobytes()
    return frame


def walk(key, phase):
    frame = idle(key)
    bob = -1 if phase in (1, 3) else 0
    frame.layers["hair"] = shifted(frame.layers["hair"], dy=bob)
    frame.layers["outfit"] = shifted(frame.layers["outfit"], dy=bob)
    feet = frame.layers["body"]
    bounds = feet.getbbox()
    center = (bounds[0] + bounds[2]) // 2
    left = region(feet, (0, 28, center, 32))
    right = region(feet, (center, 28, 32, 32))
    # One-pixel joint overlap prevents a gap when the torso bobs upward.
    for foot in (left, right):
        foot.paste(foot.crop((0, 28, 32, 29)), (0, 27))
    offsets = [((-1, 0), (1, -1)), ((0, 0), (0, -1)),
               ((1, -1), (-1, 0)), ((0, -1), (0, 0))][phase]
    frame.layers["body"] = shifted(left, *offsets[0])
    frame.layers["body"].alpha_composite(shifted(right, *offsets[1]))
    return frame


def changed_pixels(before, after):
    result = Image.new("RGBA", before.size)
    for y in range(before.height):
        for x in range(before.width):
            pixel = after.getpixel((x, y))
            if pixel[3] and pixel != before.getpixel((x, y)):
                result.putpixel((x, y), pixel)
    return result


def tool_pose(key, action, direction, step, palette):
    frame = idle(key)
    outfit = frame.layers["outfit"]
    # Retract the idle hand at the active shoulder. Side-view torso pixels
    # come from the neighbouring cloth column of the same generated key.
    if direction in ("down", "up"):
        outfit.paste((0, 0, 0, 0), (22, 23, 25, 27))
    else:
        box = (18, 24, 20, 27) if direction == "right" else (14, 24, 17, 27)
        for y in range(box[1], box[3]):
            for x in range(box[0], box[2]):
                if outfit.getpixel((x, y))[3]:
                    outfit.putpixel((x, y), key.getpixel((17, y)))
    before = legacy.author(legacy.HERO, direction, tool_pose=True)
    after = wand.pose(action, direction, step)
    old_cloth = legacy.ramp(legacy.HERO["outfit"])
    nearest = lambda value: min(palette, key=lambda c: sum((c[i] - value[i]) ** 2 for i in range(3)))
    recolor = {
        legacy.rgba(legacy.INK): nearest((48, 23, 62)),
        legacy.rgba(old_cloth[2]): nearest((116, 76, 137)),
        legacy.rgba(old_cloth[3]): nearest((168, 130, 184)),
        legacy.rgba(legacy.HERO["skin"]): nearest((249, 215, 181)),
        legacy.rgba("#c39496"): nearest((177, 120, 100)),
    }
    for name in ("outfit", "equipment", "fx"):
        overlay = changed_pixels(before.layers[name], after.layers[name])
        if name != "fx":
            for y in range(48):
                for x in range(32):
                    color = overlay.getpixel((x, y))
                    if color in recolor:
                        overlay.putpixel((x, y), recolor[color])
        # The existing shoulder at y32 becomes y23; all wand poses fit 32x32.
        overlay = overlay.resize((32, 30), Image.Resampling.NEAREST)
        frame.layers[name].alpha_composite(overlay, (0, 3))
    return frame


def aseprite(frames, data):
    durations = [0] * len(frames)
    for tag in data["animations"]:
        for i in range(tag["from"], tag["to"] + 1): durations[i] = tag["duration_ms"]
    output = []
    for index, frame in enumerate(frames):
        chunks = []
        if index == 0:
            for name in LAYERS:
                encoded = name.encode()
                chunks.append(legacy.chunk(0x2004, struct.pack("<HHHHHHB", 1, 0, 0, 0, 0, 0, 255) +
                                            bytes(3) + struct.pack("<H", len(encoded)) + encoded))
            payload = struct.pack("<H", len(data["animations"])) + bytes(8)
            for tag in data["animations"]:
                name = tag["name"].encode()
                payload += struct.pack("<HHBH", tag["from"], tag["to"], 0, 0) + bytes(6) + bytes((160, 128, 183, 0)) + struct.pack("<H", len(name)) + name
            chunks.append(legacy.chunk(0x2018, payload))
        for layer, name in enumerate(LAYERS):
            payload = struct.pack("<HhhBHh", layer, 0, 0, 255, 2, 0) + bytes(5)
            payload += struct.pack("<HH", *CELL) + zlib.compress(frame.layers[name].tobytes())
            chunks.append(legacy.chunk(0x2005, payload))
        body = b"".join(chunks)
        output.append(struct.pack("<IHHHHI", len(body) + 16, 0xF1FA, len(chunks), durations[index], 0, 0) + body)
    header = bytearray(128)
    struct.pack_into("<IHHHHHIH", header, 0, 128 + sum(map(len, output)), 0xA5E0, len(frames), *CELL, 32, 1, 100)
    struct.pack_into("<HBBhhHH", header, 32, 0, 1, 1, 0, 0, *CELL)
    return bytes(header) + b"".join(output)


def validate(folder, data, images):
    name = data["character_id"]
    master = (folder / (name + ".aseprite")).read_bytes()
    assert struct.unpack_from("<IHHHHH", master) == (len(master), 0xA5E0, len(images), 32, 32, 32)
    sheet = Image.open(folder / (name + ".png")).convert("RGBA")
    position, palette_max = 128, 0
    for index, expected in enumerate(images):
        length, magic, count, duration = struct.unpack_from("<IHHH", master, position)
        assert magic == 0xF1FA
        tag = next(t for t in data["animations"] if t["from"] <= index <= t["to"])
        assert duration == tag["duration_ms"]
        cursor, cels = position + 16, {}
        for _ in range(count):
            size, kind = struct.unpack_from("<IH", master, cursor)
            assert size >= 6 and cursor + size <= position + length
            payload = master[cursor + 6:cursor + size]
            if kind == 0x2005:
                layer, x, y, alpha, encoding = struct.unpack_from("<HhhBH", payload)
                assert (x, y, alpha, encoding) == (0, 0, 255, 2)
                assert struct.unpack_from("<HH", payload, 16) == CELL
                decoded = Image.frombytes("RGBA", CELL, zlib.decompress(payload[20:]))
                source = Image.open(folder / f"frames/{index:03d}-{LAYERS[layer]}.png").convert("RGBA")
                assert decoded.tobytes() == source.tobytes()
                cels[layer] = decoded
            cursor += size
        assert cursor == position + length and len(cels) == len(LAYERS)
        actual = Image.new("RGBA", CELL)
        for layer in range(len(LAYERS)): actual.alpha_composite(cels[layer])
        tile = sheet.crop((index % 5 * 32, index // 5 * 32, index % 5 * 32 + 32, index // 5 * 32 + 32))
        assert actual.tobytes() == expected.tobytes() == tile.tobytes()
        assert set(actual.getchannel("A").get_flattened_data()) == {0, 255}
        assert any(actual.getpixel((x, 31))[3] for x in range(32))
        colors = len({c for c in actual.get_flattened_data() if c[3]})
        assert colors <= data["validation"]["palette_max_per_frame"]
        palette_max = max(palette_max, colors)
        position += length
    assert position == len(master)
    for tag in data["animations"]:
        animated = images[tag["from"]:tag["to"] + 1]
        assert len({im.tobytes() for im in animated}) == len(animated)
    return {"status": "PASS", "id": name, "frames": len(images), "canvas": list(CELL),
            "pivot": [16, 32], "max_opaque_colors_per_frame": palette_max,
            "binary_alpha": True, "baseline": 31, "source_master_sheet_exact": True}


def contact(images, labels, columns, scale, path, grid=False):
    w, h = 32 * scale + 16, 32 * scale + 28
    result = Image.new("RGB", (columns * w, ((len(images) + columns - 1) // columns) * h), "#ddd8dc")
    draw = ImageDraw.Draw(result)
    for index, image in enumerate(images):
        x, y = index % columns * w + 8, index // columns * h + 20
        draw.text((x, y - 16), labels[index], fill="#51415a")
        tile = image.resize((32 * scale, 32 * scale), Image.Resampling.NEAREST)
        result.paste(tile, (x, y), tile)
        if grid:
            overlay = Image.new("RGBA", tile.size)
            lines = ImageDraw.Draw(overlay)
            for p in range(0, 32 * scale, scale):
                lines.line((p, 0, p, 32 * scale), fill=(117, 100, 130, 65))
                lines.line((0, p, 32 * scale, p), fill=(117, 100, 130, 65))
            result.paste(overlay, (x, y), overlay)
    result.save(path)


def export(frames, source_manifest, folder, name):
    folder.mkdir(exist_ok=True)
    (folder / "frames").mkdir(exist_ok=True)
    (folder / "frames/.gdignore").write_text("", encoding="utf-8")
    data = json.loads(json.dumps(source_manifest))
    data.update(character_id=name, canvas={"width": 32, "height": 32}, pivot={"x": 16, "y": 32})
    data["validation"].update(expected_baseline=31, palette_max_per_frame=48)
    data["design"].pop("head_source", None)
    data["design"]["key_source"] = "../WalalaWitch32/character-keys.png"
    data["reference_note"] = "New full-body 32x32 imagegen keys and pixel-part animation; see ../WalalaWitch32/README.md"
    images = [frame.composite() for frame in frames]
    sheet = Image.new("RGBA", (160, len(frames) // 5 * 32))
    entries = []
    for index, (frame, image) in enumerate(zip(frames, images)):
        x, y = index % 5 * 32, index // 5 * 32
        sheet.alpha_composite(image, (x, y))
        for layer, source in frame.layers.items(): source.save(folder / f"frames/{index:03d}-{layer}.png")
        tag = next(t for t in data["animations"] if t["from"] <= index <= t["to"])
        entries.append({"filename": f"{name}-{index:03d}", "frame": {"x": x, "y": y, "w": 32, "h": 32},
                        "rotated": False, "trimmed": False, "spriteSourceSize": {"x": 0, "y": 0, "w": 32, "h": 32},
                        "sourceSize": {"w": 32, "h": 32}, "duration": tag["duration_ms"]})
    sheet.save(folder / (name + ".png"))
    write_json(folder / "character-manifest.json", data)
    write_json(folder / (name + ".json"), {"frames": entries, "meta": {"image": name + ".png", "size": {"w": sheet.width, "h": sheet.height}, "scale": "1", "frameTags": data["animations"]}})
    (folder / (name + ".aseprite")).write_bytes(aseprite(frames, data))
    contact(images, [str(i) for i in range(len(images))], 5, 6, folder / "contact-sheet.png")
    return images, validate(folder, data, images)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare-keys", action="store_true")
    args = parser.parse_args()
    protected = json.loads((HERO / "myart-before.json").read_text(encoding="utf-8"))
    assert hashes() == protected
    if args.prepare_keys: prepare_keys()
    sheet = Image.open(HERO / "character-keys.png").convert("RGBA")
    assert sheet.size == (64, 64)
    keys = [sheet.crop((i % 2 * 32, i // 2 * 32, i % 2 * 32 + 32, i // 2 * 32 + 32)) for i in range(4)]
    palette = {c for c in sheet.get_flattened_data() if c[3]}
    movement = [idle(key) if column == 0 else walk(key, column - 1) for key in keys for column in range(5)]
    hero_manifest = json.loads((ART / "WalalaWitchV2/character-manifest.json").read_text(encoding="utf-8"))
    main_images, main_report = export(movement, hero_manifest, HERO, "walala-witch-32")
    tool_manifest = json.loads((ART / "WalalaToolsV2/character-manifest.json").read_text(encoding="utf-8"))
    actions = []
    for tag in tool_manifest["animations"]:
        action, direction = tag["name"].rsplit("-", 1)
        for step in range(tag["to"] - tag["from"] + 1):
            actions.append(tool_pose(keys[DIRECTIONS.index(direction)], action, direction, step, palette))
    tool_images, tool_report = export(actions, tool_manifest, TOOLS, "witch-tools-32")
    contact(keys, list(DIRECTIONS), 2, 12, HERO / "grid-preview.png", grid=True)
    contact(keys + [tool_images[i] for i in (10, 26, 38, 47)], list(DIRECTIONS) + ["chop", "mine", "cast", "reel"], 4, 8, HERO / "design-preview.png")
    for row, direction in enumerate(DIRECTIONS):
        animation = main_images[row * 5 + 1:row * 5 + 5]
        animation[0].save(HERO / ("walk-" + direction + ".gif"), save_all=True, append_images=animation[1:], duration=110, loop=0, disposal=2)
    assert hashes() == protected
    write_json(HERO / "validation-report.json", {"status": "PASS", "characters": [main_report, tool_report],
        "myart_hashes_unchanged": True, "aseprite_application_verified": False,
        "generated_source_sha256": hashlib.sha256((HERO / "generated-character.png").read_bytes()).hexdigest()})
    print("WITCH 32 PASS: native 32x32, 20 movement + 60 wand frames; exact layered PNG/Aseprite/sheet match; MyArt unchanged")


if __name__ == "__main__": main()
