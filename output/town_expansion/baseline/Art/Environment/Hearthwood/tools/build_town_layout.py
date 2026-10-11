"""Hearthwood town: a market square, crooked lanes, gardens and a river landing.

Native raster assets remain unchanged. This is the authoritative outdoor layout.
"""
import json
import random
from PIL import Image, ImageDraw, ImageFilter
import build_art as art

OUT = art.OUT
P = art.P
SEED = 101020267
BUILDINGS = [
    ("blacksmith_exterior", 1020, 530, "blacksmith", "余烬铁匠铺"),
    ("store_exterior", 620, 350, "store", "橡果杂货店"),
    ("shop_3", 570, 692, "restaurant", "小女巫餐厅"),
    ("shop_4", 948, 260, "civic", "北坡会馆"),
    ("shop_5", 200, 610, "furniture_store", "榛木家具店"),
    ("shop_6", 348, 866, "residence", "林荫住宅"),
    ("shop_7", 778, 818, "residence", "南巷住宅"),
    ("shop_8", 1090, 876, "residence", "河岸住宅"),
]
GATES = {"field": [454, 10], "restaurant": [570, 718], "farm": [8, 364],
         "dock": [1272, 652], "blacksmith": [1020, 556], "store": [620, 376], "furniture_store": [200, 636]}


def road(points, width, surface="stone"):
    return dict(points=[list(p) for p in points], width=width, surface=surface)


PATHS = [
    # Cross-map roads continue beyond the canvas, so the crop never forms a cap.
    road([(-32, 364), (224, 364), (408, 364), (468, 410), (520, 464), (620, 470)], 52),
    road([(408, 364), (408, 280), (426, 224), (420, 100), (454, 24), (454, -32)], 34, "dirt"),
    road([(224, 260), (224, 364)], 30, "dirt"),
    road([(620, 376), (620, 430)], 40),
    road([(620, 470), (756, 530), (854, 582), (968, 610), (1118, 652)], 48),
    road([(968, 610), (1020, 610), (1020, 556)], 32),
    road([(780, 420), (820, 342), (848, 292), (948, 292), (948, 286)], 36),
    road([(620, 376), (708, 376), (784, 294), (848, 292)], 28, "dirt"),
    road([(520, 464), (420, 540), (410, 610), (440, 730), (570, 730), (570, 718)], 42),
    road([(224, 364), (146, 426), (80, 500), (80, 646), (200, 646), (200, 636)], 30, "dirt"),
    road([(200, 646), (252, 668), (320, 706), (440, 730)], 32, "dirt"),
    road([(320, 706), (260, 750), (260, 900), (348, 904), (348, 892)], 30, "dirt"),
    road([(854, 582), (904, 702), (884, 858), (778, 858), (778, 844)], 34),
    road([(1118, 652), (1080, 734), (1140, 840), (1140, 920), (1090, 920), (1090, 902)], 28, "dirt"),
    road([(440, 730), (486, 796), (574, 874), (700, 884), (778, 858)], 28, "dirt"),
    road([(1118, 652), (1312, 652)], 42, "wood"),
]
PLAZA = [[466, 416], [540, 380], [732, 386], [822, 435], [824, 498], [750, 552], [564, 555], [464, 506]]
BANK = [(0, 1230), (160, 1206), (280, 1224), (410, 1166), (540, 1184), (650, 1150), (780, 1184), (960, 1212)]


def bank_x(y):
    for (y0, x0), (y1, x1) in zip(BANK, BANK[1:]):
        if y0 <= y <= y1:
            return round(x0 + (x1 - x0) * (y - y0) / (y1 - y0))
    return BANK[-1][1]


def path_mask(paths, surface):
    mask = Image.new("L", (1280, 960))
    d = ImageDraw.Draw(mask)
    for item in paths:
        if item["surface"] != surface:
            continue
        points = [tuple(p) for p in item["points"]]
        width = item["width"]
        d.line(points, fill=255, width=width, joint="curve")
        for x, y in points:
            radius = width // 2
            d.ellipse((x - radius, y - radius, x + radius, y + radius), fill=255)
    if surface == "stone":
        d.polygon([tuple(p) for p in PLAZA], fill=255)
        d.rounded_rectangle((468, 696, 672, 756), radius=18, fill=255)
    return mask


def fountain():
    im = art.canvas((96, 84))
    d = ImageDraw.Draw(im)
    d.ellipse((4, 61, 91, 83), fill="#29392f50")
    d.ellipse((7, 34, 89, 78), fill=P["deep"])
    d.ellipse((8, 30, 88, 72), fill=P["stone"], outline=P["deep"])
    for x in range(15, 86, 13):
        d.line((x, 56, x, 68), fill=P["deep"])
    d.ellipse((6, 26, 90, 64), fill=P["stone_light"], outline=P["deep"])
    d.ellipse((13, 31, 83, 57), fill="#5f8986", outline=P["stone"])
    d.arc((19, 36, 76, 51), 5, 174, fill="#b2c9af", width=2)
    art.panel(d, (39, 25, 56, 48), P["stone"], highlight=P["stone_light"])
    d.ellipse((29, 17, 66, 34), fill=P["stone_light"], outline=P["deep"])
    d.ellipse((33, 19, 62, 29), fill="#729e9a", outline=P["stone"])
    d.line((47, 8, 47, 23), fill=P["cream"], width=2)
    d.arc((39, 1, 56, 20), 50, 310, fill=P["gold"], width=3)
    for x, y in ((34, 38), (61, 39), (46, 51)):
        d.line((x, y, x + 9, y), fill="#a6c1b0")
    art.save(im, "town_fountain")


