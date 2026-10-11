"""Build runtime food icons from CC0 downloads, preferring read-only MyArt originals.

Requires Pillow. Run from any directory. Never writes to MyArt or existing art sets.
"""
from pathlib import Path
from io import BytesIO
import hashlib
import json
import struct
import zipfile
import zlib

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]
USER_ART = PROJECT / "MyArt/Icon/Food"
SOURCES = ROOT / "sources"
PRIMARY = "food_0.zip"

# These are visual placeholders; similar foods can deliberately share an icon.
ITEMS = {
    "herb": "spinach", "turnip": "turnip", "carrot": "carrot",
    "lettuce": "lettuce", "pea": "pea_pod", "strawberry": "strawberry",
    "rice": "rice_ball", "tomato": "tomato", "corn": "corn",
    "cucumber": "cucumber", "pepper": "chili_pepper_red", "melon": "cantaloupe_whole",
    "eggplant": "eggplant", "pumpkin": "pumpkin", "sweet_potato": "yam",
    "snow_cabbage": "cabbage", "winter_radish": "radish",
    "mushroom": "mushroom", "berry": "blueberries", "egg": "egg_whole_white",
    "honey": "honey_pot", "bamboo": "asparagus", "lotus": "ginger",
    "chestnut": "chestnut", "truffle": "mushroom", "prawn": "shrimp",
    "silverfin": "fish_fillet", "brook_carp": "fish_fillet", "moon_bass": "fish_fillet",
    "eel": "unagi", "lotus_fish": "fish_fillet", "ice_char": "fish_fillet",
    "star_koi": "fish_fillet", "wheat": "corn", "tea": "spinach",
    "moonflower": "vanilla",
}
DISHES = {
    "mushroom_soup": "soup_mushroom", "berry_pie": "pie_cherry_whole",
    "herb_stew": "soup_mushroom", "turnip_soup": "soup_miso",
    "carrot_salad": "lettuce", "pea_rice": "rice_ball",
    "strawberry_tart": "cake_slice_plain", "bamboo_rice": "rice_ball",
    "herb_omelet": "egg_fried", "berry_milk": "icecream_vanilla",
    "tomato_noodle": "macaroni", "corn_soup": "soup_pea",
    "cucumber_roll": "sushi_roll", "pepper_fish": "fish_fillet",
    "melon_ice": "icecream_mint", "prawn_rice": "shrimp_fried",
    "lotus_salad": "lettuce", "eggplant_pan": "eggplant",
    "pumpkin_stew": "soup_beet", "sweet_potato_roast": "yam",
    "chestnut_rice": "rice_ball", "wheat_bread": "bread_loaf_brown",
    "truffle_pasta": "macaroni", "snow_cabbage_pot": "soup_miso",
    "winter_radish_broth": "soup_miso", "moonflower_cake": "moon_cake",
    "carp_broth": "soup_miso", "moon_bass_grill": "fish_fillet",
    "eel_rice": "unagi", "lotus_fish_steam": "fish_fillet",
    "ice_char_roast": "fish_fillet", "star_koi_banquet": "sushi_nigiri",
    "four_seasons_platter": "pizza_vegetable_whole", "lantern_dessert": "fruitcake",
}
# Include the existing food-art catalog, ready for future item definitions.
EXTRAS = {
    "bread": "bread_loaf_brown", "fish_meat": "fish_fillet",
    "chicken_leg": "chicken_drumstick_raw", "napa_cabbage": "cabbage",
    "potato": "potato", "onion": "onion_brown", "apple": "apple_red",
    "shrimp": "shrimp", "beef": "steak_raw", "cheese": "cheese",
}
# Filled with native PNG entries from the supplementary CC0 archives.
SUPPLEMENTARY = {
    "milk": ("HenryFood.png", [96, 0, 16, 16]),
    "flour": ("HenryFood.png", [48, 16, 16, 16]),
    "oil": ("HenryFood.png", [64, 0, 16, 16]),
    "salt": ("HenryFood.png", [48, 16, 16, 16]),
    "dish_berry_milk": ("HenryFood.png", [112, 0, 16, 16]),
    "dish_mist_tea": ("food-fleurman_0.zip", "24x24/tea_03.png"),
    "dish_honey_tea": ("food-fleurman_0.zip", "24x24/tea_01.png"),
    "silverfin": ("food-bluecarrot16_20201221_0.zip", "32x32/seafood/fish_herring.png"),
    "brook_carp": ("food-bluecarrot16_20201221_0.zip", "32x32/seafood/fish_tilapia.png"),
    "moon_bass": ("food-bluecarrot16_20201221_0.zip", "32x32/seafood/fish_bass.png"),
    "lotus_fish": ("food-bluecarrot16_20201221_0.zip", "32x32/seafood/fish_anchovy.png"),
    "ice_char": ("food-bluecarrot16_20201221_0.zip", "32x32/seafood/fish_haddock.png"),
    "star_koi": ("food-bluecarrot16_20201221_0.zip", "32x32/seafood/fish_tilapia.png"),
    "dish_moon_bass_grill": ("food-7soul1_20201212.zip", "32x32/fish_cooked.png"),
    "dish_ice_char_roast": ("food-7soul1_20201212.zip", "32x32/fish_cooked.png"),
    "dish_lotus_fish_steam": ("food-7soul1_20201212.zip", "32x32/fish_cooked.png"),
}
USER_ALIASES = {"dish_wheat_bread": "bread"}
ALIASES = {"berries": "berry", "herbs": "herb"}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read_aseprite(source):
    """Decode the first and only RGBA frame, respecting visibility and cel offsets."""
    data = source.read_bytes()
    file_size, magic, frames, width, height, depth = struct.unpack_from("<IHHHHH", data)
    assert file_size == len(data) and magic == 0xA5E0, source
    assert frames == 1 and depth == 32, "Expected a single RGBA frame: " + str(source)
    frame_size, frame_magic, old_count = struct.unpack_from("<IHH", data, 128)
    assert frame_magic == 0xF1FA and frame_size == len(data) - 128
    count = old_count or struct.unpack_from("<I", data, 140)[0]
    position = 144
    layers, cels = [], {}
    for _ in range(count):
        chunk_size, kind = struct.unpack_from("<IH", data, position)
        assert chunk_size >= 6 and position + chunk_size <= len(data)
        payload = data[position + 6:position + chunk_size]
        if kind == 0x2004:
            flags, layer_type, child_level, _, _, blend = struct.unpack_from("<HHHHHH", payload)
            assert layer_type == 0 and child_level == 0 and blend == 0 and payload[12] == 255
            layers.append(bool(flags & 1))
        elif kind == 0x2005:
            index, x, y, opacity, cel_type, z = struct.unpack_from("<HhhBHh", payload)
            assert opacity == 255 and cel_type in (0, 2) and z == 0 and index not in cels
            w, h = struct.unpack_from("<HH", payload, 16)
            pixels = zlib.decompress(payload[20:]) if cel_type == 2 else payload[20:]
            assert len(pixels) == w * h * 4
            assert x >= 0 and y >= 0 and x + w <= width and y + h <= height
            cel = Image.new("RGBA", (width, height))
            cel.paste(Image.frombytes("RGBA", (w, h), pixels), (x, y))
            cels[index] = cel
        position += chunk_size
    assert position == len(data) and all(index < len(layers) for index in cels)
    visible_cels = [cels[index] for index, visible in enumerate(layers) if visible and index in cels]
    if len(visible_cels) == 1:
        # Preserve even RGB bytes under transparent pixels in single-layer originals.
        return visible_cels[0].copy()
    image = Image.new("RGBA", (width, height))
    for index, visible in enumerate(layers):
        if visible and index in cels:
            image = Image.alpha_composite(image, cels[index])
    assert image.getbbox(), source
    return image


