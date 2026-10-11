"""Deterministic dock art and collision layout; uses the existing Hearthwood palette."""
import json
import random

from PIL import ImageDraw

import build_art as base

P = base.P
OUT = base.OUT
RNG = random.Random(10102027)
BASE_WOOD_STATE = base.RNG.getstate()


def fish(d, x, y, color):
    d.polygon([(x - 6, y), (x - 3, y - 3), (x + 3, y - 3),
               (x + 6, y), (x + 3, y + 3), (x - 3, y + 3)], fill=color)
    d.polygon([(x + 5, y), (x + 10, y - 4), (x + 10, y + 4)], fill=color)
    d.point((x - 3, y - 1), fill=P["deep"])


def signs():
    image = base.canvas((56, 48))
    d = ImageDraw.Draw(image)
    base.wood(d, (25, 18, 30, 44), vertical=True)
    d.polygon([(3, 8), (42, 8), (53, 19), (42, 30), (3, 30)],
              fill=P["wood"], outline=P["deep"])
    d.line((5, 10, 41, 10), fill=P["gold"])
    d.line((5, 28, 41, 28), fill=P["bark"])
    fish(d, 22, 19, P["cream"])
    d.line([(38, 15), (43, 19), (38, 23)], fill=P["teal_light"], width=2)
    base.save(image, "outdoor_sign_dock")

    image = base.canvas((24, 34))
    d = ImageDraw.Draw(image)
    d.ellipse((4, 28, 22, 33), fill="#45302270")
    base.wood(d, (10, 12, 15, 31), vertical=True)
    base.panel(d, (1, 3, 22, 18), P["teal"], P["deep"], P["teal_light"])
    fish(d, 10, 11, P["cream"])
    d.point((3, 5), fill=P["gold"])
    d.point((20, 16), fill=P["gold"])
    base.save(image, "dock_fishing_post")

    image = base.canvas((16, 28))
    d = ImageDraw.Draw(image)
    d.ellipse((1, 22, 15, 27), fill="#45302270")
    base.wood(d, (5, 7, 11, 25), vertical=True)
    d.ellipse((4, 4, 12, 10), fill=P["wood_light"], outline=P["deep"])
    for y in (14, 17):
        d.line((4, y, 12, y), fill=P["linen"], width=2)
    base.save(image, "dock_mooring")


def boat():
    image = base.canvas((64, 92))
    d = ImageDraw.Draw(image)
    d.ellipse((9, 6, 58, 90), fill="#304c5060")
    hull = [(29, 2), (42, 9), (52, 27), (52, 63), (44, 80), (30, 88), (16, 78), (10, 60), (12, 26), (20, 10)]
    d.polygon(hull, fill=P["deep"], outline=P["ink"])
    d.polygon([(29, 5), (40, 13), (47, 28), (48, 61), (41, 77), (30, 83), (19, 75), (15, 60), (17, 27), (23, 12)], fill=P["wood_light"])
    d.polygon([(29, 13), (38, 21), (42, 31), (43, 59), (37, 72), (30, 78), (23, 70), (20, 58), (22, 30)], fill=P["bark"])
    for y in range(31, 65, 7):
        d.line((22, y, 41, y), fill=P["grain"])
    for y in (30, 60):
        base.wood(d, (16, y, 47, y + 5))
    d.line([(19, 72), (14, 58), (16, 28), (24, 11), (29, 7)], fill=P["gold"])
    d.line([(43, 75), (49, 59), (48, 28)], fill=P["wood"])
    d.line((5, 19, 57, 75), fill=P["deep"], width=3)
    d.line((5, 18, 57, 74), fill=P["wood_light"])
    d.polygon([(51, 67), (60, 72), (62, 80), (55, 79)], fill=P["gold"], outline=P["deep"])
    d.ellipse((26, 40, 38, 52), outline=P["linen"], width=2)
    d.line((32, 42, 32, 50), fill=P["linen"])
    base.save(image, "dock_boat")


