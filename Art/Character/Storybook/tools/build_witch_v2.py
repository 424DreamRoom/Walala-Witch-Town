"""Compose generated head keys with existing authored movement and wand poses.

Only the two V2 export directories are written. MyArt is read for hash checks.
The current layered character and wand exports remain the body/pose sources.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

import build_characters as base
from validate_sources import validate

ART = Path(__file__).resolve().parents[1]
PROJECT = ART.parents[2]
HERO = ART / "WalalaWitchV2"
TOOLS = ART / "WalalaToolsV2"
DIRECTIONS = ("down", "up", "right", "left")


def protected_hashes():
    return {
        path.relative_to(PROJECT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in (PROJECT / "MyArt").rglob("*") if path.is_file()
    }


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def prepare_keys():
    """Slice/downsample the built-in imagegen result, without drawing new pixels."""
    source = Image.open(HERO / "generated-heads.png").convert("RGBA")
    sheet = Image.new("RGBA", (64, 72))
    for index in range(4):
        x, y = index % 2, index // 2
        part = source.crop((x * source.width // 2, y * source.height // 2,
                            (x + 1) * source.width // 2, (y + 1) * source.height // 2))
        alpha = part.getchannel("A").point(lambda value: 255 if value >= 160 else 0)
        part.putalpha(alpha)
        part = part.crop(alpha.getbbox()).resize((24, 29), Image.Resampling.NEAREST)
        sheet.alpha_composite(part, (x * 32 + 4, y * 36 + 4))
    alpha = sheet.getchannel("A")
    # Octree keeps the small amber/gold clusters that median cut discarded.
    sheet = sheet.quantize(colors=48, method=Image.Quantize.FASTOCTREE,
                           dither=Image.Dither.NONE).convert("RGBA")
    sheet.putalpha(alpha)
    sheet.save(HERO / "head-keys.png")


def source_layers(folder, index):
    return {
        name: Image.open(folder / f"frames/{index:03d}-{name}.png").convert("RGBA")
        for name in base.LAYERS
    }


def composite(layers):
    image = Image.new("RGBA", base.CELL)
    for name in base.LAYERS:
        image.alpha_composite(layers[name])
    return image


def update_head(layers, key, original_hat, bob, tools):
    # Keep every existing outfit, leg, hand, wand and effect pixel.
    layers["body"].paste((0, 0, 0, 0), (0, 0, 32, 33))
    layers["hair"] = Image.new("RGBA", base.CELL)
    layers["hair"].alpha_composite(key, (0, bob))
    equipment = layers["equipment"]
    if not tools:
        equipment.paste((0, 0, 0, 0), (0, 0, 32, 25))
    else:
        # A wand may cross the hat; erase only unchanged original hat pixels.
        for y in range(25):
            for x in range(32):
                old = original_hat.getpixel((x, y))
                if old[3] and equipment.getpixel((x, y)) == old:
                    equipment.putpixel((x, y), (0, 0, 0, 0))
    return layers


def build(source, destination, character_id, keys, tools=False):
    source_manifest = json.loads((source / "character-manifest.json").read_text(encoding="utf-8"))
    data = json.loads(json.dumps(source_manifest))
    data["character_id"] = character_id
    data["validation"]["palette_max_per_frame"] = 80
    data["reference_note"] = "Generated head keys; existing authored lower body and wand poses. See ../WalalaWitchV2/README.md."
    data["design"]["head_source"] = "../WalalaWitchV2/head-keys.png"
    destination.mkdir(exist_ok=True)
    (destination / "frames").mkdir(exist_ok=True)
    source_hashes, frames, images = {}, [], []
    for index in range(data["frame_source"]["count"]):
        if tools:
            tag = next(tag for tag in data["animations"] if tag["from"] <= index <= tag["to"])
            direction = tag["name"].rsplit("-", 1)[1]
            row, bob = DIRECTIONS.index(direction), 0
        else:
            row, column = divmod(index, 5)
            bob = -1 if column in (2, 4) else 0
        layers = source_layers(source, index)
        original = {name: layer.copy() for name, layer in layers.items()}
        for name in base.LAYERS:
            source_hashes[f"frames/{index:03d}-{name}.png"] = hashlib.sha256(
                (source / f"frames/{index:03d}-{name}.png").read_bytes()).hexdigest()
        original_hat = Image.open(ART / "WalalaWitch" / f"frames/{row * 5:03d}-equipment.png").convert("RGBA")
        layers = update_head(layers, keys[row], original_hat, bob, tools)
        assert layers["outfit"].tobytes() == original["outfit"].tobytes()
        assert layers["body"].crop((0, 33, 32, 48)).tobytes() == original["body"].crop((0, 33, 32, 48)).tobytes()
        assert layers["fx"].tobytes() == original["fx"].tobytes()
        frame = base.Pencil()
        frame.layers = layers
        image = frame.composite()
        assert image.size == (32, 48)
        assert set(image.getchannel("A").get_flattened_data()) == {0, 255}
        assert any(image.getpixel((x, 47))[3] for x in range(32))
        assert len({pixel for pixel in image.get_flattened_data() if pixel[3]}) <= 80
        for name, layer in layers.items():
            layer.save(destination / f"frames/{index:03d}-{name}.png")
        frames.append(frame)
        images.append(image)
    columns = data["export"]["columns"]
    sheet = Image.new("RGBA", (columns * 32, (len(frames) + columns - 1) // columns * 48))
    for index, image in enumerate(images):
        sheet.alpha_composite(image, (index % columns * 32, index // columns * 48))
    sheet.save(destination / (character_id + ".png"))
    exported = json.loads((source / (source_manifest["character_id"] + ".json")).read_text(encoding="utf-8"))
    exported["meta"]["image"] = character_id + ".png"
    for index, frame in enumerate(exported["frames"]):
        frame["filename"] = f"{character_id}-{index:03d}"
    write_json(destination / "character-manifest.json", data)
    write_json(destination / (character_id + ".json"), exported)
    write_json(destination / "body-source-sha256.json", source_hashes)
    (destination / (character_id + ".aseprite")).write_bytes(base.aseprite(frames, data))
    base.contact_sheet(images, [str(i) for i in range(len(images))], 5, 4, destination / "contact-sheet.png")
    if not tools:
        for row, direction in enumerate(DIRECTIONS):
            walk = images[row * 5 + 1:row * 5 + 5]
            walk[0].save(destination / ("walk-" + direction + ".gif"), save_all=True,
                         append_images=walk[1:], duration=110, loop=0, disposal=2)
    return images, validate(destination / "character-manifest.json")


def preview(images, tool_images):
    old_sheet = Image.open(HERO / "before.png").convert("RGBA")
    before = [old_sheet.crop((0, row * 48, 32, row * 48 + 48)) for row in range(4)]
    after = [images[row * 5] for row in range(4)]
    base.contact_sheet(before + after, ["before " + d for d in DIRECTIONS] +
                       ["after " + d for d in DIRECTIONS], 4, 6, HERO / "before-after.png")
    base.contact_sheet(after + [tool_images[index] for index in (10, 26, 38, 47)],
                       list(DIRECTIONS) + ["chop", "mine", "cast", "reel"], 4, 6, HERO / "design-preview.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare-keys", action="store_true", help="Re-slice the saved imagegen result before composing")
    args = parser.parse_args()
    baseline = json.loads((HERO / "myart-before.json").read_text(encoding="utf-8"))
    baseline = {name.replace("\\", "/"): digest for name, digest in baseline.items()}
    assert protected_hashes() == baseline, "MyArt differs from the recorded original hashes"
    if args.prepare_keys:
        prepare_keys()
    key_sheet = Image.open(HERO / "head-keys.png").convert("RGBA")
    assert key_sheet.size == (64, 72)
    assert set(key_sheet.getchannel("A").get_flattened_data()) == {0, 255}
    keys = [key_sheet.crop((index % 2 * 32, index // 2 * 36,
                           index % 2 * 32 + 32, index // 2 * 36 + 36)) for index in range(4)]
    images, hero_report = build(ART / "WalalaWitch", HERO, "walala-witch-v2", keys)
    tool_images, tools_report = build(ART / "WalalaTools", TOOLS, "witch-tools-v2", keys, tools=True)
    preview(images, tool_images)
    assert protected_hashes() == baseline
    write_json(HERO / "validation-report.json", {
        "status": "PASS", "characters": [hero_report, tools_report],
        "myart_hashes_unchanged": True, "outfit_legs_hands_wand_fx_preserved": True,
        "aseprite_application_verified": False,
    })
    print("WITCH V2 PASS: 20 movement + 60 wand frames, exact source/master/sheet round trip, protected MyArt unchanged")


if __name__ == "__main__":
    main()