def objects():
    items = []

    def add(kind, x, y, w=0, h=0):
        items.append(dict(kind="outdoor_" + kind, x=x, y=y, w=w, h=h, solid=w > 0, outdoor_decoration=True))

    # Each garden is composed individually, without repeated street furniture rows.
    for args in [("mailbox", 124, 302, 12, 6), ("flowerbed", 281, 339), ("bush", 128, 251),
                 ("fence", 147, 351, 60, 5), ("bench", 323, 326, 50, 12),
                 ("herbs", 166, 328), ("lamp", 346, 350, 8, 6),
                 ("flowerbed", 700, 399), ("crates", 710, 363, 34, 12),
                 ("herbs", 531, 373), ("lamp", 750, 394, 8, 6),
                 ("crates", 1118, 557, 34, 12), ("barrel", 1115, 510, 22, 12),
                 ("bush", 909, 487), ("lamp", 1099, 599, 8, 6),
                 ("flowerbed", 864, 294), ("bench", 1047, 286, 50, 12),
                 ("mailbox", 1042, 327, 12, 6), ("fence", 1078, 318, 60, 5),
                 ("mailbox", 102, 636, 12, 6), ("herbs", 282, 640),
                 ("flowerbed", 168, 666), ("fence", 286, 562, 60, 5),
                 ("mailbox", 248, 888, 12, 6), ("flowerbed", 411, 900),
                 ("bench", 440, 851, 50, 12), ("herbs", 282, 852),
                 ("mailbox", 677, 832, 12, 6), ("flowerbed", 823, 876),
                 ("fence", 879, 798, 60, 5), ("bush", 684, 775),
                 ("barrel", 1181, 895, 22, 12), ("crates", 989, 898, 34, 12),
                 ("herbs", 1168, 857),
                 # Plaza edges stay clear through the middle, around the fountain.
                 ("bench", 564, 409, 50, 12), ("bench", 771, 479, 50, 12),
                 ("flowerbed", 596, 548), ("flowerbed", 778, 425),
                 ("lamp", 478, 491, 8, 6), ("lamp", 808, 537, 8, 6),
                 ("pond", 870, 413, 64, 30), ("bench", 920, 377, 50, 12),
                 ("herbs", 813, 384), ("bush", 924, 424),
                 # Restaurant courtyard and a park on the inside of the south loop.
                 ("flowerbed", 652, 752), ("lamp", 466, 757, 8, 6),
                 ("barrel", 674, 700, 22, 12), ("bench", 503, 748, 50, 12),
                 ("pond", 638, 848, 64, 30), ("bench", 590, 814, 50, 12),
                 ("bush", 552, 853), ("flowerbed", 696, 895)]:
        add(*args)
    for kind, x, y in [
        ("birch", 89, 154), ("pine", 116, 110), ("birch", 350, 149),
        ("pine", 368, 204), ("pine", 500, 131), ("birch", 754, 168),
        ("birch", 824, 219), ("pine", 1107, 146), ("birch", 1138, 279),
        ("pine", 351, 463), ("birch", 316, 528), ("pine", 371, 573),
        ("birch", 841, 466), ("pine", 1122, 431), ("birch", 1109, 749),
        ("pine", 112, 764), ("birch", 164, 835), ("pine", 204, 918),
        ("birch", 462, 939), ("pine", 595, 958), ("birch", 942, 901),
        ("pine", 954, 745), ("birch", 962, 686), ("birch", 715, 690),
    ]:
        add(kind, x, y, 10, 8)
    for x, y in [(53, 237), (61, 417), (58, 696), (402, 94), (788, 105), (1097, 75), (1174, 777)]:
        add("bush", x, y)
    items.append(dict(kind="town_fountain", x=682, y=482, w=70, h=32, solid=True, outdoor_decoration=True))
    return items


