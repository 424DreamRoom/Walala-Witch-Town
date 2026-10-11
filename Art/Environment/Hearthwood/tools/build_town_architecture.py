"""Authored native-pixel silhouettes for Hearthwood; outputs only to Art/."""
from PIL import Image, ImageDraw
import build_art as art

P = art.P
SLATE = ["#414e55", "#5b6d76", "#72848a", "#a5b3aa"]
ROSE = ["#75424a", "#965c61", "#b47978", "#d3a18f"]
MOSS = ["#394e42", "#526c53", "#6f8662", "#a2ad7c"]
STRAW = ["#78613d", "#a18550", "#b49a60", "#dbc58b"]
PLUM = ["#514559", "#72617b", "#8d7a91", "#bca3b6"]
TERRA = ["#774831", "#9e6347", "#b57e59", "#dbab7b"]
ASSETS = {}
COLLISIONS = {
    "shop_3": (184, 76), "shop_4": (112, 98), "shop_5": (184, 92),
    "shop_6": (136, 76), "shop_7": (144, 82), "shop_8": (152, 70),
    "town_greenhouse": (184, 68), "town_atelier": (144, 94),
    "town_bakery": (184, 80), "town_library": (184, 98),
    "town_manor": (184, 96), "town_windmill": (88, 100),
    "town_cottage": (144, 74), "town_boathouse": (184, 64),
}


def roof(d, points, colors):
    """Texture clipped to an individually drawn roof, including sloping sides."""
    mask = Image.new("1", d._image.size)
    ImageDraw.Draw(mask).polygon(points, fill=1)
    tex = art.canvas(d._image.size)
    t = ImageDraw.Draw(tex)
    x0, y0, x1, y1 = mask.getbbox()
    t.rectangle((x0, y0, x1, y1), fill=colors[0])
    for row, y in enumerate(range(y0 + 3, y1, 7)):
        for col, x in enumerate(range(x0 - (5 if row % 2 else 0), x1, 11)):
            t.rectangle((x, y, x + 9, y + 5), fill=colors[1 + (row + col * 3) % 2])
            t.line((x + 1, y, x + 8, y), fill=colors[3])
            t.line((x + 9, y + 1, x + 9, y + 5), fill=colors[0])
    d._image.paste(tex, (0, 0), mask)
    d.line(points + [points[0]], fill=P["ink"], width=2)
    d.line(points[:2], fill=colors[3], width=2)


def wall(d, box, material="timber"):
    x0, y0, x1, y1 = box
    art.panel(d, box, "#d2bc93" if material == "plaster" else P["wood_mid"], highlight=P["cream"])
    if material == "timber":
        for y in range(y0 + 4, y1, 8):
            d.line((x0 + 1, y, x1 - 1, y), fill=P["grain"])
            d.line((x0 + 2, y + 1, x1 - 2, y + 1), fill=P["wood_light"])
    else:
        for yy in range(y0 + 3, y1 - 12, 11):
            for xx in range(x0 + 10 + (yy % 3) * 4, x1 - 8, 23):
                d.line((xx, yy, xx + 3, yy), fill="#c4ad85")
        for x in (x0 + 4, x1 - 4):
            d.line((x, y0, x, y1), fill=P["bark"], width=5)
        d.line((x0, y0 + 20, x1, y0 + 20), fill=P["wood"], width=3)
    art.panel(d, (x0, y1 - 9, x1, y1), P["stone"], highlight=P["stone_light"])
    for x in range(x0 + 8, x1, 17):
        d.line((x, y1 - 7, x, y1 - 1), fill=P["deep"])


def door(d, cx, bottom, color=None):
    art.panel(d, (cx - 16, bottom - 46, cx + 16, bottom), P["deep"])
    d.rectangle((cx - 13, bottom - 43, cx + 13, bottom - 2), fill=color or P["teal"])
    for x in range(cx - 11, cx + 12, 6):
        d.line((x, bottom - 41, x, bottom - 3), fill=P["leaf_dark"])
        d.line((x + 1, bottom - 40, x + 1, bottom - 5), fill=P["sage"])
    d.rectangle((cx + 8, bottom - 19, cx + 10, bottom - 17), fill=P["gold"])
    d.line((cx - 20, bottom + 1, cx + 20, bottom + 1), fill=P["cream"], width=2)