def user_sources():
    sources = {}
    for source in sorted(USER_ART.rglob("*")):
        if source.suffix.lower() in (".png", ".aseprite", ".ase"):
            # The editable original takes precedence over an adjacent PNG export.
            if source.stem not in sources or source.suffix.lower() != ".png":
                sources[source.stem] = source
    return sources


def primary_image(name):
    with zipfile.ZipFile(SOURCES / PRIMARY) as archive:
        member = "food/" + name + ".png"
        data = archive.read(member)
    return Image.open(BytesIO(data)).convert("RGBA"), PRIMARY, member, data


def main():
    originals = user_sources()
    hashes_before = {str(p.relative_to(PROJECT)): sha(p.read_bytes()) for p in USER_ART.rglob("*") if p.is_file()}
    content = json.loads((PROJECT / "Scenes/Campaign/content.json").read_text(encoding="utf-8"))
    definitions = dict(ITEMS, **EXTRAS)
    definitions.update({"dish_" + key: value for key, value in DISHES.items()})
    for key, placeholder in content.get("food_icons", {}).items():
        if placeholder in SUPPLEMENTARY:
            SUPPLEMENTARY[key] = SUPPLEMENTARY[placeholder]
        else:
            definitions[key] = placeholder
    definitions.update({key: None for key in SUPPLEMENTARY})
    expected_items = set(content["items"]) - {"wood", "ore", "iron", "crystal", "scrap"}
    expected_dishes = {"dish_" + recipe["id"] for recipe in content["recipes"]}
    assert expected_items | expected_dishes <= definitions.keys(), "Missing food mapping"
    icons = ROOT / "icons"
    icons.mkdir(exist_ok=True)
    entries = []
    mapping = {}
    for key, placeholder in definitions.items():
        user_key = USER_ALIASES.get(key, key)
        source = originals.get(key) or originals.get(user_key) or originals.get(key.removeprefix("dish_"))
        if source:
            image = read_aseprite(source) if source.suffix.lower() != ".png" else Image.open(source).convert("RGBA")
            entry = {"id": key, "origin": "MyArt", "source": source.relative_to(PROJECT).as_posix(), "source_sha256": sha(source.read_bytes()), "placeholder": False}
        elif key in SUPPLEMENTARY:
            archive_name, member = SUPPLEMENTARY[key]
            if archive_name.endswith(".png"):
                data = (SOURCES / archive_name).read_bytes()
                x, y, w, h = member
                image = Image.open(BytesIO(data)).convert("RGBA").crop((x, y, x+w, y+h))
            else:
                with zipfile.ZipFile(SOURCES / archive_name) as archive:
                    data = archive.read(member)
                image = Image.open(BytesIO(data)).convert("RGBA")
            entry = {"id": key, "origin": "CC0", "archive": archive_name, "member": member, "source_sha256": sha(data), "placeholder": True}
        else:
            image, archive_name, member, data = primary_image(placeholder)
            entry = {"id": key, "origin": "CC0", "archive": archive_name, "member": member, "source_sha256": sha(data), "placeholder": True}
        target = icons / (key + ".png")
        image.save(target)
        # Preserve the complete native canvas and exact exported RGBA pixels.
        with Image.open(target) as exported:
            assert exported.size == image.size and exported.tobytes() == image.tobytes()
        entry.update(png=target.relative_to(PROJECT).as_posix(), size=list(image.size), rgba_sha256=sha(image.tobytes()))
        mapping[key] = "res://" + entry["png"]
        entries.append(entry)
    for alias, key in ALIASES.items():
        mapping[alias] = mapping[key]
    manifest = {"priority": "MyArt first, downloaded CC0 placeholders second", "icons": mapping, "assets": entries, "myart_sha256": hashes_before,
                "archives": {p.name: sha(p.read_bytes()) for p in SOURCES.glob("*.zip")}}
    (ROOT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    native = {entry['id']: 'res://' + entry['source'] for entry in entries if entry['origin'] == 'MyArt' and entry['source'].endswith('.aseprite')}
    source_mapping = {key: native.get(key, value.removesuffix('.png') + '.aseprite') for key, value in mapping.items()}
    for alias, key in ALIASES.items(): source_mapping[alias] = source_mapping[key]
    lines = ['extends RefCounted', '## Generated by Art/Icon/FoodPlaceholders/build_food_icons.py. MyArt has priority.', 'static var TEXTURES := {']
    lines.extend('\t"' + key + '": preload("res://Art/Source/aseprite_source.gd").texture("' + value + '"),' for key, value in sorted(source_mapping.items()))
    lines.extend(['}', '', 'static func texture(id: String) -> Texture2D:', '\treturn TEXTURES.get(id)', '',
                  'static func from_path(resource_path: String) -> Texture2D:', '\tvar id := resource_path.get_file().get_basename()',
                  '\tif id in TEXTURES: return TEXTURES[id]',
                  '\tif resource_path.ends_with(".png"): resource_path = resource_path.trim_suffix(".png") + ".aseprite"',
                  '\treturn preload("res://Art/Source/aseprite_source.gd").texture(resource_path)', ''])
    (PROJECT / "Scenes/UI/food_icons.gd").write_text("\n".join(lines), encoding="utf-8")
    preview(entries)
    hashes_after = {str(p.relative_to(PROJECT)): sha(p.read_bytes()) for p in USER_ART.rglob("*") if p.is_file()}
    assert hashes_before == hashes_after, "MyArt must remain untouched"
    print("Run Art/Source/build_sources.py after regenerating PNG previews to add any missing editable sources.")
    print("FOOD ICON BUILD PASS", len(entries), "icons;", sum(e["origin"] == "MyArt" for e in entries), "MyArt mappings; original hashes unchanged")


def preview(entries):
    cols, cell_w, cell_h = 8, 152, 126
    canvas = Image.new("RGB", (cols * cell_w, ((len(entries) + cols - 1) // cols) * cell_h), "#eadbc3")
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    for i, entry in enumerate(entries):
        x, y = i % cols * cell_w, i // cols * cell_h
        for cy in range(8, 104, 8):
            for cx in range(28, 124, 8):
                draw.rectangle((x+cx,y+cy,x+cx+7,y+cy+7), fill="#c5bbaa" if (cx+cy)//8%2 else "#eee3ce")
        image = Image.open(PROJECT / entry["png"]).convert("RGBA")
        scale = max(1, 80 // max(image.size))
        image = image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)
        canvas.paste(image, (x + (cell_w-image.width)//2, y + (106-image.height)//2), image)
        label = entry["id"].removeprefix("dish_")
        draw.text((x+4,y+105), label, font=font, fill="#453831")
        draw.text((x+4,y+116), entry["origin"], font=font, fill="#3d704e" if entry["origin"] == "MyArt" else "#775751")
    canvas.save(ROOT / "preview.png")


if __name__ == "__main__":
    main()
