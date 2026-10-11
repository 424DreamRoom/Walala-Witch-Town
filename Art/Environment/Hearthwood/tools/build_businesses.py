"""Original native-pixel blacksmith and general store; rebuildable Hearthwood art."""
import json
from PIL import Image, ImageDraw
import build_art as b

OUT = b.OUT
P = b.P
SIZES = {}
SLATE = ["#424c50", "#59676b", "#708080", "#99a39a"]
TERRA = ["#704939", "#965f49", "#ac7658", "#d1a27b"]


def asset(name, size, painter):
    im = b.canvas(size)
    painter(ImageDraw.Draw(im))
    b.save(im, name)
    SIZES[name + ".png"] = list(size)
    return im


def masonry(d, box, dark=False):
    x0, y0, x1, y1 = box
    palette = ["#5c625e", "#6c726a", "#7d8072", "#8d8f7c"] if dark else ["#92917e", "#a7a38c", "#b6ad94", "#9b9c87"]
    d.rectangle(box, fill=P["deep"])
    for row, y in enumerate(range(y0 + 1, y1, 9)):
        for col, x in enumerate(range(x0 - (10 if row % 2 else 0), x1, 21)):
            xx, end = max(x0 + 1, x), min(x + 18, x1 - 1)
            if end <= xx:
                continue
            d.rectangle((xx, y, end, min(y + 7, y1 - 1)), fill=palette[(row + col * 3) % len(palette)])
            d.line((xx + 1, y, end - 1, y), fill=palette[-1])
            d.point((end, min(y + 6, y1 - 1)), fill=P["stone"])


def anvil(d, x, y, scale=1):
    pts = [(-24, -17), (12, -17), (24, -13), (13, -8), (6, -8), (5, -1), (15, 3), (15, 7), (-13, 7), (-13, 3), (-4, -1), (-5, -8), (-19, -9), (-29, -15)]
    d.polygon([(x + a * scale, y + c * scale) for a, c in pts], fill=SLATE[0], outline=P["ink"])
    d.line((x - 23 * scale, y - 16 * scale, x + 11 * scale, y - 16 * scale), fill="#b0b6a8", width=scale)
    d.line((x - 16 * scale, y - 11 * scale, x + 9 * scale, y - 11 * scale), fill=SLATE[2], width=scale)
    d.line((x - 11 * scale, y + 4 * scale, x + 13 * scale, y + 4 * scale), fill=SLATE[2], width=scale)


def hammer(d, x, y, large=False):
    k = 2 if large else 1
    d.line((x, y, x + 6 * k, y + 11 * k), fill=P["deep"], width=3 * k)
    d.line((x, y, x + 6 * k, y + 11 * k), fill=P["wood_light"], width=k)
    d.polygon([(x - 6*k, y), (x + 2*k, y - 5*k), (x + 5*k, y), (x - 3*k, y + 5*k)], fill=SLATE[2], outline=P["ink"])
    d.line((x - 5*k, y, x + k, y - 4*k), fill=P["stone_light"], width=k)


def ingot(d, x, y):
    d.polygon([(x, y), (x + 4, y - 5), (x + 17, y - 5), (x + 21, y), (x + 18, y + 5), (x + 2, y + 5)], fill=SLATE[1], outline=P["ink"])
    d.polygon([(x + 4, y - 4), (x + 16, y - 4), (x + 18, y), (x + 3, y)], fill="#a4b4ae")
    d.line((x + 4, y - 4, x + 15, y - 4), fill="#d2d5bd")


def flame(d, x, y, frame=0):
    for dx, height in [(-10, 19), (-3, 29), (5, 23), (11, 14)]:
        top = y - height + [0, 3, -2, 1][(frame + dx) % 4]
        d.polygon([(x + dx - 5, y), (x + dx - 6, y - 9), (x + dx, top), (x + dx + 4, y - 10), (x + dx + 6, y)], fill="#bb5f3c")
        d.polygon([(x + dx - 3, y), (x + dx, top + 8), (x + dx + 3, y)], fill="#e6a15b")
        d.line((x + dx, y - 9, x + dx + 1, y - 1), fill="#f6ce83", width=2)


