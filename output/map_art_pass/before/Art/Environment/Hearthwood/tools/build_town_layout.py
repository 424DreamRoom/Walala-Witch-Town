"""Hearthwood town: a market square, crooked lanes, gardens and a river landing.

Native raster assets remain unchanged. This is the authoritative outdoor layout.
"""
import json
import random
from PIL import Image, ImageDraw, ImageFilter
import build_art as art
import build_town_architecture as architecture

OUT = art.OUT
P = art.P
SEED = 101020267
SIZE = (1600, 1536)  # Exactly twice the former 1280 x 960 area.
W, H = SIZE
BUILDINGS = [
    ("blacksmith_exterior", 1020, 530, "blacksmith", "余烬铁匠铺"),
    ("store_exterior", 620, 350, "store", "橡果杂货店"),
    ("shop_3", 570, 692, "restaurant", "小女巫餐厅"),
    ("shop_4", 948, 260, "civic", "北坡会馆"),
    ("shop_5", 200, 610, "furniture_store", "榛木家具店"),
    ("shop_6", 348, 866, "residence", "林荫住宅"),
    ("shop_7", 778, 818, "residence", "南巷住宅"),
    ("shop_8", 1090, 876, "residence", "河岸住宅"),
    ("town_greenhouse", 1308, 300, "landmark", "常青花房"),
    ("town_atelier", 1328, 550, "landmark", "蓝窗画室"),
    ("town_bakery", 205, 1128, "landmark", "麦香小屋"),
    ("town_library", 536, 1174, "landmark", "双山墙书屋"),
    ("town_manor", 1028, 1150, "residence", "玫瑰庭院"),
    ("town_windmill", 212, 1460, "landmark", "南风磨坊"),
    ("town_cottage", 758, 1450, "residence", "苔顶小屋"),
    ("town_boathouse", 1280, 1458, "residence", "芦苇河舍"),
]
GATES = {"field": [454, 10], "restaurant": [570, 718], "farm": [8, 364],
         "dock": [W - 8, 652], "blacksmith": [1020, 556], "store": [620, 376], "furniture_store": [200, 636]}


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
    road([(1118, 652), (W + 32, 652)], 42, "wood"),
    # East garden lane rejoins the old market road and the river promenade.
    road([(948, 292), (1148, 332), (1308, 340), (1308, 326)], 30, "dirt"),
    road([(1308, 340), (1450, 392), (1430, 576), (1328, 588), (1328, 576)], 32),
    road([(1328, 588), (1280, 652), (1268, 938), (1256, 1040)], 34),
    road([(1090, 920), (1180, 964), (1256, 1040), (1376, 1168), (1380, 1376), (1280, 1494), (1280, 1484)], 32, "dirt"),
    # A complete southern loop, with side approaches to every doorstep.
    road([(260, 900), (130, 974), (112, 1160), (205, 1168), (205, 1154)], 34, "dirt"),
    road([(205, 1168), (338, 1242), (536, 1216), (536, 1200)], 36),
    road([(778, 858), (792, 1002), (724, 1100), (726, 1194), (536, 1216)], 38),
    road([(726, 1194), (908, 1214), (1028, 1190), (1028, 1176)], 32),
    road([(1028, 1190), (1182, 1228), (1376, 1168)], 30, "dirt"),
    road([(205, 1168), (100, 1266), (94, 1488), (212, 1496), (212, 1486)], 32, "dirt"),
    road([(212, 1496), (466, 1480), (594, 1392), (758, 1488), (758, 1476)], 32, "dirt"),
    road([(536, 1216), (594, 1288), (594, 1392)], 28, "dirt"),
    road([(758, 1488), (990, 1458), (1100, 1376), (1280, 1494)], 34),
    road([(1028, 1190), (1100, 1278), (1100, 1376)], 30, "dirt"),
]
PLAZA = [[466, 416], [540, 380], [732, 386], [822, 435], [824, 498], [750, 552], [564, 555], [464, 506]]
BANK = [(0, 1550), (160, 1526), (280, 1544), (410, 1506), (540, 1524),
        (650, 1490), (780, 1524), (960, 1532), (1100, 1496), (1280, 1520), (H, 1464)]


def bank_x(y):
    for (y0, x0), (y1, x1) in zip(BANK, BANK[1:]):
        if y0 <= y <= y1:
            return round(x0 + (x1 - x0) * (y - y0) / (y1 - y0))
    return BANK[-1][1]