def hut():
    image = base.canvas((112, 116))
    d = ImageDraw.Draw(image)
    d.ellipse((3, 100, 108, 115), fill="#29392f65")
    base.wood(d, (10, 46, 102, 105), vertical=True)
    base.shingle_roof(d, (2, 4, 109, 57), [P["leaf_dark"], P["teal"], P["leaf"], P["teal_light"]])
    base.panel(d, (13, 58, 99, 62), P["deep"], highlight=P["gold"])
    base.panel(d, (45, 71, 68, 105), P["deep"], highlight=P["wood_light"])
    base.wood(d, (49, 75, 64, 104), vertical=True)
    d.point((61, 89), fill=P["gold"])
    base.panel(d, (17, 72, 36, 90), P["deep"], highlight=P["wood_light"])
    d.rectangle((20, 75, 33, 86), fill=P["cream"])
    d.line((26, 75, 26, 87), fill=P["bark"])
    d.line((20, 81, 34, 81), fill=P["bark"])
    base.panel(d, (76, 70, 97, 87), P["teal"], highlight=P["teal_light"])
    fish(d, 84, 79, P["cream"])
    d.line((7, 106, 105, 106), fill=P["stone_light"], width=2)
    d.line((6, 109, 106, 109), fill=P["stone"], width=3)
    base.save(image, "dock_hut")


def ground():
    image = base.canvas((640, 360), "#527b7e")
    d = ImageDraw.Draw(image)
    for y in range(0, 360, 12):
        for x in range(192, 640, 16):
            xx = x + RNG.randrange(12)
            yy = y + RNG.randrange(10)
            d.line((xx, yy, xx + RNG.randrange(2, 8), yy), fill=RNG.choice(["#577f80", "#4d7579", "#5c8584"]))
    d.rectangle((0, 0, 183, 359), fill="#677853")
    for _ in range(1400):
        x, y = RNG.randrange(180), RNG.randrange(360)
        d.line((x, y, x + RNG.randrange(1, 4), y), fill=RNG.choice(["#78855b", "#5c714f", "#859164", "#697b55"]))
    d.rectangle((159, 0, 184, 359), fill="#aeab83")
    for _ in range(280):
        x, y = RNG.randrange(160, 185), RNG.randrange(360)
        d.point((x, y), fill=RNG.choice([P["sage"], P["cream"], P["stone"]]))
    for y in range(0, 360, 9):
        edge = 185 + RNG.randrange(6)
        d.rectangle((185, y, edge + 9, y + 7), fill="#70948b")
        d.line((edge, y, edge, y + 6), fill="#a3b5a0")
    d.rectangle((0, 222, 184, 253), fill="#b3a37b")
    d.polygon([(31, 360), (58, 360), (74, 260), (69, 239), (44, 239)], fill="#b3a37b")
    for _ in range(180):
        x, y = RNG.randrange(184), RNG.randrange(224, 253)
        d.point((x, y), fill=RNG.choice([P["linen"], "#a99a72"]))
    # Continue the town's 42px wooden causeway through the western crop edge.
    for y in range(217, 259, 8):
        base.wood(d, (-32, y, 190, min(y + 7, 259)))
    # Shadows and the visible front faces of the raised wooden pier.
    for box in ((176, 204, 335, 266), (328, 132, 531, 300)):
        x0, y0, x1, y1 = box
        d.rectangle((x0 + 3, y0 + 5, x1 + 4, y1 + 3), fill="#3d6265")
        d.rectangle(box, fill=P["bark"], outline=P["deep"])
    base.planks(image, (176, 204, 335, 259), height=8, width=56)
    base.planks(image, (328, 132, 523, 291), height=10, width=60)
    d = ImageDraw.Draw(image)
    for y in (132, 289):
        d.line((328, y, 523, y), fill=P["deep"], width=2)
        d.line((330, y + 2, 521, y + 2), fill=P["gold"])
    for x in (328, 521):
        d.line((x, 134, x, 289), fill=P["bark"], width=2)
    for y in (204, 258):
        d.line((177, y, 327, y), fill=P["bark"], width=2)
    # Nails, repaired boards and rope rings keep the deck readable at native scale.
    for y in range(137, 290, 20):
        for x in (334, 516):
            d.point((x, y), fill=P["deep"])
            d.point((x + 1, y + 1), fill=P["stone_light"])
    for x, y in ((246, 233), (368, 246), (471, 186)):
        d.ellipse((x, y, x + 5, y + 2), outline=P["grain"])
    for x, y in ((362, 149), (503, 270)):
        d.ellipse((x - 5, y - 3, x + 5, y + 3), outline=P["linen"], width=2)
    for y in (83, 124, 185, 285, 334):
        x = 167
        d.polygon([(x - 7, y), (x - 4, y - 4), (x + 3, y - 3), (x + 7, y + 2), (x, y + 5)], fill=P["stone"], outline=P["leaf_dark"])
        d.line((x - 3, y - 2, x + 2, y - 2), fill=P["stone_light"])
    for x, y in ((151, 206), (155, 318), (169, 63)):
        for dx in (-4, 0, 4):
            d.line((x, y, x + dx, y - 12 - abs(dx)), fill=P["leaf_dark"])
            d.line((x + 1, y, x + dx + 1, y - 9 - abs(dx)), fill=P["leaf_light"])
    base.save(image, "dock_ground")