def ground(layout):
    rng = random.Random(SEED)
    im = art.canvas((1280, 960), "#6b805b")
    d = ImageDraw.Draw(im)
    # Broad meadows rather than repetitive square building plots.
    for box, color in [((26, 67, 383, 347), "#71845e"), ((742, 282, 1114, 456), "#667e59"),
                       ((464, 747, 750, 927), "#71845e"), ((54, 691, 239, 929), "#607951")]:
        d.ellipse(box, fill=color)
    for _ in range(14500):
        x, y = rng.randrange(1280), rng.randrange(960)
        d.line((x, y, x + rng.randrange(1, 4), y), fill=rng.choice(["#627953", "#728760", "#7e9066", "#87956b"]))
    # Small irregular dirt aprons keep the garden sizes and silhouettes varied.
    for i, house in enumerate(layout["buildings"]):
        x, y = house["x"], house["y"]
        d.polygon([(x - 99, y - 117), (x - 82, y - 150), (x + 73, y - 144),
                   (x + 104, y - 100), (x + 110, y + 15), (x + 39, y + 35),
                   (x - 67, y + 29), (x - 111, y - 8)], fill="#8c805c" if i % 2 else "#938561")
    for surface in ("dirt", "stone", "wood"):
        mask = path_mask(layout["paths"], surface)
        texture = art.canvas((1280, 960), "#b3a07b")
        t = ImageDraw.Draw(texture)
        if surface == "stone":
            for y in range(0, 960, 10):
                for x in range(-8 if (y // 10) % 2 else 0, 1280, 17):
                    t.rectangle((x, y, x + 15, y + 8), fill=rng.choice(["#b6a481", "#bfae88", "#ae9d7c", "#c7b591", "#a9a184"]))
                    t.line((x + 1, y + 1, x + 14, y + 1), fill="#d0bd96")
                    t.line((x + 1, y + 8, x + 15, y + 8), fill="#958769")
        elif surface == "dirt":
            for _ in range(16000):
                x, y = rng.randrange(1280), rng.randrange(960)
                t.line((x, y, x + 2, y), fill=rng.choice(["#c3af84", "#a9946c", "#baa67d"]))
        else:
            art.planks(texture, (1117, 631, 1312, 673), 8, 49)
        # A thin worn verge, no large rectangular city-block outlines.
        verge = mask.filter(ImageFilter.MaxFilter(5))
        im.paste(Image.new("RGBA", im.size, "#8d8a63"), (0, 0), verge)
        im.paste(texture, (0, 0), mask)
    d = ImageDraw.Draw(im)
    bank = [(bank_x(y), y) for y in range(0, 961, 8)]
    d.polygon(bank + [(1280, 960), (1280, 0)], fill="#525e4e")
    d.polygon([(x + 5, y) for x, y in bank] + [(1280, 960), (1280, 0)], fill="#638b88")
    for _ in range(500):
        y = rng.randrange(960)
        x = rng.randrange(bank_x(y) + 8, 1280)
        d.line((x, y, min(1279, x + rng.randrange(4, 13)), y), fill=rng.choice(["#84aaa0", "#749d96", "#a3beb0"]))
    for y in range(631, 673, 8):
        art.wood(d, (1118, y, 1312, min(y + 7, 673)))
    for x in (1120, 1268):
        art.wood(d, (x, 622, x + 5, 633), vertical=True)
        art.wood(d, (x, 672, x + 5, 687), vertical=True)
    for house in layout["buildings"]:
        x, y = house["x"], house["y"]
        for yy in range(y + 2, y + 29, 8):
            d.rounded_rectangle((x - 16, yy, x + 16, yy + 5), radius=2, fill=P["stone_light"], outline=P["stone"])
    art.save(im, "town_ground")


def build():
    art.RNG.seed(SEED)
    fountain()
    barriers = []
    for y in range(0, 960, 8):
        x = min(bank_x(y), bank_x(y + 8)) + 5
        if 624 <= y < 680:
            x = 1280
        if x < 1280:
            barriers.append([x, y, 1280 - x, 8])
    layout = dict(size=[1280, 960], spawn=[408, 364], revision=3,
                  buildings=[dict(kind=k, x=x, y=y, w=160, h=96, role=r, name=n) for k, x, y, r, n in BUILDINGS],
                  props=objects(), gates=GATES, paths=PATHS,
                  plazas=[dict(points=PLAZA, surface="stone")], barriers=barriers,
                  districts=[dict(name="西郊农场道", point=[58, 364]), dict(name="月泉广场", point=[620, 470]),
                             dict(name="余烬工坊", point=[1020, 556]), dict(name="南巷花园", point=[590, 840]),
                             dict(name="河岸渡口", point=[1144, 652])])
    ground(layout)
    (OUT / "town_layout.json").write_text(json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    art.compose(layout["buildings"] + layout["props"], "town_ground", "town_overview")
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest.setdefault("assets", {})["town_fountain.png"] = [96, 84]
    for name in ("outdoor_sign_dock.png",):
        with Image.open(OUT / name) as image:
            manifest["assets"][name] = list(image.size)
    manifest["town_plan"] = dict(revision=3, seed=SEED, districts=5, roads="variable-width branching lanes around an irregular public square",
                                 rebuild="python Art/Environment/Hearthwood/tools/build_town_layout.py",
                                 references=["https://wiki.stardewvalley.net/Pelican_Town", "https://fieldsofmistria.grandwiki.com/map/"])
    manifest["outdoors"]["town_decorations"] = len(layout["props"])
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("TOWN PLAN BUILT", len(layout["buildings"]), "buildings;", len(layout["props"]), "props;", len(PATHS), "lanes; five districts")


if __name__ == "__main__":
    build()
