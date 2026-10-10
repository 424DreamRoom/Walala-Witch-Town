"""Deterministic outdoor-only art pass, preserving indoor and character assets."""
import json
import random

from PIL import Image, ImageDraw

import build_art as base

OUT = base.OUT
P = base.P
SEED = 10102026
SIZES = {}


def asset(name, size, draw):
    image = base.canvas(size)
    draw(ImageDraw.Draw(image))
    base.save(image, name)
    SIZES[name + ".png"] = list(size)
    return image


def shadow(d, box):
    d.ellipse(box, fill="#29392f50")


def flower(d, x, y, color):
    d.line((x, y + 2, x, y + 6), fill=P["leaf_dark"])
    d.point((x + 1, y + 4), fill=P["leaf_light"])
    d.rectangle((x - 1, y - 1, x + 1, y + 1), fill=color)
    d.point((x, y), fill=P["cream"])


def foliage(d, cx, cy, radius, colors):
    offsets = [(-.55, -.1), (-.26, -.5), (.2, -.55), (.6, -.18), (.45, .34), (0, .4), (-.5, .3), (0, 0), (-.2, -.18), (.27, -.1)]
    d.polygon([(cx - radius, cy), (cx - radius + 5, cy - radius // 2), (cx, cy - radius), (cx + radius - 4, cy - radius // 2), (cx + radius, cy + 4), (cx + radius // 2, cy + radius // 2), (cx - radius // 2, cy + radius // 2)], fill=colors[0], outline=P["leaf_dark"])
    for i, (dx, dy) in enumerate(offsets):
        x, y = cx + int(dx * radius), cy + int(dy * radius)
        r = radius // 3 + i % 3
        d.polygon([(x - r, y), (x - r + 2, y - 4), (x + 1, y - 6), (x + r, y - 2), (x + r - 1, y + 3), (x - 2, y + 5)], fill=colors[1] if dy > 0 else colors[2])
        if i < 4:
            d.line((x - r + 3, y - 4, x, y - 5), fill=colors[3])
        for j in range(3):
            xx, yy = x - r + 3 + j * 3, y - 2 + (j + i) % 3
            d.line((xx, yy, xx + 2, yy), fill=colors[3] if dy < 0 else colors[2])
            d.point((xx + 1, yy + 1), fill=colors[1])


def props():
    def lamp(d):
        shadow(d, (7, 68, 28, 75))
        base.panel(d, (13, 29, 18, 70), P["bark"], P["deep"], P["wood_light"])
        d.line((16, 31, 16, 68), fill=P["gold"])
        d.polygon([(12, 68), (19, 68), (23, 73), (9, 73)], fill=P["stone"], outline=P["deep"])
        d.line([(16, 31), (16, 7), (18, 4), (24, 4), (26, 7), (26, 11)], fill=P["deep"], width=2)
        d.line([(16, 8), (19, 6), (23, 6)], fill=P["gold"])
        d.polygon([(21, 13), (25, 10), (30, 13), (29, 15), (22, 15)], fill=P["teal"], outline=P["deep"])
        base.panel(d, (22, 15, 29, 28), P["gold"], P["deep"])
        d.rectangle((24, 17, 27, 25), fill=P["cream"])
        d.line((25, 17, 25, 25), fill="#fff0c7")
        d.line((21, 29, 30, 29), fill=P["deep"])
        d.point((26, 31), fill=P["gold"])
    asset("outdoor_lamp", (32, 76), lamp)

    def bench(d):
        shadow(d, (4, 29, 60, 37))
        for x in (10, 50):
            base.wood(d, (x, 16, x + 3, 34), vertical=True)
        for y in (8, 14, 20):
            base.wood(d, (7, y, 56, y + 4))
        base.wood(d, (3, 24, 60, 29))
        d.line((6, 25, 57, 25), fill=P["gold"])
        for x in (4, 56):
            base.panel(d, (x, 20, x + 3, 29), P["teal"], highlight=P["teal_light"])
        base.panel(d, (15, 23, 33, 26), P["rose"], P["wine"], P["rose_light"])
        base.books(d, (40, 19, 51, 24), horizontal=True)
    asset("outdoor_bench", (64, 38), bench)

    def flowerbed(d):
        shadow(d, (2, 25, 61, 31))
        base.wood(d, (3, 20, 60, 28), vertical=True)
        base.panel(d, (2, 18, 61, 21), P["wood_light"], P["deep"], P["gold"])
        for i, x in enumerate(range(7, 59, 6)):
            d.line((x, 18, x - 2, 12), fill=P["leaf_dark"], width=2)
            d.line((x, 17, x + 3, 13), fill=P["leaf_light"])
            flower(d, x - 1, 9 + x % 3, [P["rose_light"], P["cream"], P["violet"], P["rose"]][i % 4])
    asset("outdoor_flowerbed", (64, 32), flowerbed)

    def fence(d):
        shadow(d, (0, 27, 63, 31))
        for y in (13, 22):
            base.panel(d, (1, y, 62, y + 3), P["sage"], P["leaf_dark"], P["linen"])
        for x in (3, 15, 27, 39, 51, 59):
            d.polygon([(x, 29), (x, 10), (x + 2, 7), (x + 4, 10), (x + 4, 29)], fill=P["linen"], outline=P["stone"])
            d.line((x + 1, 11, x + 1, 27), fill=P["cream"])
            d.point((x + 2, 16), fill=P["bark"])
    asset("outdoor_fence", (64, 32), fence)

    def mailbox(d):
        shadow(d, (7, 36, 26, 43))
        base.wood(d, (14, 22, 18, 40), vertical=True)
        d.polygon([(4, 13), (8, 9), (22, 9), (26, 13), (26, 26), (4, 26)], fill=P["teal"], outline=P["deep"])
        d.line((7, 12, 22, 12), fill=P["teal_light"])
        d.line((7, 16, 21, 16), fill=P["leaf_dark"])
        base.panel(d, (9, 20, 19, 24), P["cream"], P["stone"])
        d.line([(10, 21), (14, 23), (18, 21)], fill=P["rose"])
        d.line((25, 7, 25, 21), fill=P["deep"], width=2)
        d.rectangle((26, 7, 30, 11), fill=P["rose"])
        d.point((27, 8), fill=P["rose_light"])
    asset("outdoor_mailbox", (32, 44), mailbox)

    def well(d):
        shadow(d, (4, 56, 59, 67))
        d.ellipse((8, 39, 56, 65), fill=P["deep"])
        d.rectangle((8, 44, 56, 56), fill=P["stone"])
        d.ellipse((8, 46, 56, 65), fill=P["stone"], outline=P["deep"])
        for x in range(12, 55, 10):
            d.line((x, 53, x, 62), fill=P["deep"])
        d.ellipse((7, 36, 57, 54), fill=P["stone_light"], outline=P["deep"])
        d.ellipse((13, 40, 51, 50), fill=P["leaf_dark"], outline=P["stone"])
        d.line((14, 41, 43, 41), fill=P["cream"])
        for x in (13, 47):
            base.wood(d, (x, 15, x + 3, 46), vertical=True)
        d.line((17, 29, 47, 29), fill=P["bark"], width=3)
        d.line((31, 27, 31, 44), fill=P["gold"])
        d.line([(50, 26), (55, 26), (55, 34)], fill=P["deep"], width=2)
        d.polygon([(4, 20), (31, 5), (59, 20), (56, 24), (7, 24)], fill=P["wine"], outline=P["deep"])
        for y in (13, 17, 21):
            span = (y - 5) * 2
            d.line((31 - span, y, 31 + span, y), fill=P["rose"])
        d.line([(6, 19), (31, 7), (56, 19)], fill=P["rose_light"])
        base.panel(d, (40, 48, 48, 57), P["wood"], highlight=P["gold"])
        d.arc((40, 44, 48, 52), 180, 360, fill=P["deep"])
    asset("outdoor_well", (64, 68), well)

    def pond(d):
        d.polygon([(4, 22), (13, 10), (32, 5), (57, 7), (74, 19), (78, 33), (68, 46), (42, 52), (17, 47), (3, 35)], fill=P["leaf_dark"])
        d.polygon([(8, 23), (18, 13), (34, 10), (55, 12), (69, 20), (73, 31), (64, 40), (43, 45), (20, 41), (8, 32)], fill="#466c70", outline=P["stone"])
        d.polygon([(11, 23), (21, 16), (35, 13), (55, 16), (65, 23), (68, 31), (59, 37), (40, 41), (22, 36), (12, 29)], fill="#729e9a")
        d.line([(16, 24), (24, 19), (38, 18)], fill="#b1c9b5")
        d.line((41, 30, 55, 30), fill="#93bab0")
        d.line((23, 34, 32, 34), fill="#93bab0")
        for x, y in [(10, 19), (24, 8), (46, 7), (66, 13), (75, 30), (61, 46), (32, 49), (8, 40)]:
            d.polygon([(x - 4, y), (x - 2, y - 3), (x + 3, y - 3), (x + 5, y), (x + 3, y + 3), (x - 3, y + 3)], fill=P["stone"], outline=P["leaf_dark"])
            d.line((x - 1, y - 2, x + 2, y - 2), fill=P["stone_light"])
        d.ellipse((47, 22, 59, 28), fill=P["leaf"], outline=P["leaf_dark"])
        d.line((54, 24, 59, 22), fill="#729e9a")
        flower(d, 50, 21, P["rose_light"])
        for x in (6, 10, 70):
            d.line((x, 38, x - 2, 30), fill=P["leaf"])
            d.line((x + 2, 39, x + 3, 28), fill=P["leaf_light"])
    asset("outdoor_pond", (80, 54), pond)

    def barrel(d):
        shadow(d, (2, 30, 30, 37))
        d.polygon([(7, 7), (24, 7), (29, 14), (29, 27), (24, 34), (7, 34), (3, 27), (3, 14)], fill=P["wood"], outline=P["deep"])
        for x in (8, 14, 20, 25):
            d.line((x, 12, x, 30), fill=P["grain"])
            d.line((x + 1, 12, x + 1, 29), fill=P["wood_light"])
        for y in (15, 28):
            base.panel(d, (4, y, 28, y + 2), P["teal"], P["leaf_dark"], P["stone_light"])
        d.ellipse((5, 4, 26, 12), fill=P["wood_light"], outline=P["deep"])
        d.line((9, 8, 22, 8), fill=P["grain"])
    asset("outdoor_barrel", (32, 38), barrel)

    def crates(d):
        shadow(d, (3, 29, 44, 37))
        base.wood(d, (3, 18, 28, 34))
        d.line([(5, 32), (26, 21)], fill=P["gold"], width=2)
        base.wood(d, (19, 7, 44, 27), vertical=True)
        base.panel(d, (18, 6, 45, 11), P["wood_light"], highlight=P["gold"])
        for x, y in [(24, 7), (29, 5), (35, 7), (40, 5)]:
            d.ellipse((x - 3, y - 3, x + 3, y + 2), fill=P["rose"], outline=P["wine"])
            d.point((x - 1, y - 2), fill=P["rose_light"])
            d.line((x, y - 3, x + 1, y - 5), fill=P["leaf_dark"])
    asset("outdoor_crates", (48, 38), crates)

    def herbs(d):
        shadow(d, (2, 23, 45, 27))
        base.wood(d, (3, 18, 44, 25), vertical=True)
        d.line((2, 18, 45, 18), fill=P["gold"], width=2)
        for x in range(8, 42, 6):
            d.line((x, 18, x, 7), fill=P["leaf_dark"])
            for y in (9, 12, 15):
                d.line((x - 2, y - 2, x + 2, y), fill=P["leaf_light"])
            d.line((x, 5, x, 9), fill=P["violet"], width=2)
            d.point((x, 5), fill="#bea6bb")
    asset("outdoor_herbs", (48, 28), herbs)

    def bush(d):
        shadow(d, (2, 31, 46, 39))
        foliage(d, 24, 24, 21, [P["leaf_dark"], P["leaf"], P["leaf_light"], P["sage"]])
        for x, y in [(11, 19), (22, 10), (32, 18), (18, 29), (37, 29)]:
            flower(d, x, y, P["rose_light"])
    asset("outdoor_bush", (48, 40), bush)

    def fern(d):
        for x, y in [(3, 5), (6, 3), (10, 1), (15, 2), (19, 5), (22, 9)]:
            d.line([(12, 18), ((x + 12) // 2, 9), (x, y)], fill=P["leaf_dark"])
            for j in range(2, 8, 2):
                px, py = x + (12 - x) * j // 12, y + (18 - y) * j // 12
                d.line((px - 2, py + 1, px + 2, py - 1), fill=P["leaf_light"] if x < 12 else P["leaf"])
        d.line((12, 18, 11, 4), fill=P["sage"])
    asset("outdoor_fern", (24, 20), fern)

    def rock(d):
        shadow(d, (1, 17, 39, 23))
        d.polygon([(3, 17), (7, 7), (18, 3), (31, 5), (37, 14), (35, 20), (13, 22)], fill=P["stone"], outline=P["leaf_dark"])
        d.polygon([(7, 12), (10, 7), (19, 5), (29, 7), (25, 14), (14, 16)], fill=P["stone_light"])
        d.line([(28, 8), (30, 14), (25, 19)], fill="#747e70")
        d.line((11, 7, 17, 6), fill=P["linen"])
        d.line((5, 18, 12, 19), fill=P["leaf"])
    asset("outdoor_rock", (40, 24), rock)

    def log(d):
        shadow(d, (2, 23, 53, 29))
        d.polygon([(9, 10), (43, 5), (50, 10), (50, 22), (13, 27), (5, 22)], fill=P["bark"], outline=P["deep"])
        d.line((13, 12, 43, 8), fill=P["wood_light"], width=2)
        d.line((13, 18, 44, 14), fill=P["grain"])
        d.ellipse((3, 10, 18, 26), fill=P["gold"], outline=P["deep"])
        d.ellipse((6, 13, 15, 23), outline=P["wood"])
        d.point((10, 18), fill=P["wood"])
        d.line((27, 11, 34, 10), fill=P["leaf_light"], width=2)
        for x in (30, 35, 40):
            flower(d, x, 8, P["cream"])
    asset("outdoor_log", (56, 30), log)


def trees():
    def birch(d):
        shadow(d, (17, 94, 57, 103))
        d.polygon([(32, 45), (39, 45), (40, 95), (45, 101), (37, 98), (27, 102), (31, 91)], fill=P["stone_light"], outline=P["deep"])
        d.line([(34, 48), (34, 86), (31, 96)], fill=P["cream"], width=2)
        for y in (68, 78, 88):
            d.line((36, y, 39, y + 1), fill=P["bark"])
        d.line([(33, 72), (23, 58), (18, 52)], fill=P["stone_light"], width=3)
        d.line([(38, 62), (48, 49)], fill=P["stone_light"], width=3)
        foliage(d, 35, 34, 31, ["#476256", "#6b8a70", "#89a58a", "#b0bc96"])
        foliage(d, 19, 55, 16, ["#476256", "#6b8a70", "#89a58a", "#b0bc96"])
        foliage(d, 52, 46, 17, ["#476256", "#6b8a70", "#89a58a", "#b0bc96"])
    asset("outdoor_birch", (72, 104), birch)

    def pine(d):
        shadow(d, (13, 101, 54, 111))
        base.wood(d, (28, 74, 34, 108), vertical=True)
        d.line([(30, 105), (24, 110)], fill=P["bark"], width=2)
        d.line([(33, 103), (40, 109)], fill=P["bark"], width=2)
        for top, left, right, bottom in [(37, 2, 61, 90), (20, 7, 56, 69), (5, 16, 47, 46)]:
            d.polygon([(31, top), (right, bottom - 7), (right - 5, bottom), (42, bottom - 2), (35, bottom + 2), (24, bottom - 1), (left + 4, bottom), (left, bottom - 6)], fill="#3e5e53", outline=P["leaf_dark"])
            d.polygon([(30, top + 5), (left + 5, bottom - 6), (23, bottom - 8), (31, bottom - 15)], fill="#6f8b76")
            d.line([(left + 8, bottom - 10), (22, bottom - 15), (29, bottom - 18)], fill="#94a68b")
            d.line([(38, bottom - 11), (45, bottom - 8), (right - 6, bottom - 7)], fill="#587766")
            for x, y in [(25, bottom - 20), (19, bottom - 12), (34, bottom - 9), (38, bottom - 17)]:
                d.line((x, y, x + 3, y + 1), fill="#7f9a82")
    asset("outdoor_pine", (64, 112), pine)


def signs():
    for symbol in ("field", "restaurant", "home"):
        def draw(d, symbol=symbol):
            shadow(d, (6, 35, 22, 39))
            base.wood(d, (13, 14, 16, 37), vertical=True)
            d.polygon([(3, 7), (24, 7), (29, 15), (24, 23), (3, 23)], fill=P["wood"], outline=P["deep"])
            d.line((5, 8, 23, 8), fill=P["gold"])
            d.line((5, 21, 23, 21), fill=P["grain"])
            if symbol == "field":
                d.polygon([(10, 17), (12, 10), (19, 11), (17, 17)], fill=P["leaf_light"], outline=P["leaf_dark"])
                d.line((10, 19, 17, 12), fill=P["cream"])
            elif symbol == "restaurant":
                d.pieslice((9, 12, 22, 20), 0, 180, fill=P["cream"], outline=P["deep"])
                d.line((11, 12, 20, 12), fill=P["cream"])
                d.line((14, 9, 14, 11), fill=P["rose_light"])
                d.line((18, 8, 18, 10), fill=P["rose_light"])
            else:
                d.ellipse((10, 10, 19, 19), fill=P["cream"])
                d.ellipse((14, 9, 21, 16), fill=P["wood"])
                d.point((23, 12), fill=P["cream"])
        asset("outdoor_sign_" + symbol, (32, 40), draw)


def prop(kind, x, y, w=0, h=0):
    item = {"kind": "outdoor_" + kind, "x": x, "y": y, "w": w, "h": h, "solid": w > 0 and h > 0, "outdoor_decoration": True}
    return item


def town_objects(layout):
    objects = []
    for b in layout["buildings"]:
        x, y = b["x"], b["y"]
        objects.extend([prop("mailbox", x - 100, y + 14, 12, 6), prop("flowerbed", x + 57, y + 51), prop("bush", x - 96, y - 37)])
    for y in (340, 660):
        for x in (344, 744, 1144):
            objects.append(prop("lamp", x, y, 8, 6))
    objects.extend([
        prop("pond", 480, 281, 64, 30), prop("bench", 480, 202, 50, 12),
        prop("birch", 484, 133, 10, 8), prop("fence", 480, 307, 60, 5),
        prop("well", 1148, 279, 38, 20), prop("barrel", 1154, 322, 22, 12),
        prop("herbs", 481, 405), prop("flowerbed", 559, 422),
        prop("bench", 480, 478, 50, 12), prop("bush", 487, 520),
        prop("well", 480, 590, 38, 20), prop("fence", 480, 626, 60, 5),
        prop("crates", 1144, 536, 34, 12), prop("barrel", 1154, 591, 22, 12),
        prop("herbs", 875, 610), prop("bush", 882, 556),
        prop("pine", 880, 461, 10, 8), prop("birch", 482, 725, 10, 8),
        prop("bench", 480, 855, 50, 12), prop("herbs", 1148, 849),
        prop("crates", 1151, 901, 34, 12), prop("fence", 1147, 779, 60, 5),
        prop("fern", 103, 422), prop("fern", 871, 830),
    ])
    return objects


def field_objects():
    trees = [
        ("birch", 18, 97), ("pine", 107, 82), ("birch", 179, 78),
        ("pine", 263, 80), ("birch", 346, 83), ("pine", 413, 112),
        ("birch", 4, 208), ("pine", 423, 211),
        ("pine", 194, 323), ("birch", 350, 343),
    ]
    objects = [prop(kind, x, y, 10, 8) for kind, x, y in trees]
    for index in (1, 2, 3, 4, 5, 7):
        objects[index].update(resource_id="field_tree_" + str(index), resource_type="wood")
    objects += [prop("fern", x, y) for x, y in [(142, 163), (279, 152), (149, 232), (252, 284), (390, 288), (28, 248)]]
    objects += [prop("bush", 171, 115), prop("bush", 308, 183), prop("log", 177, 206, 42, 10)]
    for index, (x, y) in enumerate([(350, 168), (177, 145)]):
        node = prop("ore", x, y, 24, 10)
        node.update(resource_id="field_ore_" + str(index), resource_type="ore")
        objects.append(node)
    pond = prop("pond", 300, 238, 64, 44)
    pond.update(resource_id="field_pond", resource_type="fish")
    objects.append(pond)
    for kind, x, y in [("pond", 538, 258), ("pine", 482, 122), ("birch", 569, 111), ("pine", 636, 168), ("bush", 470, 204), ("birch", 617, 334), ("bush", 485, 339), ("log", 549, 304)]:
        objects.append(prop(kind, x, y))
    return objects


def harvest_assets():
    def ore(d):
        d.ellipse((4, 17, 35, 23), fill="#29392f50")
        d.polygon([(5, 19), (8, 9), (15, 3), (25, 4), (33, 10), (36, 19), (29, 23), (12, 23)], fill=P["stone"], outline=P["deep"])
        d.polygon([(9, 10), (15, 5), (23, 6), (18, 13), (8, 17)], fill=P["stone_light"])
        d.line((18, 13, 25, 6, 31, 11), fill=P["bark"])
        for x, y in [(14, 11), (25, 12), (20, 18)]:
            d.polygon([(x, y - 3), (x + 3, y - 1), (x + 2, y + 3), (x - 2, y + 2)], fill="#88b7b0", outline="#476e73")
            d.line((x, y - 2, x + 1, y), fill="#d3e1c7")
    asset("outdoor_ore", (40, 24), ore)

    def stump(d):
        d.ellipse((2, 10, 25, 17), fill="#29392f50")
        d.polygon([(7, 6), (21, 6), (22, 14), (18, 17), (8, 15)], fill=P["bark"], outline=P["deep"])
        d.ellipse((5, 2, 22, 10), fill=P["gold"], outline=P["deep"])
        d.ellipse((8, 4, 19, 8), outline=P["grain"])
        d.line((12, 5, 17, 6), fill=P["bark"])
        d.line((9, 10, 9, 14), fill=P["wood"])
    asset("harvest_stump", (28, 18), stump)

    def rubble(d):
        d.ellipse((2, 9, 37, 23), fill="#29392f50")
        for x, y, size in [(3, 15, 8), (14, 11, 10), (27, 14, 9), (20, 19, 6)]:
            d.polygon([(x, y), (x + 3, y - 4), (x + size, y - 2), (x + size - 1, y + 3), (x + 1, y + 3)], fill=P["stone"], outline=P["deep"])
            d.line((x + 3, y - 3, x + size - 2, y - 1), fill=P["stone_light"])
    asset("harvest_rubble", (40, 24), rubble)

    def fish(d):
        d.polygon([(1, 3), (4, 4), (7, 1), (12, 2), (15, 4), (13, 7), (7, 8), (4, 6), (1, 8)], fill="#93b8b1", outline="#476e73")
        d.line((7, 2, 11, 2), fill="#d3e1c7")
        d.point((12, 4), fill=P["deep"])
        d.line((7, 7, 11, 7), fill=P["cream"])
    asset("harvest_fish", (16, 10), fish)


def terrain(layout):
    base.RNG.seed(SEED)
    ground = base.town_ground(layout, grass_marks=22000)
    d = ImageDraw.Draw(ground)
    rng = random.Random(SEED + 31)
    for b in layout["buildings"]:
        x, y = b["x"], b["y"]
        for px, py in [(x - 99, y + 27), (x + 96, y + 39)]:
            d.polygon([(px - 20, py), (px - 12, py - 9), (px + 8, py - 10), (px + 22, py), (px + 13, py + 9), (px - 14, py + 9)], fill="#5e7752")
            for _ in range(15):
                xx, yy = px + rng.randint(-15, 15), py + rng.randint(-5, 5)
                d.line((xx, yy, xx + 2, yy - 2), fill=P["leaf_light"])
        for xx in (x - 23, x + 22):
            for yy in range(y + 11, y + 37, 7):
                d.rectangle((xx, yy, xx + 3, yy + 4), fill=P["stone"], outline=P["stone_light"])
    for x, y in [(505, 304), (487, 225), (1161, 299), (486, 501), (875, 650), (1164, 916)]:
        for offset in (0, 10, 20):
            d.polygon([(x - 7, y + offset), (x - 3, y + offset - 3), (x + 5, y + offset - 2), (x + 7, y + offset + 2), (x, y + offset + 4), (x - 6, y + offset + 3)], fill=P["stone_light"], outline=P["stone"])
    for _ in range(90):
        x, y = rng.randint(103, 1173), rng.randint(87, 869)
        if ground.getpixel((x, y))[:3] in [(107, 128, 91), (94, 119, 82)]:
            flower(d, x, y, rng.choice([P["cream"], P["rose_light"], P["violet"]]))
    base.save(ground, "town_ground")

    base.RNG.seed(SEED + 7)
    field = base.field(grass_marks=5500, include_trees=False)
    d = ImageDraw.Draw(field)
    d.rectangle((440, 64, 639, 359), fill="#4d6555")
    for _ in range(1600):
        x, y = rng.randint(442, 638), rng.randint(66, 359)
        d.line((x, y, x + 3, y), fill=rng.choice(["#556d59", "#617963", "#425d50"]))
    # A wooded ridge makes the eastern movement boundary visible in the scenery.
    for y in range(76, 360, 26):
        d.polygon([(433, y), (448, y - 6), (458, y + 8), (455, y + 22), (433, y + 28)], fill=P["bark"], outline=P["deep"])
        d.line((438, y + 1, 449, y - 2), fill=P["stone_light"])
        d.line((447, y + 8, 450, y + 16), fill=P["grain"])
    base.save(field, "field_background")


def build():
    props()
    harvest_assets()
    trees()
    signs()
    layout = json.loads((OUT / "town_layout.json").read_text(encoding="utf-8"))
    layout["props"] = [p for p in layout["props"] if not p.get("outdoor_decoration", False)] + town_objects(layout)
    terrain(layout)
    field_layout = {"size": [640, 360], "props": field_objects()}
    for name, data in [("town_layout", layout), ("field_layout", field_layout)]:
        (OUT / (name + ".json")).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    base.compose(layout["buildings"] + layout["props"], "town_ground", "town_overview")
    base.compose(field_layout["props"], "field_background", "field_overview")
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    manifest.setdefault("assets", {}).update(SIZES)
    manifest["assets"]["field_overview.png"] = [640, 360]
    manifest["outdoors"] = {"seed": SEED, "town_decorations": sum(p.get("outdoor_decoration", False) for p in layout["props"]), "field_objects": len(field_layout["props"]), "field_foreground": "independent Y-sorted sprites", "rebuild": "python Art/Environment/Hearthwood/tools/build_outdoors.py"}
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    import build_ambient
    build_ambient.build()
    print("OUTDOORS ART", len(SIZES), "new sprite types;", manifest["outdoors"]["town_decorations"], "town decorations;", len(field_layout["props"]), "field objects")


if __name__ == "__main__":
    build()