def layout():
    props = []

    def prop(kind, x, y, w=0, h=0, solid=True, **extra):
        props.append(dict(kind=kind, x=x, y=y, w=w, h=h, solid=solid, **extra))

    prop("dock_hut", 92, 174, 92, 36)
    prop("outdoor_birch", 28, 111, 10, 8)
    prop("outdoor_birch", 146, 86, 10, 8)
    prop("outdoor_bush", 18, 188, solid=False)
    prop("outdoor_crates", 157, 177, 34, 12)
    prop("outdoor_barrel", 31, 210, 22, 12)
    prop("outdoor_lamp", 166, 210, 8, 6)
    prop("outdoor_bench", 112, 307, 50, 12)
    prop("outdoor_flowerbed", 87, 195, solid=False)
    prop("outdoor_sign_field", 47, 288, solid=False)
    prop("dock_boat", 588, 184, solid=False)
    prop("outdoor_barrel", 351, 190, 22, 12)
    prop("outdoor_crates", 474, 168, 34, 12)
    for x, y in ((334, 150), (516, 150), (334, 287), (516, 287), (214, 211), (283, 211), (214, 258), (283, 258)):
        prop("dock_mooring", x, y, 8, 6)
    for name, x, y, anchor, water in (
        ("north", 388, 150, [388, 174], [388, 102]),
        ("east", 516, 220, [492, 220], [567, 220]),
        ("south", 440, 284, [440, 260], [440, 330]),
    ):
        prop("dock_fishing_post", x, y, 12, 8, resource_id="dock_" + name,
             resource_type="fish", anchor=anchor, water=water)
    waves = []
    for y in range(66, 357, 25):
        for x in range(208, 630, 39):
            x, yy = x + RNG.randrange(12), y + RNG.randrange(12)
            if 166 < x < 342 and 192 < yy < 275 or 316 < x < 543 and 120 < yy < 312:
                continue
            waves.append([x, yy])
    data = dict(size=[640, 360], spawn=[42, 238], exit=[8, 238], props=props, waves=waves,
                paths=[dict(points=[[-32, 238], [190, 238]], width=42, surface="wood")],
                walls=[[0, 48, 184, 16], [-16, 48, 16, 312], [0, 310, 184, 50],
                       [184, 48, 144, 156], [184, 260, 144, 100],
                       [328, 48, 208, 84], [328, 292, 208, 68], [524, 48, 116, 312]])
    (OUT / "dock_layout.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    signs()
    boat()
    hut()
    ground()
    layout()
    base.RNG.setstate(BASE_WOOD_STATE)
    print("Built dock ground, fishing signs, hut, boat, mooring posts and layout.")