def path_mask(paths, surface):
    mask = Image.new("L", SIZE)
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
    # Individually spaced yards and trees in the additional eastern/southern land.
    for kind, x, y, w, h in [
        ("herbs", 1204, 332, 0, 0), ("flowerbed", 1396, 325, 0, 0),
        ("bench", 1210, 407, 50, 12), ("lamp", 1447, 353, 8, 6),
        ("bush", 1445, 489, 0, 0), ("flowerbed", 1414, 592, 0, 0),
        ("bench", 1380, 722, 50, 12), ("lamp", 1340, 686, 8, 6),
        ("barrel", 1394, 544, 22, 12), ("herbs", 1235, 545, 0, 0),
        ("mailbox", 304, 1151, 12, 6), ("crates", 102, 1119, 34, 12),
        ("flowerbed", 254, 1195, 0, 0), ("lamp", 330, 1209, 8, 6),
        ("bench", 445, 1211, 50, 12), ("herbs", 628, 1204, 0, 0),
        ("flowerbed", 466, 1253, 0, 0), ("lamp", 663, 1229, 8, 6),
        ("pond", 868, 1100, 64, 30), ("bench", 816, 1059, 50, 12),
        ("bush", 923, 1109, 0, 0), ("flowerbed", 1102, 1200, 0, 0),
        ("mailbox", 1155, 1174, 12, 6), ("fence", 1192, 1136, 60, 5),
        ("barrel", 279, 1455, 22, 12), ("crates", 311, 1474, 34, 12),
        ("bench", 406, 1426, 50, 12), ("flowerbed", 656, 1478, 0, 0),
        ("mailbox", 854, 1486, 12, 6), ("herbs", 818, 1418, 0, 0),
        ("pond", 889, 1358, 64, 30), ("bench", 945, 1313, 50, 12),
        ("lamp", 1034, 1432, 8, 6), ("barrel", 1385, 1458, 22, 12),
        ("crates", 1175, 1456, 34, 12), ("herbs", 1343, 1502, 0, 0),
        ("bench", 1317, 1094, 50, 12), ("flowerbed", 1323, 1229, 0, 0),
    ]:
        add(kind, x, y, w, h)
    for i, (x, y) in enumerate([
        (1200, 126), (1403, 181), (1439, 830), (1362, 938), (1238, 819),
        (76, 1008), (348, 999), (426, 1060), (685, 999), (1169, 1025),
        (354, 1293), (412, 1371), (57, 1432), (483, 1496), (674, 1287),
        (803, 1229), (975, 1274), (1159, 1338), (1416, 1286), (1436, 1430),
    ]):
        add("birch" if i % 3 else "pine", x, y, 10, 8)
    items.append(dict(kind="town_fountain", x=682, y=482, w=70, h=32, solid=True, outdoor_decoration=True))
    return items