def exterior(kind):
    def paint(d):
        d.ellipse((13, 176, 179, 191), fill="#30282078")
        if kind == "blacksmith":
            masonry(d, (17, 97, 174, 189))
            b.shingle_roof(d, (9, 10, 182, 120), SLATE)
            masonry(d, (138, 5, 159, 69), True)
            b.panel(d, (135, 4, 162, 12), SLATE[1], highlight=P["stone_light"])
            d.rectangle((139, 5, 158, 8), fill=P["ink"])
            b.wood(d, (69, 125, 125, 139))
            anvil(d, 98, 140)
            # Open forge alcove distinguishes the workshop from the houses.
            d.rounded_rectangle((23, 140, 67, 177), radius=13, fill=P["ink"])
            d.rectangle((25, 159, 65, 176), fill="#633b2d")
            flame(d, 46, 174)
            for xx in range(28, 64, 7):
                d.line((xx, 158, xx, 179), fill=SLATE[0], width=2)
            b.panel(d, (22, 177, 68, 184), SLATE[1], highlight=SLATE[2])
            b.wood(d, (80, 145, 111, 187), vertical=True)
            d.line((82, 156, 109, 156), fill=SLATE[1], width=3)
            d.line((82, 177, 109, 177), fill=SLATE[1], width=3)
            d.rectangle((105, 167, 108, 170), fill=P["gold"])
            b.wood(d, (126, 151, 167, 179))
            hammer(d, 138, 155)
            d.line((155, 154, 155, 175), fill=P["gold"], width=2)
            d.line((150, 154, 159, 154), fill=SLATE[2], width=3)
            b.wood(d, (127, 179, 169, 188))
            ingot(d, 133, 179)
            d.line((76, 188, 116, 188), fill=P["stone_light"], width=2)
        else:
            for xx in range(17, 175, 17):
                b.wood(d, (xx, 98, min(xx + 16, 174), 187), vertical=True, shade=1)
            b.shingle_roof(d, (9, 7, 182, 112), TERRA)
            b.panel(d, (67, 49, 123, 88), P["deep"])
            b.shingle_roof(d, (62, 36, 128, 58), TERRA)
            b.arched_window(d, (81, 58, 109, 87), curtain=False)
            b.wood(d, (66, 113, 126, 127))
            # Acorn pictogram; all lettering is rendered by the game font.
            d.ellipse((91, 116, 101, 125), fill=P["gold"], outline=P["deep"])
            d.rectangle((89, 116, 103, 119), fill=P["leaf_dark"])
            d.line((96, 113, 98, 111), fill=P["cream"])
            for xx in (24, 126):
                b.panel(d, (xx, 146, xx + 40, 174), P["deep"])
                d.rectangle((xx + 2, 148, xx + 38, 171), fill=P["cream"])
                for bx, color in [(xx + 6, P["rose"]), (xx + 16, P["teal"]), (xx + 27, P["violet"])]:
                    b.bottle(d, bx, 155, color, 6, 13)
                d.line((xx + 20, 147, xx + 20, 172), fill=P["wood"], width=2)
                b.wood(d, (xx - 2, 174, xx + 42, 180))
            b.wood(d, (80, 140, 111, 187), vertical=True)
            d.rectangle((83, 144, 108, 159), fill=P["teal"], outline=P["deep"])
            d.line((95, 145, 95, 158), fill=P["gold"])
            d.rectangle((105, 171, 108, 173), fill=P["gold"])
            for xx in range(19, 174, 14):
                d.polygon([(xx, 129), (xx + 12, 129), (xx + 14, 146), (xx - 2, 146)], fill=P["leaf"] if (xx // 14) % 2 else P["linen"], outline=P["deep"])
                d.rectangle((xx - 1, 145, xx + 13, 149), fill=P["leaf_light"] if (xx // 14) % 2 else P["cream"])
            for xx in (20, 171):
                d.line((xx, 147, xx, 188), fill=P["bark"], width=3)
            b.wood(d, (25, 180, 60, 189))
            for xx in range(30, 58, 8):
                d.ellipse((xx, 176, xx + 5, 181), fill=P["red"], outline=P["deep"])
                d.point((xx + 2, 176), fill=P["rose_light"])
            b.pot(d, 149, 183, P["teal"], flowers=True)
            d.line((76, 188, 115, 188), fill=P["cream"], width=2)
    return asset(kind + "_exterior", (192, 192), paint)


def floor(kind):
    im = b.canvas((640, 480), "#251f20")
    b.planks(im, (57, 122, 582, 424), 12, 64)
    d = ImageDraw.Draw(im)
    if kind == "blacksmith":
        masonry(d, (57, 122, 378, 362), True)
        masonry(d, (48, 54, 591, 124), True)
        b.rug(d, (281, 367, 360, 440), P["red"], P["gold"])
        for x, y in [(121, 236), (174, 259), (260, 316), (327, 282)]:
            d.line((x, y, x + 6, y + 2), fill="#4b514c")
            d.point((x + 8, y + 2), fill=SLATE[2])
        b.arched_window(d, (401, 66, 463, 112), curtain=False)
        b.wood(d, (103, 66, 307, 77))
        for x in (121, 157, 208, 253, 281):
            d.line((x, 72, x, 99), fill=SLATE[0], width=3)
            d.arc((x - 4, 95, x + 4, 104), 0, 300, fill=P["gold"])
    else:
        for x in range(48, 592, 18):
            b.wood(d, (x, 54, x + 17, 124), vertical=True, shade=1)
        b.rug(d, (247, 296, 397, 402), P["leaf"], P["cream"])
        b.arched_window(d, (416, 62, 499, 117), curtain=True)
        b.wood(d, (247, 70, 355, 103))
        for x, color in [(263, P["rose"]), (283, P["gold"]), (303, P["violet"]), (327, P["teal"])]:
            b.bottle(d, x, 77, color, 8, 17)
        for x, y in [(508, 160), (528, 180), (548, 200)]:
            d.polygon([(x, y), (x + 25, y + 12), (x + 14, y + 33), (x - 11, y + 21)], fill="#c09a63")
            d.line((x, y + 3, x + 21, y + 14), fill=P["gold"])
    for box in [(47, 122, 58, 425), (581, 122, 592, 425), (48, 423, 261, 436), (378, 423, 591, 436)]:
        b.wood(d, box, vertical=box[2] - box[0] < 15)
    b.wood(d, (46, 48, 594, 56))
    for x in (60, 570):
        b.wood(d, (x, 53, x + 9, 425), vertical=True)
        for y in (62, 125, 413):
            d.rectangle((x, y, x + 9, y + 4), fill=SLATE[1])
            d.point((x + 2, y + 1), fill=P["gold"])
    for y in range(436, 477, 9):
        b.wood(d, (262, y, 377, y + 8))
        d.line((263, y, 376, y), fill=P["gold"])
    d.line((303, 453, 335, 453), fill=P["cream"], width=2)
    d.polygon([(314, 454), (324, 462), (334, 454)], fill=P["cream"])
    b.save(im, kind + "_ground")
    SIZES[kind + "_ground.png"] = [640, 480]


def furniture():
    def furnace(d):
        masonry(d, (20, 1, 91, 72), True)
        for y in (9, 34, 60):
            b.panel(d, (17, y, 94, y + 6), SLATE[0], highlight=SLATE[2])
        masonry(d, (5, 62, 106, 137), True)
        d.rounded_rectangle((22, 77, 89, 125), radius=22, fill=P["ink"])
        d.rectangle((23, 104, 88, 128), fill="#603c2f")
        flame(d, 55, 126)
        b.panel(d, (8, 128, 103, 139), SLATE[1], highlight=SLATE[2])
        for x in (28, 47, 66, 82):
            d.rectangle((x, 125, x + 6, 128), fill="#df9252")
    asset("smith_furnace", (112, 140), furnace)

    def workbench(d):
        for x in (9, 110):
            b.wood(d, (x, 48, x + 7, 77), vertical=True)
        b.wood(d, (6, 34, 119, 67), vertical=True)
        b.wood(d, (1, 21, 124, 45), shade=2)
        b.panel(d, (11, 49, 58, 62), P["wood"], highlight=P["gold"])
        b.panel(d, (65, 49, 112, 62), P["wood"], highlight=P["gold"])
        for x in (33, 87):
            d.rectangle((x, 53, x + 4, 55), fill=SLATE[0])
        ingot(d, 76, 29)
        hammer(d, 24, 27)
        d.line((53, 23, 54, 39), fill=P["gold"], width=2)
        b.panel(d, (53, 18, 69, 27), SLATE[0], highlight=SLATE[2])
        d.line((61, 9, 61, 18), fill=P["stone_light"], width=2)
    asset("smith_workbench", (126, 78), workbench)

    def rack(d):
        b.wood(d, (3, 10, 93, 60), vertical=True)
        for x in (18, 48, 78):
            d.line((x, 19, x, 54), fill=P["gold"], width=2)
        hammer(d, 17, 24, True)
        d.polygon([(43, 12), (46, 3), (50, 12), (50, 34), (43, 34)], fill=SLATE[2], outline=SLATE[0])
        d.line((39, 36, 54, 36), fill=P["gold"], width=3)
        d.line((47, 38, 47, 51), fill=P["red"], width=3)
        d.arc((65, 13, 91, 37), 195, 345, fill=SLATE[2], width=4)
        b.wood(d, (0, 59, 95, 63))
    asset("smith_rack", (96, 64), rack)

    def anvil_prop(d):
        b.wood(d, (15, 31, 57, 56), vertical=True)
        d.ellipse((15, 27, 57, 39), fill=P["wood_light"], outline=P["deep"])
        d.ellipse((21, 30, 51, 36), outline=P["grain"])
        anvil(d, 37, 27)
    asset("smith_anvil", (72, 58), anvil_prop)

    def tub(d):
        b.wood(d, (4, 12, 44, 36), vertical=True)
        d.ellipse((3, 3, 45, 21), fill=SLATE[0], outline=P["deep"])
        d.ellipse((6, 6, 42, 18), fill=P["teal"], outline=P["teal_light"])
        d.arc((12, 8, 29, 14), 15, 200, fill=P["cream"])
        d.line((4, 28, 44, 28), fill=SLATE[1], width=3)
    asset("smith_quench", (48, 40), tub)

    def ore_bin(d):
        b.wood(d, (3, 17, 72, 48), vertical=True)
        b.wood(d, (0, 13, 75, 21))
        for x, y in [(9, 17), (22, 15), (37, 19), (49, 13), (63, 19)]:
            d.polygon([(x - 6, y), (x - 3, y - 10), (x + 5, y - 11), (x + 8, y - 2), (x + 4, y + 4)], fill=SLATE[1], outline=SLATE[0])
            d.line((x - 2, y - 8, x + 4, y - 9), fill=SLATE[3])
        b.wood(d, (3, 25, 72, 48))
        d.line((3, 37, 72, 37), fill=SLATE[1], width=3)
    asset("smith_ore_bin", (76, 50), ore_bin)

    def bellows(d):
        for i in range(7):
            d.polygon([(4 + i * 3, 12), (9 + i * 3, 8), (35 + i, 29), (29 + i, 34)], fill=P["wine"] if i % 2 else P["red"], outline=P["deep"])
        d.line((5, 12, 37, 34), fill=P["wood_light"], width=3)
        d.line((5, 3, 39, 26), fill=P["wood_light"], width=3)
        d.polygon([(2, 4), (13, 10), (6, 15), (0, 10)], fill=SLATE[2], outline=P["ink"])
        b.wood(d, (30, 33, 47, 45), vertical=True)
    asset("smith_bellows", (50, 46), bellows)

    def shelves(d):
        b.wood(d, (4, 3, 107, 96), vertical=True)
        for y in (26, 55, 84):
            for i, x in enumerate(range(12, 100, 14)):
                b.bottle(d, x, y - 17, [P["rose"], P["teal"], P["gold"], P["violet"]][(i + y) % 4], 8, 15)
            b.wood(d, (0, y, 111, y + 7), shade=2)
        for x in (8, 60):
            b.panel(d, (x, 95, x + 43, 115), P["wood"], highlight=P["gold"])
            d.rectangle((x + 18, 102, x + 22, 104), fill=P["deep"])
        b.wood(d, (0, 116, 111, 121))
    asset("store_shelves", (112, 122), shelves)

    def dry_shelves(d):
        b.wood(d, (4, 1, 107, 106), vertical=True)
        for y in (34, 70):
            for x in range(14, 97, 20):
                d.rounded_rectangle((x, y - 25, x + 13, y - 2), radius=4, fill=P["linen"], outline=P["deep"])
                d.line((x + 3, y - 22, x + 10, y - 22), fill=P["bark"], width=2)
                d.rectangle((x + 3, y - 15, x + 10, y - 8), fill=P["leaf"] if x % 3 else P["red"])
            b.wood(d, (0, y, 111, y + 7), shade=2)
        b.books(d, (12, 80, 100, 105))
        b.wood(d, (0, 106, 111, 113))
    asset("store_dry_shelves", (112, 114), dry_shelves)

    def counter(d):
        b.wood(d, (5, 29, 158, 69), vertical=True)
        b.wood(d, (0, 18, 163, 39), shade=2)
        for x in (12, 63, 114):
            b.panel(d, (x, 43, x + 36, 63), P["wood_mid"], highlight=P["gold"])
            d.rectangle((x + 4, 47, x + 32, 59), outline=P["grain"])
        b.books(d, (14, 17, 42, 26), horizontal=True)
        b.panel(d, (64, 15, 91, 28), P["cream"], highlight=P["linen"])
        d.line((77, 17, 77, 27), fill=P["wood"])
        for y in (19, 22, 25):
            d.line((67, y, 74, y), fill=P["grain"])
        b.panel(d, (118, 12, 142, 29), P["teal"], highlight=P["teal_light"])
        d.ellipse((121, 6, 139, 18), fill=P["gold"], outline=P["deep"])
        d.line((130, 2, 130, 7), fill=P["cream"], width=2)
        d.rectangle((126, 23, 135, 25), fill=P["deep"])
    asset("store_counter", (164, 72), counter)

    def produce(d):
        b.wood(d, (3, 18, 86, 52), vertical=True)
        b.wood(d, (0, 8, 89, 27), shade=2)
        for i, x in enumerate((4, 33, 62)):
            b.panel(d, (x, 10, x + 23, 25), P["deep"], highlight=P["gold"])
            for dx, dy in ((5, 7), (13, 6), (9, 14), (18, 15)):
                if i == 0:
                    d.rectangle((x + dx, dy + 4, x + dx + 2, dy + 9), fill=P["cream"])
                    d.ellipse((x + dx - 2, dy, x + dx + 4, dy + 5), fill=P["wood_light"], outline=P["deep"])
                elif i == 1:
                    d.ellipse((x + dx - 1, dy + 2, x + dx + 4, dy + 7), fill=P["wine"])
                    d.point((x + dx, dy + 3), fill=P["rose_light"])
                else:
                    d.line((x + dx, dy + 8, x + dx + 2, dy), fill=P["leaf_dark"])
                    d.rectangle((x + dx - 1, dy + 2, x + dx + 3, dy + 4), fill=P["leaf_light"])
        b.wood(d, (7, 30, 82, 47))
        for x in (15, 42, 68):
            d.rectangle((x, 35, x + 8, 41), fill=P["cream"])
    asset("store_produce", (90, 54), produce)

    def sacks(d):
        for x, y in ((4, 0), (37, 10), (17, 20)):
            d.rounded_rectangle((x, y + 4, x + 29, y + 35), radius=8, fill=P["linen"], outline=P["deep"])
            d.line((x + 6, y + 7, x + 23, y + 7), fill=P["wood"], width=2)
            d.arc((x + 8, y + 10, x + 21, y + 27), 0, 300, fill=P["wood_light"])
            d.line((x + 3, y + 27, x + 7, y + 31), fill=P["gold"])
    asset("store_sacks", (70, 58), sacks)


def build():
    b.RNG.seed(101020264)
    furniture()
    for kind in ("blacksmith", "store"):
        def sign(d, business=kind):
            b.wood(d, (14, 18, 18, 42), vertical=True)
            b.wood(d, (2, 2, 31, 25))
            if business == "blacksmith":
                d.polygon([(6, 9), (24, 9), (28, 12), (20, 15), (18, 18), (23, 21), (10, 21), (14, 17), (12, 14), (7, 13)], fill=P["stone_light"], outline=SLATE[0])
            else:
                d.ellipse((11, 10, 22, 22), fill=P["gold"], outline=P["deep"])
                d.rectangle((9, 8, 24, 12), fill=P["leaf"])
                d.line((16, 8, 19, 5), fill=P["cream"])
        asset(kind + "_sign", (34, 44), sign)
    walls = [[48, 48, 544, 78], [48, 126, 12, 298], [580, 126, 12, 298], [48, 424, 214, 12], [378, 424, 214, 12], [250, 436, 12, 44], [378, 436, 12, 44], [250, 476, 140, 8]]
    specs = {
        "blacksmith": [
            ("smith_furnace", 144, 222, 102, 52), ("smith_rack", 305, 179, 94, 18),
            ("smith_bellows", 225, 224, 44, 27), ("smith_workbench", 469, 224, 120, 42),
            ("smith_anvil", 294, 310, 56, 26), ("smith_quench", 395, 310, 44, 25),
            ("smith_ore_bin", 137, 331, 72, 30),
        ],
        "store": [
            ("store_shelves", 145, 215, 108, 34), ("store_dry_shelves", 291, 205, 108, 30),
            ("store_shelves", 490, 218, 108, 34), ("store_counter", 352, 285, 158, 36),
            ("store_sacks", 129, 329, 64, 37), ("store_produce", 490, 355, 84, 32),
        ],
    }
    for kind, items in specs.items():
        exterior(kind)
        floor(kind)
        layout = {"size": [640, 480], "spawn": [320, 405], "exit": [320, 449], "walls": walls,
                  "service": [294, 335] if kind == "blacksmith" else [352, 314],
                  "furniture": [dict(kind=n, x=x, y=y, w=w, h=h) for n, x, y, w, h in items]}
        (OUT / (kind + "_layout.json")).write_text(json.dumps(layout, indent=2) + "\n", encoding="utf-8")
        b.compose(layout["furniture"], kind + "_ground", kind + "_overview")
        SIZES[kind + "_overview.png"] = [640, 480]
    # Four frames only change the fire in the furnace opening.
    sheet = b.canvas((112 * 4, 140))
    original = Image.open(OUT / "smith_furnace.png").convert("RGBA")
    for i in range(4):
        frame = original.copy()
        d = ImageDraw.Draw(frame)
        d.rectangle((34, 94, 77, 127), fill="#603c2f")
        flame(d, 55, 126, i)
        sheet.alpha_composite(frame, (112 * i, 0))
    b.save(sheet, "smith_fire")
    SIZES["smith_fire.png"] = [448, 140]
    layout_path = OUT / "town_layout.json"
    town = json.loads(layout_path.read_text(encoding="utf-8"))
    for index, kind in ((1, "blacksmith"), (2, "store")):
        town["buildings"][index].update(kind=kind + "_exterior", role=kind)
    layout_path.write_text(json.dumps(town, indent=2) + "\n", encoding="utf-8")
    b.compose(town["buildings"] + town["props"], "town_ground", "town_overview")
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest.setdefault("assets", {}).update(SIZES)
    manifest["businesses"] = {"seed": 101020264, "buildings": ["blacksmith", "store"], "rebuild": "python Art/Environment/Hearthwood/tools/build_businesses.py"}
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("BUSINESS ART", len(SIZES), "native pixel PNGs; two enterable 640x480 interiors")


if __name__ == "__main__":
    build()
