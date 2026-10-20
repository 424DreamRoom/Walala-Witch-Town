"""Build original SVG construction assets outside the protected MyArt directory."""
import csv
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "Art/Building/icons"
WORLD = ROOT / "Art/Building/objects"
# Stable ID | Chinese | English | Japanese | Traditional Chinese | category |
# wood,iron,ore | footprint | area | silhouette
SOURCE = """stool|木凳|Wooden Stool|木のスツール|木凳|seating|2,0,0|18,10|both|stool
table|圆木桌|Round Table|丸い木のテーブル|圓木桌|tables|6,0,0|76,36|both|round_table
bookcase|魔女书柜|Witch Bookcase|魔女の本棚|魔女書櫃|storage|10,1,0|104,46|home|bookcase
sofa|软垫沙发|Cushioned Sofa|クッションソファ|軟墊沙發|seating|8,1,0|88,38|home|sofa
desk|书写桌|Writing Desk|書き物机|書寫桌|tables|6,1,0|80,30|home|desk
bed|星纹小床|Star Bed|星模様のベッド|星紋小床|beds|12,2,0|82,70|home|star_bed
chest|木箱|Wooden Chest|木箱|木箱|storage|8,0,0|40,20|both|chest
workbench|建造工作台|Construction Workbench|建築作業台|建造工作臺|workshop|16,2,0|48,24|both|workbench
picket_fence|尖顶木栅栏|Picket Fence|杭の柵|尖頂木柵欄|fences|3,0,0|32,12|farm|picket
log_fence|原木栅栏|Log Fence|丸太の柵|原木柵欄|fences|4,0,0|32,12|farm|logs
lattice_fence|格纹栅栏|Lattice Fence|格子の柵|格紋柵欄|fences|4,0,0|32,12|farm|lattice
stone_wall|矮石墙|Low Stone Wall|低い石壁|矮石牆|fences|0,0,5|32,16|farm|wall
iron_fence|铁艺栅栏|Iron Fence|鉄の柵|鐵藝柵欄|fences|0,3,0|32,12|farm|iron_fence
hedge|常绿树篱|Evergreen Hedge|常緑の生け垣|常綠樹籬|fences|2,0,1|32,20|farm|hedge
wood_gate|木栅门|Wooden Gate|木の門|木柵門|fences|6,1,0|32,12|farm|wood_gate
iron_gate|铁栅门|Iron Gate|鉄の門|鐵柵門|fences|2,4,0|32,12|farm|iron_gate
wood_path|木板小径|Plank Path|板張りの小道|木板小徑|paths|2,0,0|32,32|farm|planks
stone_path|石板小径|Flagstone Path|敷石の小道|石板小徑|paths|0,0,2|32,32|farm|flagstones
brick_path|红砖小径|Brick Path|レンガの小道|紅磚小徑|paths|0,0,3|32,32|farm|bricks
gravel_path|碎石小径|Gravel Path|砂利の小道|碎石小徑|paths|0,0,1|32,32|farm|gravel
moss_path|苔石小径|Mossy Path|苔むした小道|苔石小徑|paths|1,0,2|32,32|farm|moss
stepping_stones|圆石步道|Stepping Stones|飛び石|圓石步道|paths|0,0,2|32,32|farm|stepping
single_bed|原木单人床|Log Single Bed|丸太のシングルベッド|原木單人床|beds|14,0,0|32,48|home|single_bed
double_bed|花布双人床|Floral Double Bed|花柄のダブルベッド|花布雙人床|beds|24,2,0|64,48|home|double_bed
canopy_bed|帷幔床|Canopy Bed|天蓋付きベッド|帷幔床|beds|30,3,0|64,48|home|canopy_bed
hammock|月牙吊床|Crescent Hammock|三日月のハンモック|月牙吊床|beds|12,1,0|64,24|farm|hammock
chair|木质靠背椅|Wooden Chair|木の椅子|木質靠背椅|seating|4,0,0|24,20|both|chair
armchair|绒布扶手椅|Velvet Armchair|ベルベットの肘掛け椅子|絨布扶手椅|seating|8,1,0|32,28|home|armchair
bench|长木凳|Wooden Bench|長い木のベンチ|長木凳|seating|6,0,0|48,20|both|bench
rocking_chair|摇椅|Rocking Chair|ロッキングチェア|搖椅|seating|10,1,0|32,28|both|rocker
garden_bench|花园长椅|Garden Bench|庭のベンチ|花園長椅|seating|8,2,0|64,24|farm|garden_bench
square_table|方木桌|Square Table|四角い木のテーブル|方木桌|tables|8,0,0|32,28|both|square_table
long_table|长餐桌|Dining Table|長い食卓|長餐桌|tables|16,1,0|64,32|home|long_table
tea_table|茶几|Tea Table|ローテーブル|茶几|tables|6,0,0|48,24|home|tea_table
picnic_table|野餐桌|Picnic Table|ピクニックテーブル|野餐桌|tables|18,2,0|64,40|farm|picnic
wardrobe|双门衣柜|Wardrobe|両開きの洋服ダンス|雙門衣櫃|storage|20,2,0|48,24|home|wardrobe
cupboard|餐具柜|Kitchen Cupboard|食器棚|餐具櫃|storage|16,2,0|48,24|home|cupboard
low_shelf|矮书架|Low Bookshelf|低い本棚|矮書架|storage|8,0,0|48,20|both|low_shelf
wall_shelf|陈列架|Display Shelf|飾り棚|陳列架|storage|10,1,0|32,20|home|display_shelf
barrel|橡木桶|Oak Barrel|オークの樽|橡木桶|storage|6,1,0|24,24|both|barrel
candle|烛台|Candle Stand|燭台|燭臺|lighting|1,1,0|16,12|both|candle
lantern|提灯|Lantern|ランタン|提燈|lighting|2,2,0|20,16|both|lantern
floor_lamp|落地灯|Floor Lamp|フロアランプ|落地燈|lighting|6,2,0|20,16|home|floor_lamp
street_lamp|庭院灯柱|Garden Lamp Post|庭の街灯|庭院燈柱|lighting|8,3,0|20,16|farm|street_lamp
mushroom_lamp|蘑菇灯|Mushroom Lamp|キノコのランプ|蘑菇燈|lighting|4,1,2|24,20|both|mushroom_lamp
crystal_lamp|水晶灯|Crystal Lamp|水晶のランプ|水晶燈|lighting|0,2,6|24,20|both|crystal
oval_rug|椭圆地毯|Oval Rug|楕円のラグ|橢圓地毯|decor|4,0,0|48,32|home|oval_rug
round_rug|圆形地毯|Round Rug|丸いラグ|圓形地毯|decor|4,0,0|32,32|home|round_rug
star_rug|星月地毯|Star and Moon Rug|星と月のラグ|星月地毯|decor|6,0,0|48,32|home|star_rug
mirror|穿衣镜|Standing Mirror|姿見|穿衣鏡|decor|6,1,3|24,16|home|mirror
clock|座钟|Mantel Clock|置き時計|座鐘|decor|4,2,0|24,16|home|clock
painting|风景画架|Landscape Easel|風景画のイーゼル|風景畫架|decor|6,0,0|32,20|both|painting
globe|星球仪|Celestial Globe|天球儀|星球儀|decor|4,2,2|24,20|home|globe
vase|陶瓷花瓶|Ceramic Vase|陶器の花瓶|陶瓷花瓶|decor|0,0,4|20,16|both|vase
aquarium|小鱼缸|Small Aquarium|小さな水槽|小魚缸|decor|4,2,4|48,24|home|aquarium
music_box|八音盒|Music Box|オルゴール|八音盒|decor|4,3,0|20,16|home|music_box
flower_box|花槽|Flower Box|フラワーボックス|花槽|garden|6,0,1|48,20|farm|flower_box
clay_planter|陶土花盆|Clay Planter|素焼きの植木鉢|陶土花盆|garden|0,0,3|24,20|both|clay_planter
herb_planter|香草盆|Herb Planter|ハーブの鉢|香草盆|garden|4,0,2|32,24|both|herb_planter
rose_arch|蔷薇拱门|Rose Arch|バラのアーチ|薔薇拱門|garden|16,2,0|64,20|farm|rose_arch
birdbath|鸟浴盆|Birdbath|小鳥の水浴び台|鳥浴盆|garden|0,1,8|32,24|farm|birdbath
scarecrow|稻草人|Scarecrow|かかし|稻草人|garden|8,0,0|24,16|farm|scarecrow
well|石井|Stone Well|石の井戸|石井|garden|10,2,12|48,40|farm|well
sundial|日晷|Sundial|日時計|日晷|garden|0,1,6|24,20|farm|sundial
loom|织布架|Weaving Frame|織り機|織布架|workshop|14,2,0|48,28|both|loom
spinning_wheel|纺车|Spinning Wheel|糸車|紡車|workshop|12,1,0|40,24|both|spinning
kiln|陶窑|Pottery Kiln|陶芸窯|陶窯|workshop|4,4,16|48,40|farm|kiln
cauldron|魔女坩埚|Witch Cauldron|魔女の大釜|魔女坩堝|workshop|4,6,4|40,32|both|cauldron
piano|钢琴|Piano|ピアノ|鋼琴|workshop|28,4,0|88,42|home|piano"""
CATEGORIES = [
    ("all", "全部", "All", "すべて", "全部"),
    ("fences", "围栏", "Fences", "柵", "圍欄"),
    ("paths", "地面", "Paths", "床材", "地面"),
    ("beds", "床铺", "Beds", "ベッド", "床鋪"),
    ("seating", "座椅", "Seating", "椅子", "座椅"),
    ("tables", "桌台", "Tables", "テーブル", "桌臺"),
    ("storage", "柜架", "Cabinets", "棚", "櫃架"),
    ("lighting", "灯具", "Lighting", "照明", "燈具"),
    ("decor", "装饰", "Decor", "装飾", "裝飾"),
    ("garden", "庭院", "Garden", "庭", "庭院"),
    ("workshop", "工坊", "Workshop", "工房", "工坊"),
]


