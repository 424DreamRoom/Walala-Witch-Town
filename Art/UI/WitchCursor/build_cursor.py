"""Export a pixel arrow with a witch hat attached to its lower-right tail.

Run from the project root: python Art/UI/WitchCursor/build_cursor.py
The hat palette comes from Scenes/Save/saving_indicator.gd.
"""
from pathlib import Path
import re

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
SOURCE = ROOT / "Scenes/Save/saving_indicator.gd"
HOTSPOT = (4, 4)
# Compact hat at the arrow's tail. Each character is one native pixel.
HAT_ROWS = [
    "           ooo",
    "          oHHo",
    "         oHHo",
    "        oHLLo",
    "        oHLLo",
    "       oHLLSo",
    "      oHLLLSo",
    "      oHLLLSo",
    "     oHLLLLSo",
    "     oLLLLSSo",
    "    oGGGCCGRo",
    "    oGGGCoGRo",
    "    oGGGCCGRo",
    "  ooHLLLLSSSSoo",
    " oHLLLLSSSSSSSSo",
    "oHLLLLLSSSSSSSSSo",
    " ooLLLLSSSSSSSoo",
    "   ooooooooooo",
]


def main():
    source = SOURCE.read_text(encoding="utf-8")
    colors = dict(re.findall(r'"(\w)": Color\("([0-9a-f]{6})"\)', source))
    hat = Image.new("RGBA", (32, 32))
    for y, row in enumerate(HAT_ROWS):
        for x, pixel in enumerate(row):
            if pixel in colors:
                hat.putpixel((x + 13, y + 13), tuple(bytes.fromhex(colors[pixel])) + (255,))

    # A one-pixel cream rim keeps the dark silhouette readable in every scene.
    native = Image.new("RGBA", hat.size)
    arrow = ImageDraw.Draw(native)
    arrow.polygon([(2, 2), (2, 20), (7, 16), (12, 25), (16, 23), (11, 15), (20, 15)], fill="#443345")
    arrow.polygon([(3, 4), (3, 18), (7, 14), (13, 23), (14, 22), (9, 14), (17, 14)], fill="#fff0cf")
    arrow.line([(8, 16), (13, 23)], fill="#ded0ea", width=1)
    for y in range(32):
        for x in range(32):
            if hat.getpixel((x, y))[3]:
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if 0 <= x + dx < 32 and 0 <= y + dy < 32:
                            native.putpixel((x + dx, y + dy), (255, 240, 207, 255))
    native.alpha_composite(hat)
    native.save(OUT / "witch_hat_native.png")
    cursor = native.resize((64, 64), Image.Resampling.NEAREST)
    cursor.save(OUT / "witch_hat.png")

    # Review only: compare the actual cursor on light and dark game colors.
    preview = Image.new("RGB", (384, 192))
    draw = ImageDraw.Draw(preview)
    for index, background in enumerate(("#302638", "#847b5b", "#f1d5a0")):
        left = index * 128
        draw.rectangle((left, 0, left + 127, 191), fill=background)
        preview.paste(cursor, (left + 32, 16), cursor)
        enlarged = native.resize((96, 96), Image.Resampling.NEAREST)
        preview.paste(enlarged, (left + 16, 88), enlarged)
    preview.save(OUT / "preview.png")
    assert cursor.getpixel(HOTSPOT)[3] == 255, "The click hotspot must be on the arrow tip."
    assert set(cursor.getchannel("A").tobytes()) == {0, 255}
    print("CURSOR ART: arrow with witch-hat tail, 64x64 RGBA, hotspot=(4, 4), alpha=0/255")


if __name__ == "__main__":
    main()
