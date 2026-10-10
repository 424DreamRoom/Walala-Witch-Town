"""Native-size and nearest-neighbor comparisons from the actual exported sheets."""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[2]


def frame(path, index=0, columns=5):
    image = Image.open(path).convert("RGBA")
    x, y = index % columns * 32, index // columns * 48
    return image.crop((x, y, x + 32, y + 48))


def main():
    hero = frame(ROOT / "WalalaWitch/walala-witch.png")
    old = Image.open(PROJECT / "Art/Character/WalalaWitch/walala_witch.png").convert("RGBA")
    old = old.crop((0, 0, 16, 24)).resize((32, 48), Image.Resampling.NEAREST)
    green = frame(ROOT / "WitchCustomers/green_braids/green_braids.png", columns=6)
    blue = frame(ROOT / "WitchCustomers/blue_blonde/blue_blonde.png", columns=6)
    images, names = [old, hero, green, hero, blue], ["previous", "redrawn", "green_braids", "witch", "blue_blonde"]
    preview = Image.new("RGB", (720, 312), "#ddd8dc")
    draw = ImageDraw.Draw(preview)
    for i, (image, name) in enumerate(zip(images, names)):
        x = i * 144 + 8
        draw.text((x, 8), name, fill="#5a485a")
        preview.paste(image, (x + 48, 32), image)
        large = image.resize((128, 192), Image.Resampling.NEAREST)
        preview.paste(large, (x, 104), large)
    preview.save(ROOT / "before-after.png")
    sheet = Image.open(ROOT / "WalalaWitch/walala-witch.png").convert("RGBA")
    previous = ROOT / "WalalaWitch/Verification/before-slimming.png"
    if previous.exists():
        from build_characters import contact_sheet
        images, labels = [], []
        for path, label in ((previous, "previous"), (ROOT / "WalalaWitch/walala-witch.png", "slimmer")):
            for row, direction in enumerate(("down", "up", "right", "left")):
                images.append(frame(path, row * 5))
                labels.append(label + " " + direction)
        contact_sheet(images, labels, 4, 4, ROOT / "slimming-comparison.png")
    for row, direction in enumerate(("down", "up", "right", "left")):
        frames = []
        for column in range(1, 5):
            tile = sheet.crop((column * 32, row * 48, (column + 1) * 32, (row + 1) * 48))
            canvas = Image.new("RGBA", (128, 192), "#ddd8dc")
            canvas.alpha_composite(tile.resize(canvas.size, Image.Resampling.NEAREST))
            frames.append(canvas.convert("RGB"))
        frames[0].save(ROOT / "WalalaWitch" / ("walk-" + direction + ".gif"), save_all=True, append_images=frames[1:], duration=110, loop=0, disposal=2)
    print("PREVIEWS PASS native/4x comparison and four walk loops")


if __name__ == "__main__":
    main()
