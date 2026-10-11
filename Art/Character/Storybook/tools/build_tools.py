"""Native tool poses using the existing slim witch's layered character authoring."""
import json
import math
from pathlib import Path
import random
import struct
import argparse
import wave

from PIL import Image, ImageDraw, ImageFont

import build_characters as base

ROOT = Path(__file__).resolve().parents[4]
OUT = base.ROOT / "WalalaTools"
DIRECTIONS = ("down", "up", "right", "left")


def pose(action, direction, step):
    p = base.author(base.HERO, direction, tool_pose=True)
    flip = direction == "left"
    xy = lambda point: (31 - point[0], point[1]) if flip else point
    side = direction in ("right", "left")
    if action in ("chop", "mine"):
        grips = [(21, 29), (23, 29), (24, 35), (22, 35)]
        heads = [(21, 16), (28, 20), (29, 36), (26, 34)]
        if direction == "down":
            heads = [(24, 19), (28, 25), (24, 42), (26, 36)]
        elif direction == "up":
            heads = [(24, 18), (28, 19), (23, 23), (26, 28)]
        grip, head = grips[step], heads[step]
    else:
        grip = [(21, 29), (23, 31), (23, 34)][step] if action != "wait" else (23, 34)
        head = [(21, 13), (28, 19), (30, 22)][step] if action != "wait" else (30, 22)
        if action == "reel":
            grip, head = [(23, 34), (22, 31), (21, 29)][step], [(30, 22), (27, 18), (23, 14)][step]
        if direction == "up":
            head = (head[0] - 2, head[1] - 3)
    shoulder = (19 if side else 21, 32)
    a, b = xy(shoulder), xy(grip)
    cloth = base.ramp(base.HERO["outfit"])
    p.draw["outfit"].line((a, b), fill=base.rgba(base.INK), width=5)
    p.draw["outfit"].line((a, b), fill=base.rgba(cloth[2]), width=3)
    p.dot("outfit", a[0], a[1], cloth[3])
    p.rect("equipment", (b[0] - 1, b[1] - 1, b[0] + 1, b[1] + 1), base.HERO["skin"], "#c39496")
    # One-pixel outlines and a warm wooden handle keep tools in the map palette.
    for dx, color in [(-1, "#655154"), (0, "#cba77b"), (1, "#8f725d")]:
        p.line("equipment", [xy((grip[0] + dx, grip[1])), xy((head[0] + dx, head[1]))], color)
    # Every action uses the same violet crystal wand, including fishing.
    points = [(head[0], head[1] - 4), (head[0] + 2, head[1]),
              (head[0], head[1] + 3), (head[0] - 2, head[1])]
    p.poly("equipment", [xy(point) for point in points], "#b39dcf", "#655174")
    p.line("equipment", [xy((head[0] - 1, head[1] - 2)), xy((head[0] - 1, head[1]))], "#ede1f3")
    p.line("equipment", [xy((head[0] - 1, head[1] + 3)), xy((head[0] + 1, head[1] + 3))], "#e2c08b")
    if action in ("chop", "mine") and step == 2:
        for x, y in [(29, 30), (30, 32), (30, 40)]:
            p.dot("fx", *xy((x, y)), "#eddfb8")
    return p


