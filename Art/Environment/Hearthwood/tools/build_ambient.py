"""Native pixel loops derived from the scene art, with fixed roots and fixtures."""
import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "Ambient"
SOURCE = OUT.parent
FRAMES = 12
PADDING = 4
SPECS = {
    "town_tree": {"motion": "wind", "hinge": 64, "amplitude": 2.0, "fps": 2.5},
    "outdoor_birch": {"motion": "wind", "hinge": 73, "amplitude": 2.0, "fps": 2.5},
    "outdoor_pine": {"motion": "wind", "hinge": 95, "amplitude": 2.0, "fps": 2.5},
    "planter": {"motion": "wind", "top": 26, "hinge": 38, "amplitude": 1.2, "fps": 3.0},
    "outdoor_bush": {"motion": "wind", "hinge": 32, "amplitude": 1.2, "fps": 3.0},
    "outdoor_fern": {"motion": "wind", "hinge": 18, "amplitude": 1.2, "fps": 3.0},
    "outdoor_flowerbed": {"motion": "wind", "hinge": 18, "amplitude": 1.2, "fps": 3.0},
    "outdoor_herbs": {"motion": "wind", "hinge": 18, "amplitude": 1.2, "fps": 3.0},
    "outdoor_pond": {"motion": "water", "fps": 4.0},
    "outdoor_lamp": {"motion": "light", "fps": 6.0},
    "home_desk": {"motion": "flame", "fps": 6.0},
}


def padded(image):
    result = Image.new("RGBA", (image.width + PADDING * 2, image.height))
    result.paste(image, (PADDING, 0))
    return result


def wind(image, spec, frame, gust):
    phase = frame * math.tau / FRAMES
    result = Image.new("RGBA", (image.width + PADDING * 2, image.height))
    for y in range(image.height):
        top = spec.get("top", 0)
        weight = max(0.0, 1.0 - max(0, y - top) / (spec["hinge"] - top)) ** .8
        amplitude = spec["amplitude"] * (1.5 if gust else 1.0)
        shift = round(math.sin(phase) * amplitude * weight * (1 + .12 * math.sin(phase * 2 + y / 14)))
        assert abs(shift) < PADDING
        result.paste(image.crop((0, y, image.width, y + 1)), (PADDING + shift, y))
    return result


def water(image, frame):
    if frame == 0:
        return padded(image)
    result = image.copy()
    draw = ImageDraw.Draw(result)
    base = (114, 158, 154, 255)
    highlights = {(177, 201, 181, 255), (147, 186, 176, 255)}
    for y in range(14, 40):
        for x in range(12, 68):
            if result.getpixel((x, y)) in highlights:
                result.putpixel((x, y), base)
    phase = frame * math.tau / FRAMES
    for index, (cx, cy) in enumerate([(27, 25), (48, 33)]):
        x = cx + round(math.sin(phase + index) * 3)
        y = cy + round(math.sin(phase * 2 + index))
        length = 4 + (frame + index * 3) % 6
        for dx in range(length):
            if image.getpixel((x + dx, y))[:3] in [(114, 158, 154), (147, 186, 176), (177, 201, 181)]:
                draw.point((x + dx, y), fill="#b1c9b5" if frame % 3 == 0 else "#93bab0")
    # Move only the lily and flower; the shoreline stays exactly in place.
    lily = Image.new("RGBA", (14, 14))
    colors = {(53, 75, 62), (88, 116, 87), (129, 148, 103), (219, 168, 153), (234, 214, 173)}
    for y in range(16, 30):
        for x in range(47, 61):
            pixel = image.getpixel((x, y))
            if pixel[:3] in colors:
                lily.putpixel((x - 47, y - 16), pixel)
                result.putpixel((x, y), base)
    result.alpha_composite(lily, (47 + round(math.sin(phase)), 16 + round(math.sin(phase) * .7)))
    return padded(result)


def light(image, frame, candle=False):
    result = image.copy()
    draw = ImageDraw.Draw(result)
    phase = frame * math.tau / FRAMES
    if candle:
        x = 78 + round(math.sin(phase))
        top = 6 + (frame % 3)
        draw.polygon([(78, 11), (x - 1, 8), (x, top), (x + 1, 9), (79, 11)], fill="#d3ab71")
        draw.point((x, 9), fill="#fff0c7")
        draw.point((78, 10), fill="#ead6ad")
    elif frame != 0:
        color = ["#ead6ad", "#fff0c7", "#e3c48d", "#f3dfaf"][frame % 4]
        draw.rectangle((24, 17, 27, 25), fill=color)
        draw.line((25, 18, 25, 24), fill="#fff0c7")
    return padded(result)


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"version": 1, "frames_per_bank": FRAMES, "padding": PADDING, "assets": {}}
    for kind, spec in SPECS.items():
        source = Image.open(SOURCE / (kind + ".png")).convert("RGBA")
        banks = 2 if spec["motion"] == "wind" else 1
        frames = []
        for bank in range(banks):
            for frame in range(FRAMES):
                if spec["motion"] == "wind":
                    image = wind(source, spec, frame, bank == 1)
                elif spec["motion"] == "water":
                    image = water(source, frame)
                else:
                    image = light(source, frame, spec["motion"] == "flame")
                frames.append(image)
        sheet = Image.new("RGBA", (frames[0].width * FRAMES, source.height * banks))
        for index, image in enumerate(frames):
            sheet.paste(image, (index % FRAMES * image.width, index // FRAMES * image.height))
        sheet.save(OUT / (kind + ".png"))
        manifest["assets"][kind] = dict(spec, cell=[frames[0].width, source.height], banks=banks, source=[source.width, source.height])
        unique = len({im.tobytes() for im in frames[:FRAMES]})
        assert unique >= 3, (kind, unique)
        if spec["motion"] == "wind":
            for image in frames:
                assert image.crop((PADDING, spec["hinge"], source.width + PADDING, source.height)).tobytes() == source.crop((0, spec["hinge"], source.width, source.height)).tobytes()
                assert set(image.get_flattened_data()) <= set(source.get_flattened_data())
            assert frames[0].tobytes() == padded(source).tobytes()
            assert frames[FRAMES].tobytes() == padded(source).tobytes()
        gif = []
        for image in frames[:FRAMES]:
            backdrop = Image.new("RGBA", image.size, "#516a55")
            backdrop.alpha_composite(image)
            gif.append(backdrop.convert("RGB").resize((image.width * 3, image.height * 3), Image.Resampling.NEAREST))
        gif[0].save(OUT / (kind + ".gif"), save_all=True, append_images=gif[1:], duration=round(1000 / spec["fps"]), loop=0)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("AMBIENT ART PASS", len(SPECS), "loops; fixed roots/fixtures, original palette, integer pixel motion")


def preview():
    folder = SOURCE / "Verification/Ambient"
    frames = [Image.open(folder / f"field_{index:02d}.png").convert("RGB") for index in range(24)]
    frames = [image.resize((1280, 720), Image.Resampling.NEAREST) for image in frames]
    palette = frames[0].quantize(colors=256, dither=Image.Dither.NONE)
    frames = [image.quantize(palette=palette, dither=Image.Dither.NONE) for image in frames]
    frames[0].save(OUT / "runtime-field.gif", save_all=True, append_images=frames[1:], duration=200, loop=0)
    print("AMBIENT PREVIEW PASS 24 real Godot frames")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime-preview", action="store_true")
    args = parser.parse_args()
    preview() if args.runtime_preview else build()
