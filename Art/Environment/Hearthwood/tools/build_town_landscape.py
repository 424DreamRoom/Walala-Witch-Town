"""Native-pixel town set dressing; reuses sprites without changing their pixels.

Keep the busy textures at garden edges and leave travel lanes visually quiet.
All generated images belong to build_town_layout's Art/ output directory.
"""
import random

from PIL import Image, ImageDraw, ImageFilter

import build_art as art

# Authored pockets, with uneven spacing and a different emphasis per district.
# These are composition anchors, not new destinations or gameplay obstacles.
POCKETS = [
    ("west_orchard", (206, 185), "birch"),
    ("north_copse", (600, 132), "pine"),
    ("workshop_verge", (1178, 440), "herbs"),
    ("east_flower_garden", (1202, 475), "flowerbed"),
    ("south_lane_herbs", (350, 685), "herbs"),
    ("reading_garden", (672, 1020), "flowerbed"),
    ("windmill_copse", (410, 1328), "birch"),
    ("south_wildflowers", (881, 1230), "herbs"),
    ("reed_bank", (1450, 1240), "bush"),
    ("west_meadow", (42, 1280), "pine"),
]
MEADOWS = [
    [(24, 66), (207, 38), (355, 83), (380, 222), (331, 318), (174, 335), (30, 290)],
    [(514, 35), (656, 18), (783, 70), (766, 178), (639, 207), (524, 171)],
    [(774, 290), (946, 277), (1110, 329), (1102, 420), (922, 455), (770, 417)],
    [(1109, 100), (1353, 75), (1465, 182), (1440, 564), (1300, 613), (1139, 487)],
    [(31, 720), (163, 690), (237, 764), (221, 916), (81, 944), (32, 849)],
    [(457, 779), (614, 754), (740, 796), (748, 908), (592, 947), (483, 899)],
    [(60, 969), (285, 947), (485, 1023), (697, 992), (714, 1444), (570, 1508), (244, 1482), (65, 1368)],
    [(756, 1001), (949, 963), (1178, 1033), (1201, 1405), (1010, 1467), (791, 1404)],
    [(1201, 1227), (1370, 1210), (1461, 1285), (1430, 1497), (1271, 1515), (1159, 1403)],
]


def yard_polygons(layout):
    yards = []
    for index, house in enumerate(layout["buildings"]):
        x, y, half, depth = house["x"], house["y"], house["w"] // 2 + 17, house["h"] + 13
        yards.append([(x - half, y - depth + 16), (x - half + 21, y - depth),
                      (x + half - 14, y - depth + 3), (x + half + 6, y - depth + 24),
                      (x + half + 8, y - 3), (x + half - 19, y + 20 + index % 3 * 4),
                      (x + 24, y + 34), (x - half + 13, y + 27), (x - half - 6, y + 4)])
    return yards


def base_ground(layout, size, seed):
    """Low-frequency meadow shapes, sparse grass and clustered texture islands."""
    rng = random.Random(seed + 31)
    image = art.canvas(size, "#6b805b")
    d = ImageDraw.Draw(image)
    for index, polygon in enumerate(MEADOWS):
        d.polygon(polygon, fill=["#71845e", "#6e825c", "#667e59", "#71845e", "#607951"][index % 5])
    # Most of the lawn is quiet; short grouped marks replace uniform confetti.
    for _ in range(6500):
        x, y = rng.randrange(size[0]), rng.randrange(size[1])
        d.line((x, y, x + rng.randrange(1, 4), y), fill=rng.choice(["#687e57", "#728760"]))
    for _, (cx, cy), _ in POCKETS:
        for _ in range(460):
            x, y = round(rng.gauss(cx, 69)), round(rng.gauss(cy, 41))
            if not (2 <= x < size[0] - 3 and 3 <= y < size[1] - 2):
                continue
            color = rng.choice(["#627953", "#728760", "#7e9066"])
            d.line((x - 2, y, x, y), fill=color)
            if rng.randrange(3) == 0:
                d.line((x, y, x + 1, y - 2), fill=color)
                d.point((x + 3, y - 1), fill="#87956b")
    yards = Image.new("L", size)
    yd = ImageDraw.Draw(yards)
    for polygon in layout["yards"]:
        # Fit the footprint, rather than repeating one large octagonal plot.
        yd.polygon(polygon, fill=255)
    # Discrete pixel steps at the verge; no blur or filtered source assets.
    image.paste(art.canvas(size, "#81825b"), (0, 0), yards.filter(ImageFilter.MaxFilter(9)))
    image.paste(art.canvas(size, "#90835f"), (0, 0), yards.filter(ImageFilter.MaxFilter(3)))
    image.paste(art.canvas(size, "#978761"), (0, 0), yards)
    return image


