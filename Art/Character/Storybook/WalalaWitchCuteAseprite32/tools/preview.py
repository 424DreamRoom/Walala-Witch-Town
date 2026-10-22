"""Integer-scale art comparisons and wrapped animation strips, never redraws art."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ASSET = Path(__file__).resolve().parents[1]
ROOT = ASSET.parents[3]
FONT = "C:/Windows/Fonts/msyh.ttc"
BG, INK, MUTED = "#f4eee5", "#493c53", "#817486"


def review(images, tags):
    old = Image.open(ASSET.parent / "WalalaWitchAseprite32/walala-witch.png").convert("RGBA")
    previous = [old.crop((i % 8 * 32, i // 8 * 32, i % 8 * 32 + 32, i // 8 * 32 + 32)) for i in range(152)]
    image = Image.new("RGB", (960, 620), BG)
    draw = ImageDraw.Draw(image)
    title = ImageFont.truetype(FONT, 26)
    text = ImageFont.truetype(FONT, 18)
    small = ImageFont.truetype(FONT, 14)
    draw.text((28, 18), "小月亮女巫 · 人物美术优化", fill=INK, font=title)
    draw.text((28, 57), "银白短发 / 浅紫软帽 / 圆脸与腮红 / 奶油领口", fill=MUTED, font=text)

    def paste(frame, x, y, scale):
        tile = frame.resize((32 * scale, 32 * scale), Image.Resampling.NEAREST)
        image.paste(tile, (x, y), tile)

    for column, (label, frame) in enumerate((("原版", previous[0]), ("可爱版", images[0]))):
        x = 34 + column * 258
        draw.rounded_rectangle((x, 100, x + 240, 385), 12, fill="#fffaf1")
        draw.text((x + 17, 113), label, fill=INK, font=text)
        paste(frame, x + 24, 150, 6)
        paste(frame, x + 188, 343, 1)
        draw.text((x + 16, 350), "6× / 原始尺寸", fill=MUTED, font=small)
    draw.text((575, 111), "四方向", fill=INK, font=text)
    for column, name in enumerate(("down", "up", "right", "left")):
        paste(images[tags["idle-" + name]["from"]], 570 + column % 2 * 176, 154 + column // 2 * 130, 4)
    draw.text((30, 415), "同场景人物比例", fill=INK, font=text)
    siblings = []
    for name, index in (("mori", 16), ("yingluo", 16), ("blue_blonde", 0)):
        kind = "residents" if name == "mori" else "guides" if name == "yingluo" else "customers"
        sheet = Image.open(ROOT / f"Art/Characters/NPC32/{kind}/{name}.png").convert("RGBA")
        siblings.append(sheet.crop((index * 32, 0, (index + 1) * 32, 32)))
    for frame, x in zip((siblings[0], images[0], siblings[1], siblings[2]), (42, 198, 354, 510)):
        paste(frame, x, 451, 4)
    draw.text((708, 467), "32 × 32 原生像素", fill=INK, font=text)
    draw.text((708, 499), "四方向 · 152 帧", fill=MUTED, font=text)
    draw.text((708, 531), "23 色 · 透明背景", fill=MUTED, font=text)
    image.save(ASSET / "before-after.png")

    # Last cell is frame zero, so the wrap can be inspected beside the last key.
    contact = Image.new("RGB", (1264, 8 * 145), "#302b40")
    cd = ImageDraw.Draw(contact)
    metrics = {}
    for row, (action, direction) in enumerate((a, d) for a in ("walk", "run") for d in ("down", "up", "right", "left")):
        tag = tags[f"{action}-{direction}"]
        sequence = images[tag["from"]:tag["to"] + 1]
        cd.text((6, row * 145 + 4), f"{action}-{direction}", fill="#f5e3c5", font=small)
        for col, frame in enumerate(sequence + sequence[:1]):
            tile = frame.resize((128, 128), Image.Resampling.NEAREST)
            contact.paste(tile, (100 + col * 128, row * 145 + 17), tile)
        pixels = [list(frame.getdata()) for frame in sequence]
        changes = [sum(a != b for a, b in zip(pixels[i], pixels[(i + 1) % len(pixels)])) for i in range(len(pixels))]
        metrics[f"{action}-{direction}"] = {"changed_pixels_between_frames_including_wrap": changes}
    contact.save(ASSET / "loop-review.png")
    (ASSET / "loop-review.json").write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