def window(d, x, y, w=30, h=30, flowers=False):
    art.panel(d, (x, y, x + w, y + h), P["deep"])
    d.rectangle((x + 3, y + 3, x + w - 3, y + h - 3), fill=P["cream"])
    d.rectangle((x + 4, y + 4, x + w - 4, y + h // 2), fill="#b6c4b1")
    d.line((x + w // 2, y + 2, x + w // 2, y + h - 2), fill=P["wood"], width=2)
    d.line((x + 2, y + h // 2, x + w - 2, y + h // 2), fill=P["wood"], width=2)
    for xx in (x - 6, x + w + 3):
        art.panel(d, (xx, y + 4, xx + 3, y + h - 1), P["teal"], highlight=P["sage"])
    d.line((x - 2, y + h + 1, x + w + 2, y + h + 1), fill=P["gold"], width=3)
    if flowers:
        art.wood(d, (x - 2, y + h + 3, x + w + 2, y + h + 10))
        for px in range(x + 3, x + w, 7):
            d.line((px, y + h + 3, px, y + h - 2), fill=P["leaf"])
            d.rectangle((px - 2, y + h - 3, px + 2, y + h), fill=P["rose_light"])


def chimney(d, x, y, h=42):
    art.panel(d, (x, y, x + 17, y + h), P["stone"], highlight=P["stone_light"])
    for row, yy in enumerate(range(y + 5, y + h, 8)):
        d.line((x + 1, yy, x + 16, yy), fill=P["deep"])
        d.line((x + (6 if row % 2 else 12), yy - 5, x + (6 if row % 2 else 12), yy), fill=P["deep"])
    art.panel(d, (x - 3, y - 3, x + 20, y + 3), P["stone_light"])
    d.rectangle((x + 1, y - 2, x + 16, y), fill=P["deep"])


def paint(kind, size, style, colors):
    im = art.canvas(size)
    d = ImageDraw.Draw(im)
    w, h = size
    cx, bottom = w // 2, h - 5
    d.ellipse((12, h - 18, w - 13, h - 1), fill="#30282060")
    if style == "tower":
        wall(d, (cx - 55, 114, cx + 55, bottom), "plaster")
        roof(d, [(cx - 76, 128), (cx, 78), (cx + 76, 128), (cx + 72, 160), (cx - 72, 160)], colors)
        wall(d, (cx - 30, 33, cx + 30, 137), "plaster")
        roof(d, [(cx - 40, 45), (cx, 5), (cx + 40, 45), (cx + 36, 66), (cx - 36, 66)], colors)
        d.ellipse((cx - 21, 75, cx + 21, 117), fill=P["deep"])
        d.ellipse((cx - 18, 78, cx + 18, 114), fill=P["cream"], outline=P["gold"])
        for dx, dy in ((0, -14), (14, 0), (0, 14), (-14, 0)):
            d.rectangle((cx + dx - 1, 96 + dy - 1, cx + dx + 1, 96 + dy + 1), fill=P["bark"])
        d.line([(cx - 10, 90), (cx, 96), (cx + 1, 83)], fill=P["bark"], width=2)
        window(d, cx - 46, bottom - 57, 18, 29)
        window(d, cx + 28, bottom - 57, 18, 29)
    elif style == "aframe":
        wall(d, (cx - 66, bottom - 75, cx + 66, bottom))
        roof(d, [(cx - 88, bottom - 48), (cx, 10), (cx + 88, bottom - 48), (cx + 70, bottom - 43), (cx, 44), (cx - 70, bottom - 43)], colors)
        d.polygon([(cx - 61, bottom - 54), (cx, 49), (cx + 61, bottom - 54)], fill=P["wood_mid"], outline=P["deep"])
        for yy in range(84, bottom - 54, 8):
            half = int((yy - 49) * 0.56)
            d.line((cx - half, yy, cx + half, yy), fill=P["grain"])
        window(d, cx - 13, 104, 26, 24)
        window(d, cx - 53, bottom - 44, 22, 23, True)
        window(d, cx + 31, bottom - 44, 22, 23, True)
        chimney(d, cx + 49, 42)
    elif style == "gambrel":
        wall(d, (cx - 71, bottom - 83, cx + 71, bottom), "plaster")
        roof(d, [(cx - 86, 116), (cx - 62, 40), (cx - 34, 20), (cx + 36, 20), (cx + 62, 40), (cx + 86, 116)], colors)
        d.line((cx - 62, 40, cx + 62, 40), fill=colors[3], width=2)
        for dx in (-42, 20):
            wall(d, (cx + dx, 66, cx + dx + 26, 100))
            roof(d, [(cx + dx - 4, 76), (cx + dx + 13, 52), (cx + dx + 30, 76)], colors)
            window(d, cx + dx + 4, 78, 18, 18)
        window(d, cx - 59, bottom - 58, 30, 29, True)
        window(d, cx + 29, bottom - 58, 30, 29, True)
    elif style in ("twins", "showroom", "manor"):
        wall(d, (20, min(104, bottom - 98), w - 21, bottom), "plaster" if style != "showroom" else "timber")
        for left, right, top in ((10, cx + 5, 20), (cx - 5, w - 11, 35 if style == "showroom" else 20)):
            peak = (left + right) // 2
            roof(d, [(left, 113), (peak, top), (right, 113)], colors)
            window(d, peak - 12, 76, 24, 26)
        d.line((20, 115, w - 21, 115), fill=P["deep"], width=4)
        d.line((21, 116, w - 22, 116), fill=P["gold"])
        for xx in (cx - 27, cx + 27):
            d.line((xx, 116, xx, bottom), fill=P["wood"], width=3)
        if style == "manor":
            # Deep covered veranda with a separate low hip roof.
            roof(d, [(15, bottom - 62), (37, bottom - 83), (w - 38, bottom - 83), (w - 16, bottom - 62)], SLATE)
        for xx in (35, w - 68):
            window(d, xx, bottom - 57, 32, 30, style != "showroom")
        if style == "showroom":
            # Furniture displayed behind a broad shopfront.
            for xx in (37, w - 65):
                d.line((xx + 4, bottom - 42, xx + 4, bottom - 18), fill=P["wood"], width=3)
                d.line((xx + 4, bottom - 30, xx + 22, bottom - 30), fill=P["wood"], width=3)
                d.line((xx + 22, bottom - 30, xx + 22, bottom - 18), fill=P["wood"], width=3)
            art.wood(d, (30, bottom - 14, 69, bottom - 10))
            art.wood(d, (w - 70, bottom - 14, w - 31, bottom - 10))
        for xx in (25, w - 26):
            d.line((xx, bottom - 60, xx, bottom), fill=P["bark"], width=4)
    elif style == "greenhouse":
        wall(d, (20, bottom - 68, w - 21, bottom), "plaster")
        # A luminous glass roof, framed by dark metal rather than shingles.
        points = [(10, 102), (cx, 32), (w - 11, 102), (w - 15, 124), (14, 124)]
        d.polygon(points, fill="#89aaa1", outline=P["deep"])
        for xx in range(20, w - 15, 21):
            d.line((cx + (xx - cx) // 3, 54, xx, 122), fill="#c8dbbc", width=2)
            d.line((xx, 126, xx, bottom - 12), fill=P["teal"], width=3)
        d.line((10, 103, w - 11, 103), fill=P["teal"], width=3)
        d.line((14, 124, w - 15, 124), fill=P["bark"], width=4)
        for xx in (27, 50, 151, 176):
            art.pot(d, xx, bottom - 11, P["rose"], flowers=True)
        window(d, cx - 15, 76, 30, 21)
    elif style == "windmill":
        d.polygon([(cx - 44, bottom), (cx - 31, 83), (cx + 31, 83), (cx + 44, bottom)], fill="#c1b08e", outline=P["ink"])
        for yy in range(105, bottom - 4, 12):
            half = 31 + (yy - 83) // 14
            d.line((cx - half, yy, cx + half, yy), fill=P["stone"])
        roof(d, [(cx - 45, 89), (cx, 31), (cx + 45, 89)], colors)
        # Four sail frames are part of this building sprite and Y-sort together.
        for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            a = (cx + sx * 12, 107 + sy * 12)
            b = (cx + sx * 91, 107 + sy * 91)
            c = (b[0] - sx * 18, b[1] + sy * 10)
            e = (a[0] - sx * 6, a[1] + sy * 14)
            d.polygon([a, b, c, e], fill=P["linen"], outline=P["bark"])
            d.line((cx, 107, b[0], b[1]), fill=P["bark"], width=4)
            for k in range(25, 83, 12):
                d.line((cx + sx * k, 107 + sy * k, cx + sx * (k - 12), 107 + sy * (k + 12)), fill=P["wood"])
        d.ellipse((cx - 8, 99, cx + 8, 115), fill=P["wood"], outline=P["ink"])
        window(d, cx - 12, bottom - 102, 24, 25)
    elif style == "atelier":
        wall(d, (25, 84, w - 26, bottom), "plaster")
        roof(d, [(12, 90), (50, 18), (w - 16, 50), (w - 12, 105)], colors)
        chimney(d, w - 52, 28, 36)
        window(d, 39, 111, w - 79, 37)
        d.line((26, 154, w - 27, 154), fill=P["wood"], width=3)
        d.line((29, 157, 58, bottom - 12), fill=P["wood"], width=3)
        d.line((w - 30, 157, w - 59, bottom - 12), fill=P["wood"], width=3)
        d.line((cx - 19, 114, cx - 19, 145), fill=P["wood"], width=2)
        d.line((cx + 19, 114, cx + 19, 145), fill=P["wood"], width=2)
        art.pot(d, 41, bottom - 6, P["violet"], True)
        art.pot(d, w - 39, bottom - 6, P["teal"], True)
    else:
        # Wide low hips for the inn/bakery; a lean-to for the riverside house.
        wall(d, (20, bottom - 78, w - 21, bottom), "plaster" if style == "bakery" else "timber")
        if style == "boathouse":
            roof(d, [(10, 66), (w - 32, 21), (w - 11, 94), (10, 116)], colors)
            chimney(d, w - 56, 25, 36)
        else:
            roof(d, [(10, 109), (39, 35), (w - 40, 35), (w - 11, 109)], colors)
            d.line((39, 35, 10, 109), fill=colors[3], width=2)
            d.line((w - 40, 35, w - 11, 109), fill=colors[0], width=2)
            chimney(d, 44, 16, 48)
        for xx in (32, w - 67):
            window(d, xx, bottom - 56, 34, 28, style == "cottage")
        if style in ("restaurant", "bakery"):
            for xx in range(22, w - 25, 15):
                d.polygon([(xx, bottom - 72), (xx + 14, bottom - 72), (xx + 17, bottom - 56), (xx - 2, bottom - 56)], fill=P["linen"] if xx % 2 else P["rose"], outline=P["deep"])
            for xx in (24, w - 25):
                d.line((xx, bottom - 55, xx, bottom), fill=P["bark"], width=3)
            if style == "bakery":
                wall(d, (cx - 19, 61, cx + 19, 97), "plaster")
                roof(d, [(cx - 25, 71), (cx, 48), (cx + 25, 71)], TERRA)
                window(d, cx - 10, 75, 20, 20)
                for xx in (42, w - 55):
                    d.ellipse((xx, bottom - 39, xx + 11, bottom - 32), fill=P["gold"], outline=P["bark"])
        if style == "cottage":
            for yy in range(103, bottom - 12, 9):
                d.line((w - 26, yy, w - 22, yy + 8), fill=P["leaf_dark"], width=2)
                d.rectangle((w - 28, yy, w - 20, yy + 3), fill=P["leaf"])
        if style == "boathouse":
            # Oars and a rope coil communicate the waterfront silhouette.
            d.line((34, bottom - 3, 61, bottom - 59), fill=P["gold"], width=3)
            d.ellipse((52, bottom - 61, 63, bottom - 46), fill=P["wood_light"], outline=P["bark"])
            for off in (0, 3, 6):
                d.ellipse((w - 57 + off, bottom - 23 + off, w - 29 - off, bottom - off), outline=P["gold"])
    door(d, cx, bottom)
    # Pictorial plaques only: no baked lettering or operation instructions.
    if style in ("restaurant", "bakery", "twins", "showroom"):
        art.wood(d, (cx - 24, bottom - 61, cx + 24, bottom - 49))
        if style == "restaurant":
            d.pieslice((cx - 10, bottom - 60, cx + 10, bottom - 50), 0, 180, fill=P["cream"])
            d.line((cx - 6, bottom - 59, cx - 3, bottom - 63), fill=P["cream"])
        elif style == "bakery":
            d.ellipse((cx - 12, bottom - 59, cx + 12, bottom - 51), fill=P["gold"], outline=P["deep"])
            for dx in (-6, 0, 6): d.line((cx + dx, bottom - 58, cx + dx + 2, bottom - 54), fill=P["cream"])
        elif style == "twins":
            d.rectangle((cx - 11, bottom - 59, cx + 11, bottom - 52), fill=P["cream"], outline=P["deep"])
            d.line((cx, bottom - 59, cx, bottom - 52), fill=P["wood"])
        else:
            d.line([(cx - 8, bottom - 59), (cx - 8, bottom - 52), (cx + 8, bottom - 52), (cx + 8, bottom - 59)], fill=P["cream"], width=2)
    art.save(im, kind)
    ASSETS[kind + ".png"] = list(size)


def build():
    art.RNG.seed(10112026)
    for args in [
        ("shop_3", (224, 192), "restaurant", ROSE),
        ("shop_4", (192, 256), "tower", PLUM),
        ("shop_5", (224, 208), "showroom", TERRA),
        ("shop_6", (192, 208), "aframe", MOSS),
        ("shop_7", (192, 208), "gambrel", PLUM),
        ("shop_8", (192, 192), "boathouse", SLATE),
        ("town_greenhouse", (224, 192), "greenhouse", MOSS),
        ("town_atelier", (192, 224), "atelier", SLATE),
        ("town_bakery", (224, 192), "bakery", STRAW),
        ("town_library", (224, 224), "twins", SLATE),
        ("town_manor", (224, 240), "manor", ROSE),
        ("town_windmill", (224, 280), "windmill", TERRA),
        ("town_cottage", (192, 192), "cottage", MOSS),
        ("town_boathouse", (224, 176), "boathouse", TERRA),
    ]:
        paint(*args)
    return ASSETS


if __name__ == "__main__":
    build()