def sounds():
    rng = random.Random(10102026)
    rate = 22050
    folder = ROOT / "Sounds/Walala"
    for name, duration, frequency in [("chop", .20, 165), ("mine", .28, 740), ("cast", .30, 260), ("bite", .28, 520), ("catch", .40, 660)]:
        samples = []
        for i in range(int(rate * duration)):
            t = i / rate
            decay = math.exp(-t * (24 if name == "chop" else 12))
            tone = math.sin(2 * math.pi * frequency * t)
            if name in ("cast", "bite"):
                tone = math.sin(2 * math.pi * (frequency * t + 1300 * t * t)) * .45
            elif name == "catch":
                tone = math.sin(2 * math.pi * frequency * (1 if t < .15 else 1.5) * t)
            noise = rng.uniform(-1, 1) * (.65 if name == "chop" else .20 if name in ("mine", "cast") else .08)
            samples.append(int(max(-1, min(1, (tone * .45 + noise) * decay)) * 24000))
        with wave.open(str(folder / (name + ".wav")), "wb") as sound:
            sound.setparams((1, 2, rate, 0, "NONE", "not compressed"))
            sound.writeframes(struct.pack("<" + "h" * len(samples), *samples))


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    frame_dir = OUT / "frames"
    frame_dir.mkdir(exist_ok=True)
    frames, tags = [], []
    for action, count, duration in [("chop", 4, 170), ("mine", 4, 170), ("cast", 3, 150), ("wait", 1, 300), ("reel", 3, 200)]:
        for direction in DIRECTIONS:
            start = len(frames)
            frames.extend(pose(action, direction, step) for step in range(count))
            tag = base.animation(action + "-" + direction, start, len(frames) - 1, duration)
            tag["loop"] = action == "wait"
            tags.append(tag)
    data = base.manifest(base.HERO, True)
    data.update(character_id="witch-tools", family="map-actions", animations=tags,
                required_animation_tags=[tag["name"] for tag in tags])
    data["frame_source"]["count"] = len(frames)
    data["validation"]["palette_max_per_frame"] = 64
    (OUT / "character-manifest.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    images = [frame.composite() for frame in frames]
    sheet = Image.new("RGBA", (160, 48 * (len(frames) // 5)))
    for index, (frame, image) in enumerate(zip(frames, images)):
        sheet.alpha_composite(image, ((index % 5) * 32, (index // 5) * 48))
        for name, layer in frame.layers.items():
            layer.save(frame_dir / f"{index:03d}-{name}.png")
    sheet.save(OUT / "witch-tools.png")
    durations = [0] * len(frames)
    for tag in tags:
        for index in range(tag["from"], tag["to"] + 1):
            durations[index] = tag["duration_ms"]
    exported = {"frames": [{"filename": f"witch-tools-{index:03d}",
                            "frame": {"x": index % 5 * 32, "y": index // 5 * 48, "w": 32, "h": 48},
                            "rotated": False, "trimmed": False,
                            "spriteSourceSize": {"x": 0, "y": 0, "w": 32, "h": 48},
                            "sourceSize": {"w": 32, "h": 48}, "duration": durations[index]}
                           for index in range(len(frames))],
                "meta": {"image": "witch-tools.png", "size": {"w": 160, "h": 576}, "scale": "1", "frameTags": tags}}
    (OUT / "witch-tools.json").write_text(json.dumps(exported, indent=2) + "\n", encoding="utf-8")
    (OUT / "witch-tools.aseprite").write_bytes(base.aseprite(frames, data))
    base.contact_sheet(images, [str(i) for i in range(len(frames))], 8, 4, OUT / "contact-sheet.png")
    preview = []
    for tag in (tags[2], tags[6], tags[10], tags[14], tags[18]):
        preview.extend(images[tag["from"]:tag["to"] + 1])
    base.contact_sheet(preview, ["chop"] * 4 + ["mine"] * 4 + ["cast"] * 3 + ["wait"] + ["reel"] * 3, 4, 5, OUT / "actions-preview.png")
    for im in images:
        assert im.size == (32, 48)
        assert set(im.getchannel("A").get_flattened_data()) == {0, 255}
        assert any(im.getpixel((x, 47))[3] == 255 for x in range(32))
        assert len(set(im.get_flattened_data())) <= 65
    print("WAND ART PASS: 60 native frames, 20 directional tags, 6 editable layers; existing sounds retained")


def runtime_preview():
    folder = ROOT / "Scenes/Gameplay/Verification/Harvest"
    font = ImageFont.truetype(str(ROOT / "Art/Fonts/FusionPixel/FusionPixel12Proportional.ttf"), 12)
    image = Image.new("RGB", (504, 170), "#28312f")
    draw = ImageDraw.Draw(image)
    for i, (name, label, box) in enumerate([
        ("chop", "\u780d\u6811", (335, 98, 495, 242)),
        ("mine_0", "\u6316\u77ff", (270, 94, 430, 238)),
        ("fishing_bite", "\u9493\u9c7c", (220, 146, 380, 290)),
    ]):
        screenshot = Image.open(folder / (name + ".png")).convert("RGB")
        image.paste(screenshot.crop(box), (i * 168 + 4, 22))
        draw.text((i * 168 + 71, 4), label, font=font, fill="#fff0d5")
    image.resize((1008, 340), Image.Resampling.NEAREST).save(OUT / "runtime-preview.png")
    print("RUNTIME PREVIEW PASS: three crops from real Godot screenshots")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime-preview", action="store_true")
    args = parser.parse_args()
    if args.runtime_preview:
        runtime_preview()
    else:
        build()
