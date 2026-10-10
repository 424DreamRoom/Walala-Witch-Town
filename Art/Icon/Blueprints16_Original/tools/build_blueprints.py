"""Author original blueprint icons at 16x16 and export editable Aseprite layers."""
from pathlib import Path
import argparse
import importlib.util
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[2]
spec = importlib.util.spec_from_file_location(
    "icon_writer", PROJECT / "Art/Icon/Resources16_Original/tools/build_resources.py"
)
writer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(writer)

# One character per native pixel; the existing writer separates four editable layers.
ICONS = {
    "furniture_blueprint": {
        "name_zh": "\u5bb6\u5177\u84dd\u56fe",
        "name_en": "Furniture blueprint",
        "palette": {
            "O": "4d5b5e", "B": "789ca0", "S": "5e7e85",
            "H": "b5c9bd", "D": "efe0b6", "d": "b7c5b0",
        },
        "rows": [
            "", "   OOOOOOOO", "   OHBBBBBHO", "   OHBBBBBHSO",
            "   OHdddBBOOOO", "   OHBDDDDBBSO", "   OHBDBBDBBSO",
            "   OHBDBBDBBSO", "   OHDDDDDDBSO", "   OHBDBBDBBSO",
            "   OHBDBBDBBSO", "   OHBBBBBBBSO", "   OHddddBBBSO",
            "   OHSSSSSSSSO", "    OOOOOOOOO", "",
        ],
    },
    "recipe_blueprint": {
        "name_zh": "\u98df\u8c31\u84dd\u56fe",
        "name_en": "Recipe blueprint",
        "palette": {
            "O": "77614f", "B": "d9c69b", "S": "baa27d",
            "H": "efe0b6", "D": "8e755a", "d": "cc9380", "e": "ad6e62",
        },
        "rows": [
            "", "    OOOOOOOOO", "   OHHHHHHHHSO", "   OHddBBBBBSO",
            "   OHBBDBBBDDO", "   OHBBBDBBDSO", "   OHBBDBBBDSO",
            "   OHDDDDDDBSO", "   OHDddddDDSO", "   OHBDeeDBBSO",
            "   OHBBddBBBSO", "   OHBBBBBBBSO", "   OHDDDBeedSO",
            "   OHSSSSeedSO", "    OOOOOeOeO", "",
        ],
    },
}


def make_preview(sprites):
    preview = Image.new("RGB", (576, 384), "#24252c")
    draw = ImageDraw.Draw(preview)
    chinese = ImageFont.truetype(
        str(PROJECT / "Art/Fonts/FusionPixel/FusionPixel12Proportional.ttf"), 24
    )
    english = ImageFont.load_default(size=15)
    small = ImageFont.load_default(size=13)
    for i, (name, sprite) in enumerate(sprites.items()):
        left, top = 16 + i * 288, 16
        for y in range(16):
            for x in range(16):
                color = "#44454d" if (x // 2 + y // 2) % 2 else "#383940"
                draw.rectangle(
                    (left + x * 16, top + y * 16,
                     left + x * 16 + 15, top + y * 16 + 15), fill=color
                )
        enlarged = sprite.resize((256, 256), Image.Resampling.NEAREST)
        preview.paste(enlarged, (left, top), enlarged)
        draw.text((left, 284), ICONS[name]["name_zh"], font=chinese, fill="#ded6c9")
        draw.text((left, 318), ICONS[name]["name_en"], font=english, fill="#ded6c9")
        draw.text((left, 346), "16 x 16 / RGBA / 4 layers", font=small, fill="#9a989f")
        preview.paste(sprite, (left + 240, 345), sprite)
    return preview


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("--overwrite", action="store_true", help="Rebuild this pack's generated files")
    overwrite = args.parse_args().overwrite
    sprites, sources = {}, {}
    for name, icon in ICONS.items():
        layers, sprite = writer.author(icon)
        assert all(layer.getbbox() for layer in layers)
        sprites[name] = sprite
        # Aseprite flags 1 (visible) + 2 (editable) keep source layers unlocked.
        sources[name] = writer.aseprite_bytes(layers, layer_flags=3)
    preview = make_preview(sprites)
    targets = [ROOT / (name + ext) for name in ICONS for ext in (".png", ".aseprite")]
    targets += [ROOT / "preview_nearest_16x.png", ROOT / "manifest.json"]
    if not overwrite:
        for path in targets:
            if path.exists():
                raise FileExistsError(f"Refusing to overwrite {path}; pass --overwrite to rebuild")
    ROOT.mkdir(parents=True, exist_ok=True)
    assets = []
    for name, sprite in sprites.items():
        with (ROOT / (name + ".aseprite")).open("wb" if overwrite else "xb") as file:
            file.write(sources[name])
        sprite.save(ROOT / (name + ".png"))
        assets.append({
            "slug": name, "name_zh": ICONS[name]["name_zh"],
            "name_en": ICONS[name]["name_en"], "png": name + ".png",
            "aseprite": name + ".aseprite",
            "godot_texture": "res://Art/Icon/Blueprints16_Original/" + name + ".png",
        })
    preview.save(ROOT / "preview_nearest_16x.png")
    manifest = {"count": len(assets), "size": [16, 16], "layers": writer.LAYERS, "assets": assets}
    (ROOT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("Created 2 native 16x16 PNG icons, 2 editable four-layer Aseprite sources, and preview.")


if __name__ == "__main__":
    main()