def ground(layout):
    rng = random.Random(SEED)
    im = art.canvas(SIZE, "#6b805b")
    d = ImageDraw.Draw(im)
    # Broad meadows rather than repetitive square building plots.
    for box, color in [((26, 67, 383, 347), "#71845e"), ((742, 282, 1114, 456), "#667e59"),
                       ((464, 747, 750, 927), "#71845e"), ((54, 691, 239, 929), "#607951"),
                       ((1110, 100, 1460, 610), "#71845e"), ((55, 963, 718, 1508), "#748660"),
                       ((734, 988, 1196, 1460), "#647d55"), ((1152, 1240, 1460, 1520), "#71845e")]:
        d.ellipse(box, fill=color)
    for _ in range(29000):
        x, y = rng.randrange(W), rng.randrange(H)
        d.line((x, y, x + rng.randrange(1, 4), y), fill=rng.choice(["#627953", "#728760", "#7e9066", "#87956b"]))
    # Small irregular dirt aprons keep the garden sizes and silhouettes varied.
    for i, house in enumerate(layout["buildings"]):
        x, y = house["x"], house["y"]
        d.polygon([(x - 99, y - 117), (x - 82, y - 150), (x + 73, y - 144),
                   (x + 104, y - 100), (x + 110, y + 15), (x + 39, y + 35),
                   (x - 67, y + 29), (x - 111, y - 8)], fill="#8c805c" if i % 2 else "#938561")
    for surface in ("dirt", "stone", "wood"):
        mask = path_mask(layout["paths"], surface)
        texture = art.canvas(SIZE, "#b3a07b")
        t = ImageDraw.Draw(texture)
        if surface == "stone":
            for y in range(0, H, 10):
                for x in range(-8 if (y // 10) % 2 else 0, W, 17):
                    t.rectangle((x, y, x + 15, y + 8), fill=rng.choice(["#b6a481", "#bfae88", "#ae9d7c", "#c7b591", "#a9a184"]))
                    t.line((x + 1, y + 1, x + 14, y + 1), fill="#d0bd96")
                    t.line((x + 1, y + 8, x + 15, y + 8), fill="#958769")
        elif surface == "dirt":
            for _ in range(32000):
                x, y = rng.randrange(W), rng.randrange(H)
                t.line((x, y, x + 2, y), fill=rng.choice(["#c3af84", "#a9946c", "#baa67d"]))
        else:
            art.planks(texture, (1117, 631, W + 32, 673), 8, 49)
        # A thin worn verge, no large rectangular city-block outlines.
        verge = mask.filter(ImageFilter.MaxFilter(5))
        im.paste(Image.new("RGBA", im.size, "#8d8a63"), (0, 0), verge)
        im.paste(texture, (0, 0), mask)
    d = ImageDraw.Draw(im)
    bank = [(bank_x(y), y) for y in range(0, H + 1, 8)]
    d.polygon(bank + [(W, H), (W, 0)], fill="#525e4e")
    d.polygon([(x + 5, y) for x, y in bank] + [(W, H), (W, 0)], fill="#638b88")
    for _ in range(800):
        y = rng.randrange(H)
        x = rng.randrange(bank_x(y) + 8, W)
        d.line((x, y, min(W - 1, x + rng.randrange(4, 13)), y), fill=rng.choice(["#84aaa0", "#749d96", "#a3beb0"]))
    for y in range(631, 673, 8):
        art.wood(d, (1118, y, W + 32, min(y + 7, 673)))
    for x in (1120, 1488, W - 12):
        art.wood(d, (x, 622, x + 5, 633), vertical=True)
        art.wood(d, (x, 672, x + 5, 687), vertical=True)
    for house in layout["buildings"]:
        x, y = house["x"], house["y"]
        for yy in range(y + 2, y + 29, 8):
            d.rounded_rectangle((x - 16, yy, x + 16, yy + 5), radius=2, fill=P["stone_light"], outline=P["stone"])
    art.save(im, "town_ground")


def build():
    architecture.build()
    art.RNG.seed(SEED)
    fountain()
    barriers = []
    for y in range(0, H, 8):
        x = min(bank_x(y), bank_x(y + 8)) + 5
        if 624 <= y < 680:
            x = W
        if x < W:
            barriers.append([x, y, W - x, 8])
    layout = dict(size=list(SIZE), previous_size=[1280, 960], area_multiplier=2, spawn=[408, 364], revision=4,
                  buildings=[dict(kind=k, x=x, y=y, w=architecture.COLLISIONS.get(k, (160, 96))[0],
                                  h=architecture.COLLISIONS.get(k, (160, 96))[1], role=r, name=n) for k, x, y, r, n in BUILDINGS],
                  props=objects(), gates=GATES, paths=PATHS,
                  plazas=[dict(points=PLAZA, surface="stone")], barriers=barriers,
                  districts=[dict(name="西郊农场道", point=[58, 364]), dict(name="月泉广场", point=[620, 470]),
                             dict(name="余烬工坊", point=[1020, 556]), dict(name="南巷花园", point=[590, 840]),
                             dict(name="河岸渡口", point=[1480, 652]), dict(name="东园花径", point=[1308, 340]),
                             dict(name="南坡书街", point=[536, 1216]), dict(name="风车草甸", point=[466, 1480]),
                             dict(name="芦苇河畔", point=[1280, 1494])])
    ground(layout)
    (OUT / "town_layout.json").write_text(json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    art.compose(layout["buildings"] + layout["props"], "town_ground", "town_overview")
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest.setdefault("assets", {})["town_fountain.png"] = [96, 84]
    manifest["assets"].update(architecture.ASSETS)
    manifest["assets"].update({name + ".png": list(SIZE) for name in ("town_ground", "town_overview")})
    for name in ("outdoor_sign_dock.png",):
        with Image.open(OUT / name) as image:
            manifest["assets"][name] = list(image.size)
    manifest["town_plan"] = dict(revision=4, seed=SEED, districts=9, size=list(SIZE), area_multiplier=2,
                                 buildings=len(BUILDINGS), architecture="fourteen authored variants in ten structural families plus smithy and general store",
                                 roads="connected east garden lane and southern street loops around the original market square",
                                 rebuild="python Art/Environment/Hearthwood/tools/build_town_layout.py",
                                 references=["https://wiki.stardewvalley.net/Pelican_Town", "https://fieldsofmistria.grandwiki.com/map/"])
    manifest["outdoors"]["town_decorations"] = len(layout["props"])
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("TOWN PLAN BUILT", SIZE, "area x2;", len(layout["buildings"]), "buildings;", len(layout["props"]), "props;", len(PATHS), "lanes; nine districts")


if __name__ == "__main__":
    build()