def intersect(a, b):
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def clustered_props(layout, masks, size, bank_x):
    """Keep entire new silhouettes away from roads, roofs and useful props."""
    routes = Image.new("L", size)
    for mask in masks.values():
        routes.paste(255, (0, 0), mask)
    keepout = routes.filter(ImageFilter.MaxFilter(17))
    buildings = []
    for item in layout["buildings"]:
        with Image.open(art.OUT / (item["kind"] + ".png")) as sprite:
            w, h = sprite.size
        buildings.append((item["x"] - w // 2 - 8, item["y"] - h - 8,
                          item["x"] + w // 2 + 8, item["y"] + 8))
    new = []
    for name, (cx, cy), kind in POCKETS:
        candidates = [(kind, -27, -6), (kind, 19, 12), ("bush", 48, -17),
                      ("herbs", -52, 24), ("herbs", 30, 39), ("bush", -8, 45)]
        if kind in ("pine", "birch"):
            candidates[1] = ("birch" if kind == "pine" else "pine", 24, 17)
        for sprite_kind, dx, dy in candidates:
            x, y = cx + dx, cy + dy
            with Image.open(art.OUT / ("outdoor_" + sprite_kind + ".png")) as sprite:
                w, h = sprite.size
            bounds = (x - w // 2 - 2, y - h - 2, x + w // 2 + 3, y + 3)
            if bounds[0] < 2 or bounds[1] < 2 or bounds[2] >= size[0] or bounds[3] >= size[1]:
                continue
            if bounds[2] >= min(bank_x(yy) for yy in range(bounds[1], bounds[3] + 1)) - 8:
                continue
            if keepout.crop(bounds).getbbox() or any(intersect(bounds, b) for b in buildings):
                continue
            useful_props = [p for p in layout["props"] if p.get("solid", True) and p["kind"] not in ("outdoor_pine", "outdoor_birch")]
            if any(intersect(bounds, (p["x"] - p["w"] / 2 - 8, p["y"] - p["h"] - 8,
                                      p["x"] + p["w"] / 2 + 8, p["y"] + 8)) for p in useful_props):
                continue
            tree = sprite_kind in ("pine", "birch")
            new.append(dict(kind="outdoor_" + sprite_kind, x=x, y=y, w=10 if tree else 0,
                            h=8 if tree else 0, solid=tree, outdoor_decoration=True, composition_group=name))
    return new


def ground_details(image, layout, masks, bank_x, seed):
    """A landmark collar, garden accents and reeds, all on the ground layer."""
    d = ImageDraw.Draw(image)
    # A quiet, distinct ring gives the public square an identifiable centre.
    d.ellipse((623, 431, 741, 497), outline="#998d70", width=3)
    d.ellipse((628, 434, 736, 494), outline="#d0bd96", width=2)
    rng = random.Random(seed + 79)
    roads = Image.new("L", image.size)
    for mask in masks.values():
        roads.paste(255, (0, 0), mask)
    yards = [(b["x"] - b["w"] / 2 - 27, b["y"] - b["h"] - 18,
              b["x"] + b["w"] / 2 + 27, b["y"] + 39) for b in layout["buildings"]]
    for _, (cx, cy), kind in POCKETS:
        for _ in range(28):
            x, y = cx + rng.randrange(-75, 76), cy + rng.randrange(-42, 64)
            if not (4 <= x < image.width - 4 and 4 <= y < image.height - 4):
                continue
            if x >= bank_x(y) - 15 or roads.crop((x - 4, y - 4, x + 5, y + 5)).getbbox():
                continue
            if any(a < x < c and b < y < e for a, b, c, e in yards):
                continue
            d.line((x, y, x - 1, y - 3), fill="#587457")
            d.line((x, y, x + 3, y - 1), fill="#819467")
            if kind in ("flowerbed", "herbs") and rng.randrange(3) == 0:
                d.line((x - 1, y - 4, x + 1, y - 4), fill=rng.choice([art.P["rose_light"], art.P["cream"], art.P["violet"]]))
    for cy in range(70, image.height - 20, 91):
        if 590 <= cy <= 710:
            continue
        for _ in range(8):
            y = cy + rng.randrange(-10, 11)
            x = bank_x(y) + rng.randrange(-5, 6)
            h = rng.randrange(5, 12)
            d.line((x, y, x - 1, y - h), fill="#536d50")
            d.point((x - 1, y - h), fill="#b3a07b")
            d.line((x, y - 2, x + 3, y - 6), fill="#819467")