def records():
    result = []
    for line in SOURCE.splitlines():
        ident, cn, en, ja, tw, category, cost, size, area, shape = line.split("|")
        result.append(dict(id=ident, names=[cn, en, ja, tw], category=category,
                           cost=list(map(int, cost.split(","))), size=list(map(int, size.split(","))),
                           area=area, shape=shape, solid=category != "paths" and not shape.endswith("rug")))
    return result


# Small original rectilinear silhouettes with the game's warm wood, ink and sage palette.
def svg(shape, category, width=48, height=48):
    ink, wood, light, dark, cream, sage, rose, iron = "#493b3c", "#a87551", "#d6a46b", "#77543e", "#f0ddb1", "#839b65", "#bf8195", "#75818b"
    parts = []

    def r(x, y, w, h, fill, outline=True):
        parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}"' + (f' stroke="{ink}" stroke-width="1.5"' if outline else '') + '/>')

    def p(points, fill, outline=True):
        parts.append(f'<polygon points="{points}" fill="{fill}"' + (f' stroke="{ink}" stroke-width="1.5"' if outline else '') + '/>')

    def e(x, y, rx, ry, fill):
        parts.append(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{ink}" stroke-width="1.5"/>')

    def line(x1, y1, x2, y2, color=ink, stroke=2):
        parts.append(f'<path d="M{x1} {y1}L{x2} {y2}" stroke="{color}" stroke-width="{stroke}" fill="none"/>')

    def star(x, y):
        p(f'{x},{y-4} {x+2},{y-1} {x+5},{y} {x+2},{y+2} {x},{y+5} {x-2},{y+2} {x-5},{y} {x-2},{y-1}', cream, False)

    def legs(y=29, left=10, right=36):
        r(left, y, 4, 42-y, dark); r(right, y, 4, 42-y, dark)

    def flowers():
        for x, y in [(14, 22), (24, 18), (34, 22)]:
            line(x, y, x, 33, sage); e(x, y, 4, 3, rose); r(x-1, y-1, 2, 2, cream, False)

    if shape in ["picket", "logs", "lattice", "iron_fence", "wood_gate", "iron_gate"]:
        metal = shape.startswith("iron")
        color = iron if metal else wood
        r(4, 25, 40, 4, color); r(4, 36, 40, 4, color)
        for x in ([5, 20, 35] if shape == "logs" else [5, 13, 21, 29, 37]):
            r(x, 14, 5, 30, color)
            if shape in ["picket", "iron_fence"]: p(f'{x},14 {x+2.5},8 {x+5},14', light if not metal else iron)
        if shape == "lattice":
            for x in [5, 17, 29]: line(x, 16, x+12, 39, light); line(x+12, 16, x, 39, light)
        if shape.endswith("gate"):
            line(9, 38, 38, 17, cream if metal else light, 3); r(32, 28, 3, 3, cream)
    elif shape in ["wall", "bricks", "flagstones", "gravel", "moss", "stepping", "planks"]:
        base = "#b77d63" if shape == "bricks" else "#92968c"
        if shape == "planks":
            for y in [8, 17, 26, 35]:
                r(4, y, 40, 8, wood); line(9, y+4, 25, y+4, light, 1)
        elif shape in ["stepping", "gravel"]:
            for x, y, rx, ry in ([(14, 15, 9, 6), (32, 26, 10, 7), (16, 38, 8, 5)] if shape == "stepping" else [(8+(i*11)%34, 10+(i*13)%32, 3, 2) for i in range(15)]): e(x, y, rx, ry, base)
        else:
            for row in range(3 if shape == "wall" else 4):
                for col in range(3): r(4+col*14+(row%2)*2, 12+row*8 if shape == "wall" else 7+row*9, 12, 7, base if col%2 else "#b4b09d")
            if shape == "moss":
                for x, y in [(6, 12), (31, 23), (16, 36)]: r(x, y, 9, 3, sage, False)
    elif shape == "hedge":
        r(5, 32, 38, 10, dark)
        for x in [11, 24, 37]: e(x, 27, 10, 13, sage); r(x-3, 20, 5, 3, "#adc088", False)
    elif "bed" in shape:
        wide = shape in ["double_bed", "canopy_bed", "star_bed"]
        x, w = (6, 36) if wide else (12, 24)
        r(x, 9, w, 32, wood); r(x+3, 13, w-6, 25, rose if shape != "single_bed" else sage)
        r(x+5, 14, 11 if wide else 14, 7, cream)
        if wide: r(x+20, 14, 11, 7, cream)
        r(x-1, 38, 4, 6, dark); r(x+w-3, 38, 4, 6, dark)
        if shape == "canopy_bed":
            r(4, 5, 3, 38, dark); r(41, 5, 3, 38, dark); r(3, 4, 42, 4, wood); p('7,8 16,8 8,29', cream); p('40,8 31,8 40,29', cream)
        elif shape == "star_bed": star(24, 29)
        elif shape == "double_bed":
            for x1 in [16, 31]: e(x1, 29, 3, 3, cream)
    elif shape == "hammock":
        r(4, 10, 4, 34, wood); r(40, 10, 4, 34, wood); p('8,18 24,26 40,18 34,36 17,38', sage); line(12, 24, 35, 29, cream)
    elif shape in ["stool", "chair", "armchair", "bench", "rocker", "garden_bench", "sofa"]:
        wide = shape in ["bench", "garden_bench", "sofa"]
        left, right = (5, 39) if wide else (12, 32)
        legs(31, left, right)
        if shape not in ["stool", "bench"]:
            r(left, 13, right-left+4, 18, rose if shape in ["armchair", "sofa"] else wood)
            if shape == "garden_bench":
                for y in [18, 23]: line(left+2, y, right+2, y, light)
        r(left-2, 29, right-left+8, 7, light if shape not in ["armchair", "sofa"] else rose)
        if shape in ["armchair", "sofa"]: r(left-3, 23, 6, 12, wood); r(right+1, 23, 6, 12, wood)
        if shape == "rocker": line(7, 43, 42, 40, dark, 4)
    elif shape in ["round_table", "square_table", "long_table", "tea_table", "desk", "picnic", "workbench"]:
        legs(25)
        if shape == "round_table": e(24, 23, 20, 9, light)
        else:
            r(4, 19 if shape != "tea_table" else 26, 40, 9, wood); r(5, 19 if shape != "tea_table" else 26, 38, 3, light, False)
        if shape == "desk": r(7, 29, 13, 10, wood); r(27, 15, 10, 5, cream)
        elif shape == "tea_table": e(29, 24, 4, 3, cream)
        elif shape == "picnic": r(1, 33, 46, 5, light); line(11, 25, 35, 42, dark, 3)
        elif shape == "long_table": r(10, 15, 28, 3, cream, False); e(24, 17, 5, 2, sage)
        elif shape == "workbench":
            r(7, 6, 34, 13, dark); line(9, 10, 37, 10, light); r(11, 12, 3, 10, iron); r(26, 7, 3, 14, iron); r(23, 7, 10, 4, iron); r(27, 29, 11, 8, wood)
    elif shape in ["bookcase", "wardrobe", "cupboard", "low_shelf", "display_shelf", "chest", "barrel"]:
        if shape == "barrel":
            p('14,9 34,9 40,20 39,35 33,43 14,43 9,34 9,20', wood); r(9, 18, 30, 4, iron); r(9, 33, 30, 4, iron); line(22, 12, 22, 42, light)
        elif shape == "chest":
            r(5, 22, 38, 20, wood); p('5,22 10,14 38,14 43,22', light); r(10, 15, 3, 27, iron); r(35, 15, 3, 27, iron); r(22, 27, 5, 6, cream)
        else:
            top = 23 if shape == "low_shelf" else 5
            r(6, top, 36, 37 if top == 5 else 19, wood)
            if shape == "wardrobe":
                r(9, 8, 14, 31, light); r(25, 8, 14, 31, light); r(19, 23, 2, 3, cream); r(27, 23, 2, 3, cream)
            else:
                for y in ([27] if shape == "low_shelf" else [10, 25]):
                    r(9, y, 30, 12, dark)
                    for i, color in enumerate([sage, cream, rose, iron]): r(11+i*7, y+3-(i%2)*2, 5, 8+(i%2)*2, color)
                if shape == "cupboard": r(8, 29, 32, 11, light); line(24, 29, 24, 39)
                elif shape == "display_shelf": e(17, 16, 4, 4, rose); star(32, 29)
    elif category == "lighting":
        r(15, 39, 18, 4, wood); r(22, 22, 4, 17, dark)
        if shape == "candle": r(20, 18, 8, 17, cream); p('24,7 28,15 24,20 21,16', '#f5bb65')
        elif shape == "lantern": r(14, 13, 20, 21, iron); r(17, 16, 14, 15, '#f3cd81'); line(17, 12, 21, 6); line(21, 6, 28, 6); line(28, 6, 32, 12)
        elif shape == "floor_lamp": p('14,9 34,9 40,25 8,25', cream)
        elif shape == "street_lamp": r(21, 5, 5, 36, iron); line(24, 8, 38, 8, iron, 3); r(31, 10, 12, 13, cream)
        elif shape == "mushroom_lamp": e(24, 22, 19, 12, rose); r(8, 23, 32, 6, rose, False); e(16, 18, 4, 3, cream); e(32, 20, 3, 3, cream)
        else: p('24,5 36,18 30,36 18,36 12,18', '#9cbeca'); line(24, 5, 24, 34, cream); line(12, 18, 36, 18, cream)
    elif shape.endswith("rug"):
        e(24, 28, 20 if shape != "round_rug" else 16, 13, rose if shape != "star_rug" else '#727595')
        e(24, 28, 16 if shape != "round_rug" else 12, 9, sage if shape == "oval_rug" else '#727595')
        if shape == "star_rug": star(24, 27)
        else:
            for x in [17, 24, 31]: r(x-1, 27, 3, 3, cream, False)
    elif shape in ["mirror", "clock", "painting", "globe", "vase", "aquarium", "music_box", "piano"]:
        if shape == "mirror": e(24, 21, 12, 18, light); e(24, 21, 9, 15, '#adc9cb'); line(19, 28, 28, 13, cream); legs(37, 13, 31)
        elif shape == "clock": r(8, 16, 32, 26, wood); e(24, 17, 14, 14, wood); e(24, 17, 10, 10, cream); line(24, 17, 24, 10); line(24, 17, 30, 20); r(21, 31, 6, 7, light)
        elif shape == "painting": legs(29); line(24, 8, 24, 43, wood, 3); r(6, 9, 36, 27, light); r(9, 12, 30, 21, '#adc9cb'); p('10,31 20,19 29,30', sage); p('24,31 32,23 39,31', '#62795b'); e(32, 18, 3, 3, cream)
        elif shape == "globe": r(16, 40, 16, 4, wood); line(24, 30, 24, 40, wood, 4); e(24, 21, 14, 14, '#8ba9ac'); p('13,16 22,10 29,15 26,22 18,24', sage); line(14, 10, 34, 32, cream)
        elif shape == "vase": p('18,13 30,13 28,23 36,33 31,43 17,43 12,33 20,23', '#b8afc9'); flowers(); r(18, 34, 12, 3, cream, False)
        elif shape == "aquarium": legs(34); r(4, 13, 40, 25, wood); r(7, 16, 34, 19, '#9fc6c9'); p('18,25 24,21 30,25 24,29', '#e3ae72'); p('30,25 35,21 35,29', '#e3ae72'); line(12, 34, 14, 24, sage); r(8, 33, 30, 2, '#b9b08b', False)
        elif shape == "piano":
            # Upright piano silhouette with a readable keyboard and music stand.
            r(5, 10, 38, 30, dark); r(8, 13, 32, 8, wood); p('7,10 14,5 39,5 43,10', light)
            r(8, 22, 32, 9, cream); r(8, 22, 32, 2, light, False)
            for x in range(10, 40, 4): r(x, 23, 3, 7, '#fff4d7', False)
            for x in [13, 21, 29, 37]: r(x, 22, 2, 4, ink, False)
            r(19, 14, 10, 3, cream); line(24, 14, 24, 8, iron); p('19,8 29,8 27,13 21,13', cream)
            r(9, 39, 5, 5, dark); r(34, 39, 5, 5, dark)
        else: r(10, 26, 28, 16, wood); p('10,25 16,16 35,16 38,25', light); e(24, 30, 7, 3, cream); line(25, 17, 25, 8, iron); e(22, 8, 3, 2, iron)
    elif category == "garden":
        if shape in ["flower_box", "clay_planter", "herb_planter"]:
            if shape == "flower_box": r(4, 31, 40, 12, wood); flowers()
            else:
                p('11,28 37,28 32,43 16,43', '#b47d66'); r(9, 26, 30, 5, light)
                if shape == "clay_planter": flowers()
                else:
                    for x in [15, 24, 32]: line(x, 27, x, 13, sage); e(x-3, 17, 5, 2, sage); e(x+3, 22, 5, 2, sage)
        elif shape == "rose_arch":
            r(4, 17, 5, 27, wood); r(39, 17, 5, 27, wood); p('4,17 12,6 36,6 44,17 39,19 33,11 15,11 9,19', sage)
            for x,y in [(10,13),(19,8),(31,8),(40,15)]: e(x,y,3,3,rose)
        elif shape in ["birdbath", "sundial"]:
            r(17, 39, 14, 5, '#9b9c8e'); r(21, 24, 6, 15, '#b4b09d'); e(24, 23, 18, 7, '#b4b09d'); e(24, 22, 14, 4, '#adc9cb' if shape == 'birdbath' else cream)
            if shape == 'sundial': p('20,22 29,10 29,25', iron)
            else: e(10, 17, 4, 3, sage); p('13,17 17,18 13,19', light)
        elif shape == "scarecrow":
            r(22, 11, 4, 33, wood); line(7, 24, 41, 24, wood, 4); p('17,21 30,21 34,35 13,35', rose); e(24, 16, 7, 6, cream); r(12, 10, 24, 4, wood); r(18, 4, 12, 7, wood)
        else:
            r(6, 28, 36, 15, '#a4a48f'); e(24, 28, 18, 6, '#777f7a'); e(24, 28, 12, 3, '#adc9cb'); r(7, 10, 4, 22, wood); r(37, 10, 4, 22, wood); p('3,13 24,2 45,13', rose); line(10, 17, 38, 17, dark, 3); line(24, 17, 24, 30, cream)
    elif shape == "loom":
        legs(5, 6, 38); r(6, 7, 36, 4, wood); r(6, 33, 36, 5, wood)
        for x in range(13, 37, 4): line(x, 11, x, 33, cream, 1)
        r(12, 23, 24, 8, rose); line(12, 27, 36, 27, cream)
    elif shape == "spinning":
        legs(31, 9, 34); e(24, 23, 15, 15, light); e(24, 23, 11, 11, wood)
        for x,y in [(24,10),(36,23),(24,36),(11,23)]: line(24,23,x,y,cream)
        r(3, 7, 6, 15, rose); line(7, 15, 24, 23, cream, 1)
    elif shape == "kiln":
        r(10, 13, 29, 29, '#b48168'); p('10,13 16,7 33,7 39,13', '#c79778'); r(30, 2, 7, 9, '#a47563'); r(17, 27, 15, 15, ink); p('20,39 23,30 27,35 29,31 31,40', '#efb66b')
        for y in [19,24]: line(12,y,37,y,light,1)
    elif shape == "cauldron":
        legs(35, 12, 32); e(24, 29, 18, 13, iron); e(24, 20, 18, 5, ink); e(24, 19, 13, 3, sage); e(19, 11, 3, 3, '#b4c98f'); e(28, 6, 2, 2, '#b4c98f'); star(24,31)
    else:
        raise ValueError(shape)
    return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 48 48">%s</svg>\n' % (width, height, ''.join(parts))


def main():
    protected = ROOT / 'MyArt'
    before = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in protected.rglob('*') if p.is_file()}
    assert protected.resolve() not in OUT.resolve().parents and protected.resolve() not in WORLD.resolve().parents
    OUT.mkdir(parents=True, exist_ok=True)
    WORLD.mkdir(parents=True, exist_ok=True)
    entries = records()
    assert len(entries) >= 60 and len({row['id'] for row in entries}) == len(entries)
    gd = ['extends RefCounted', '## Generated by tools/build_catalog_assets.py.', 'const IDS := ' + json.dumps([r['id'] for r in entries]), 'const CATEGORIES := ' + json.dumps({r[0]: r[1] for r in CATEGORIES}, ensure_ascii=False), 'const RECIPES := {']
    for row in entries:
        ident = row['id']
        recipe = dict(title=row['names'][0], category=row['category'], wood=row['cost'][0], iron=row['cost'][1], ore=row['cost'][2], area=row['area'], solid=row['solid'])
        text = json.dumps(recipe, ensure_ascii=False)
        text = text[:-1] + ', "size": Vector2(%d, %d)}' % tuple(row['size'])
        gd.append('\t"%s": %s,' % (ident, text))
        (OUT / (ident + '.svg')).write_text(svg(row['shape'], row['category']), encoding='utf-8')
        w, h = row['size']
        world_w = max(24, math.ceil(w * 1.2))
        world_h = math.ceil(h * 1.1 + 16) if row['solid'] else math.ceil(h * 1.12)
        (WORLD / (ident + '.svg')).write_text(svg(row['shape'], row['category'], world_w, world_h), encoding='utf-8')
    gd += ['}', '']
    (ROOT / 'Scenes/Building/construction_recipes.gd').write_text('\n'.join(gd), encoding='utf-8')
    # Append only missing translations; never replace user-maintained rows.
    tsv = ROOT / 'Localization/messages.tsv'
    with tsv.open(encoding='utf-8', newline='') as f: translations = list(csv.reader(f, delimiter='\t'))
    known = {row[0] for row in translations[1:]}
    for names in [row['names'] for row in entries] + [list(row[1:]) for row in CATEGORIES]:
        if names[0] not in known: translations.append(names); known.add(names[0])
    with tsv.open('w', encoding='utf-8', newline='') as f: csv.writer(f, delimiter='\t', lineterminator='\n').writerows(translations)
    hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in protected.rglob('*') if p.is_file()}
    assert before == hashes, 'Protected source hashes changed'
    icons = [dict(id=r['id'], path='icons/'+r['id']+'.svg', sha256=hashlib.sha256((OUT/(r['id']+'.svg')).read_bytes()).hexdigest()) for r in entries]
    assert len({r['sha256'] for r in icons}) == len(entries), 'Every icon must have its own silhouette'
    (ROOT / 'Art/Building/manifest.json').write_text(json.dumps(dict(count=len(entries), icons=icons, source='Original code-native SVG silhouettes; no external game assets'), indent=2), encoding='utf-8')
    categories = {row[0]: row[1] for row in CATEGORIES}
    lines = ['# 建造清单', '', f'{len(entries)} 种建造物，图标为项目原创 SVG。所有配方均需要附近的建造工作台。', '',
             '| 图标 | 名称 | 分类 | 木材 | 铁锭 | 矿石 | 场地 |', '| --- | --- | --- | ---: | ---: | ---: | --- |']
    for row in entries:
        area = dict(home='室内', farm='户外', both='室内与户外')[row['area']]
        lines.append('| ![%s](icons/%s.svg) | %s | %s | %d | %d | %d | %s |' %
                     (row['names'][0], row['id'], row['names'][0], categories[row['category']], *row['cost'], area))
    (ROOT / 'Art/Building/CATALOG.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('CONSTRUCTION_ASSETS',len(entries),'MYART_HASHES_UNCHANGED',len(hashes))


if __name__ == '__main__': main()
