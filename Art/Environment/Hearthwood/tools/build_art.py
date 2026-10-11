"""Original raster pixel environments, drawn at native resolution with Pillow."""
from pathlib import Path
from math import cos, sin, pi
import json
import random

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parents[1]
RNG = random.Random(10102026)
P = {
    "ink": "#30251f", "deep": "#453022", "bark": "#624329",
    "wood": "#96613d", "wood_mid": "#ad7750", "wood_light": "#c28c60",
    "grain": "#825433", "gold": "#d3ab71", "cream": "#ead6ad",
    "linen": "#d9c6a0", "stone": "#8b8976", "stone_light": "#b4b09a",
    "leaf_dark": "#354b3e", "leaf": "#587457", "leaf_light": "#819467",
    "sage": "#99a188", "teal": "#647e7b", "teal_light": "#9baea0",
    "rose": "#b87779", "rose_light": "#dba899", "wine": "#7c414c",
    "red": "#a35748", "violet": "#87778e", "blue": "#7b91a0",
}


def canvas(size, color=(0, 0, 0, 0)):
    return Image.new("RGBA", size, color)


def save(im, name):
    OUT.mkdir(parents=True, exist_ok=True)
    im.save(OUT / (name + ".png"))
    return im


def panel(d, box, fill, edge=None, highlight=None):
    d.rectangle(box, fill=fill, outline=edge or P["ink"])
    if highlight:
        x0, y0, x1, y1 = box
        d.line((x0 + 1, y0 + 1, x1 - 1, y0 + 1), fill=highlight)
        d.line((x0 + 1, y0 + 1, x0 + 1, y1 - 1), fill=highlight)


def wood(d, box, vertical=False, shade=0):
    x0, y0, x1, y1 = box
    colors = [P["wood"], P["wood_mid"], P["wood_light"]]
    panel(d, box, colors[shade % 3], P["deep"], P["wood_light"])
    if vertical:
        for x in range(x0 + 3, x1, 6):
            d.line((x, y0 + 2, x, y1 - 2), fill=P["grain"])
        for _ in range(max(1, (x1 - x0) // 10)):
            x, y = RNG.randint(x0 + 2, max(x0 + 2, x1 - 2)), RNG.randint(y0 + 2, max(y0 + 2, y1 - 2))
            d.line((x, y, x, min(y + RNG.randint(3, 10), y1 - 1)), fill=P["gold"])
    else:
        for y in range(y0 + 3, y1, 5):
            d.line((x0 + 2, y, x1 - 2, y), fill=P["grain"])
        for _ in range(max(1, (x1 - x0) // 8)):
            x, y = RNG.randint(x0 + 2, max(x0 + 2, x1 - 2)), RNG.randint(y0 + 2, max(y0 + 2, y1 - 2))
            d.line((x, y, min(x + RNG.randint(3, 12), x1 - 1), y), fill=P["wood_light"])


def planks(im, box, height=12, width=64):
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = box
    colors = ["#97633e", "#a56f45", "#ae794d", "#a87449", "#b38054"]
    for row, y in enumerate(range(y0, y1 + 1, height)):
        start = x0 - (width // 2 if row % 2 else 0)
        for x in range(start, x1 + 1, width):
            bx = max(x, x0), y, min(x + width - 1, x1), min(y + height - 1, y1)
            d.rectangle(bx, fill=RNG.choice(colors))
            d.line((bx[0], bx[3], bx[2], bx[3]), fill="#744c33")
            d.line((bx[0], y + 1, bx[2], y + 1), fill="#c28d5b")
            d.line((bx[0], y + 1, bx[0], bx[3]), fill="#875a39")
            for _ in range(max(2, (bx[2] - bx[0]) // 10)):
                xx = RNG.randint(bx[0] + 1, max(bx[0] + 1, bx[2] - 2))
                yy = RNG.randint(y + 3, max(y + 3, bx[3] - 2))
                d.line((xx, yy, min(xx + RNG.randint(3, 16), bx[2]), yy), fill=RNG.choice(["#95623e", "#b78050", "#ba8356"]))


def rug(d, box, main=P["red"], accent=P["rose_light"]):
    x0, y0, x1, y1 = box
    panel(d, box, P["deep"])
    d.rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), fill=main)
    for off in (4, 7):
        d.rectangle((x0 + off, y0 + off, x1 - off, y1 - off), outline=accent if off == 4 else P["gold"])
    for y in range(y0 + 11, y1 - 9, 13):
        for x in (x0 + 12, x1 - 12):
            d.line([(x, y - 4), (x + 4, y), (x, y + 4), (x - 4, y), (x, y - 4)], fill=accent)
            d.point((x, y), fill=P["cream"])
    cx = (x0 + x1) // 2
    for y in range(y0 + 16, y1 - 12, 22):
        d.line([(cx, y - 7), (cx + 8, y), (cx, y + 7), (cx - 8, y), (cx, y - 7)], fill=P["gold"])
        d.line([(cx, y - 4), (cx + 5, y), (cx, y + 4), (cx - 5, y), (cx, y - 4)], fill=accent)
    for x in range(x0 + 3, x1 - 2, 3):
        d.line((x, y0 - 2, x, y0), fill=P["linen"])
        d.line((x, y1, x, y1 + 2), fill=P["linen"])


def bottle(d, x, y, color, w=5, h=11):
    panel(d, (x, y + 3, x + w - 1, y + h), P["deep"])
    d.rectangle((x + 1, y + 4, x + w - 2, y + h - 1), fill=color)
    d.rectangle((x + 1, y, x + w - 2, y + 3), fill=P["stone"])
    d.line((x + 1, y + 4, x + 1, y + h - 3), fill=P["teal_light"])
    if w >= 5:
        d.line((x + 1, y + h - 5, x + w - 2, y + h - 5), fill=P["linen"])


def pot(d, x, y, color=P["rose"], flowers=False):
    d.polygon([(x - 5, y - 2), (x + 5, y - 2), (x + 3, y + 6), (x - 3, y + 6)], fill=P["deep"])
    d.polygon([(x - 4, y - 1), (x + 4, y - 1), (x + 2, y + 5), (x - 2, y + 5)], fill=color)
    d.line((x - 4, y - 2, x + 4, y - 2), fill=P["gold"])
    for xx, yy in [(x - 5, y - 8), (x + 3, y - 10), (x, y - 12), (x - 1, y - 5)]:
        d.line((x, y - 1, xx, yy), fill=P["leaf_dark"])
        d.rectangle((xx - 2, yy - 1, xx + 2, yy + 1), fill=P["leaf"])
        d.point((xx, yy - 1), fill=P["leaf_light"])
        if flowers:
            d.rectangle((xx - 1, yy - 3, xx + 1, yy - 1), fill=P["rose_light"])
            d.point((xx, yy - 2), fill=P["cream"])


def books(d, box, horizontal=False):
    x0, y0, x1, y1 = box
    colors = [P["teal"], P["wine"], P["gold"], P["violet"], P["red"], P["blue"]]
    if horizontal:
        for i, y in enumerate(range(y0, y1, 4)):
            panel(d, (x0 + i % 3, y, x1 - i % 2, y + 3), colors[i % len(colors)], P["deep"])
            d.line((x0 + 3, y + 1, x1 - 2, y + 1), fill=P["linen"])
    else:
        x = x0
        while x < x1 - 3:
            w, h = RNG.randint(3, 6), RNG.randint(max(5, (y1 - y0) // 2), max(6, y1 - y0))
            panel(d, (x, y1 - h, min(x + w, x1), y1), RNG.choice(colors), P["deep"])
            d.line((x + 1, y1 - h + 3, x + w - 1, y1 - h + 3), fill=P["gold"])
            d.line((x + 1, y1 - 3, x + w - 1, y1 - 3), fill=P["gold"])
            x += w + 1


def arched_window(d, box, curtain=True):
    x0, y0, x1, y1 = box
    cx = (x0 + x1) // 2
    r = (x1 - x0) // 2
    d.pieslice((x0, y0, x1, y0 + r * 2), 180, 360, fill=P["deep"])
    d.rectangle((x0, y0 + r, x1, y1), fill=P["deep"])
    d.pieslice((x0 + 3, y0 + 3, x1 - 3, y0 + r * 2 - 3), 180, 360, fill=P["cream"])
    d.rectangle((x0 + 3, y0 + r, x1 - 3, y1 - 3), fill=P["cream"])
    for y in range(y0 + 12, y1 - 4):
        for x in range(x0 + 4, x1 - 3):
            if (x + y * 3) % 11 == 0 and y > y0 + r // 2:
                d.point((x, y), fill=P["sage"])
    d.line((cx, y0 + 3, cx, y1 - 2), fill=P["wood"], width=2)
    d.line((x0 + 2, y0 + r + 8, x1 - 2, y0 + r + 8), fill=P["wood"], width=2)
    d.line((x0 - 3, y1, x1 + 3, y1), fill=P["gold"], width=3)
    if curtain:
        cy = y0 + r + 6
        for x in range(x0 + 2, x1 - 2, 10):
            d.polygon([(x, cy), (x + 7, cy), (x + 9, y1 - 10), (x + 6, y1 - 7), (x, y1 - 8)], fill=P["rose_light"], outline=P["rose"])
            d.line((x + 3, cy + 1, x + 4, y1 - 10), fill=P["linen"])
        d.line((x0 - 2, cy, x1 + 2, cy), fill=P["deep"], width=2)


def shingle_roof(d, box, colors, gable=True):
    x0, y0, x1, y1 = box
    cx = (x0 + x1) // 2
    outline = [(x0, y0 + 19), (cx, y0), (x1, y0 + 19), (x1, y1), (x0, y1)] if gable else [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    d.polygon(outline, fill=P["ink"])
    d.polygon([(x0 + 2, y0 + 21), (cx, y0 + 2), (x1 - 2, y0 + 21), (x1 - 2, y1 - 3), (x0 + 2, y1 - 3)], fill=colors[0])
    for row, y in enumerate(range(y0 + 23, y1 - 2, 8)):
        for x in range(x0 + 3 - (6 if row % 2 else 0), x1 - 2, 12):
            xx0, xx1 = max(x, x0 + 2), min(x + 10, x1 - 2)
            d.polygon([(xx0, y), (xx1, y), (xx1, y + 4), (xx1 - 2, y + 6), (xx0, y + 6)], fill=RNG.choice(colors[:3]))
            d.line((xx0, y, xx1, y), fill=colors[3])
            d.line((xx0, y + 6, xx1 - 2, y + 6), fill=colors[0])
            d.point((xx1 - 2, y + 2), fill=colors[3])
    d.line((x0, y1, x1, y1), fill=P["deep"], width=4)
    d.line((x0, y1 - 3, x1, y1 - 3), fill=colors[3])
    d.line([(x0, y0 + 19), (cx, y0), (x1, y0 + 19)], fill=colors[3], width=2)


def building(index):
    im = canvas((192, 192))
    d = ImageDraw.Draw(im)
    d.ellipse((13, 175, 179, 191), fill="#30282078")
    panel(d, (17, 94, 174, 187), P["deep"])
    for x in range(21, 173, 17):
        wood(d, (x, 101, min(x + 15, 170), 185), vertical=True, shade=(x // 17) % 2)
    panel(d, (17, 180, 174, 190), P["stone"], P["deep"], P["stone_light"])
    for x in range(20, 173, 14):
        d.line((x, 183, x, 189), fill=P["deep"])
    roof_colors = [
        ["#425a50", "#5e7864", "#6d836a", "#91a182"],
        ["#594d60", "#776779", "#857284", "#a38c9d"],
        ["#744735", "#975e43", "#a46c4b", "#c99468"],
    ][index % 3]
    shingle_roof(d, (9, 7, 182, 123), roof_colors)
    wood(d, (139, 42, 154, 72), vertical=True)
    panel(d, (137, 38, 157, 45), P["stone"], highlight=P["stone_light"])
    d.rectangle((140, 39, 154, 41), fill=P["deep"])
    panel(d, (56, 69, 95, 105), P["deep"])
    shingle_roof(d, (52, 56, 99, 77), roof_colors)
    arched_window(d, (64, 76, 86, 103), curtain=False)
    for x in (25, 126):
        arched_window(d, (x, 137, x + 37, 174), curtain=True)
        wood(d, (x - 4, 146, x - 1, 173), vertical=True)
        wood(d, (x + 38, 146, x + 41, 173), vertical=True)
    d.rounded_rectangle((78, 140, 113, 188), radius=15, fill=P["ink"])
    d.rounded_rectangle((81, 143, 110, 187), radius=13, fill=P["teal"])
    for x in range(84, 109, 6):
        d.line((x, 154, x, 185), fill=P["leaf_dark"])
        d.line((x + 1, 155, x + 1, 182), fill=P["sage"])
    d.rectangle((106, 169, 108, 171), fill=P["gold"])
    d.line((76, 188, 115, 188), fill=P["cream"], width=2)
    wood(d, (63, 125, 128, 138))
    # Pictorial signs stay legible without baking text into artwork.
    symbol = index % 4
    if index == 0:
        d.ellipse((91, 126, 101, 136), fill=P["cream"])
        d.ellipse((95, 125, 103, 133), fill=P["wood_mid"])
        d.point((108, 129), fill=P["cream"])
    elif symbol == 1:
        d.polygon([(87, 134), (94, 127), (101, 134)], fill=P["leaf"])
        d.line((94, 129, 94, 136), fill=P["cream"])
    elif symbol == 2:
        d.rectangle((86, 128, 103, 135), fill=P["linen"], outline=P["deep"])
        d.line((95, 128, 95, 135), fill=P["wood"])
    else:
        d.ellipse((87, 129, 105, 135), fill=P["cream"])
        d.rectangle((91, 126, 101, 130), fill=P["rose"])
    pot(d, 40, 183, P["teal"], flowers=True)
    pot(d, 150, 183, P["red"], flowers=True)
    if index == 0:
        for x, direction in [(18, 1), (174, -1)]:
            d.line([(x, 111), (x - direction * 2, 143), (x, 171), (x + direction * 7, 187)], fill=P["deep"], width=9)
            d.line([(x - direction * 2, 110), (x - direction * 3, 143), (x - direction, 171), (x + direction * 5, 187)], fill=P["wood"], width=4)
            d.arc((x - 4, 155, x + 4, 170), 30, 320, fill=P["gold"])
        for x, direction in [(19, 1), (172, -1)]:
            for y in range(110, 177, 7):
                d.line((x, y, x + direction * 4, y + 6), fill=P["leaf_dark"])
                d.rectangle((x - 2, y, x + 3, y + 2), fill=P["leaf"])
                d.point((x + direction * 2, y), fill=P["leaf_light"])
        d.line((116, 164, 130, 186), fill=P["deep"], width=2)
        d.polygon([(126, 178), (133, 188), (125, 190), (122, 182)], fill=P["gold"], outline=P["bark"])
    return save(im, "shop_" + str(index))


def tree():
    im = canvas((64, 88))
    d = ImageDraw.Draw(im)
    d.ellipse((14, 79, 52, 87), fill="#253c3060")
    d.polygon([(29, 40), (37, 42), (37, 76), (43, 84), (33, 82), (25, 86), (28, 73)], fill=P["deep"])
    d.line([(32, 49), (31, 74), (29, 82)], fill=P["wood"], width=3)
    d.line([(35, 52), (35, 75), (38, 81)], fill=P["gold"])
    points = []
    for i in range(52):
        angle = i * 2 * pi / 52
        radius = 27 + RNG.randint(-3, 3)
        points.append((round(32 + cos(angle) * radius), round(32 + sin(angle) * radius * 0.96)))
    d.polygon(points, fill=P["leaf_dark"], outline=P["ink"])
    for _ in range(65):
        x, y = RNG.randrange(11, 53), RNG.randrange(8, 51)
        if (x - 30) ** 2 / 23 ** 2 + (y - 29) ** 2 / 25 ** 2 > 1:
            continue
        color = P["leaf_light"] if y < 23 and x < 40 else P["leaf"]
        w, h = RNG.randint(4, 9), RNG.randint(3, 6)
        d.polygon([(x - w, y), (x - w + 2, y - h), (x + 2, y - h), (x + w, y - 2), (x + w - 2, y + h), (x - 2, y + h)], fill=color)
        d.line((x - w + 2, y - h, x + 2, y - h), fill=P["sage"] if y < 25 else P["leaf_light"])
    for _ in range(130):
        x, y = RNG.randrange(8, 55), RNG.randrange(6, 51)
        if im.getpixel((x, y))[3] and im.getpixel((x, y))[:3] != (48, 37, 31):
            d.line((x, y, x + 1, y), fill=RNG.choice([P["leaf"], P["leaf_light"], P["leaf_dark"]]))
    return save(im, "town_tree")


def props():
    im = canvas((48, 64))
    d = ImageDraw.Draw(im)
    wood(d, (8, 40, 39, 61), vertical=True)
    d.line((7, 41, 40, 41), fill=P["gold"], width=3)
    d.line((10, 59, 37, 59), fill=P["deep"], width=2)
    for x in (14, 24, 34):
        pot(d, x, 41, P["wood"], flowers=True)
    save(im, "planter")
    im = canvas((48, 64))
    d = ImageDraw.Draw(im)
    d.line((15, 31, 9, 63), fill=P["bark"], width=3)
    d.line((33, 31, 40, 63), fill=P["bark"], width=3)
    wood(d, (11, 22, 36, 55))
    panel(d, (14, 25, 33, 51), P["leaf_dark"], P["deep"])
    d.ellipse((18, 30, 29, 36), outline=P["cream"])
    for y in (40, 44, 47):
        d.line((18, y, 29 - (y % 3), y), fill=P["sage"])
    save(im, "menu")


def town_ground(layout, grass_marks=65000):
    im = canvas((1280, 960), "#6b805b")
    d = ImageDraw.Draw(im)
    for _ in range(grass_marks):
        x, y = RNG.randrange(1280), RNG.randrange(960)
        color = RNG.choice(["#627953", "#728760", "#7e9066", "#87956b", "#5d7351"])
        d.line((x, y, x + RNG.randrange(1, 4), y), fill=color)
        if RNG.random() < 0.08:
            d.line((x + 1, y, x + 2, y - 2), fill="#9aa476")
    roads = [(32, 312, 1248, 416), (32, 632, 1248, 736), (360, 32, 456, 928), (760, 32, 856, 928), (32, 32, 1248, 80), (32, 880, 1248, 928), (32, 32, 96, 928), (1184, 32, 1248, 928)]
    for x0, y0, x1, y1 in roads:
        d.rectangle((x0 - 3, y0 - 3, x1 + 2, y1 + 2), fill="#4b5945")
        d.rectangle((x0, y0, x1 - 1, y1 - 1), fill="#af9c77")
        for y in range(y0, y1, 12):
            for x in range(x0 - (8 if (y // 12) % 2 else 0), x1, 18):
                bx = (max(x, x0), y, min(x + 16, x1 - 1), min(y + 10, y1 - 1))
                d.rectangle(bx, fill=RNG.choice(["#b6a481", "#bfae88", "#ae9d7c", "#c7b591", "#a9a184"]))
                d.line((bx[0] + 1, y + 1, bx[2] - 1, y + 1), fill="#d0bd96")
                d.line((bx[0] + 1, bx[3], bx[2], bx[3]), fill="#91846a")
                if RNG.random() < 0.16:
                    xx = max(x0 + 1, x + 6)
                    d.line([(xx, y + 2), (xx + 2, y + 5), (xx, y + 8)], fill="#94866d")
    for b in layout["buildings"]:
        x, y = b["x"], b["y"]
        d.rounded_rectangle((x - 109, y - 153, x + 109, y + 15), radius=8, fill="#887a55")
        for _ in range(1000):
            xx, yy = RNG.randint(x - 107, x + 107), RNG.randint(y - 150, y + 13)
            d.point((xx, yy), fill=RNG.choice(["#99875d", "#a39168", "#817650"]))
        d.rectangle((x - 18, y - 1, x + 18, min(y + 40, 927)), fill="#b6a17a")
        for yy in range(y + 4, min(y + 41, 928), 9):
            d.line((x - 17, yy, x + 17, yy), fill="#dac298")
        d.rounded_rectangle((x - 76, y - 92, x + 86, y + 6), radius=6, fill="#454b3c")
        for xx in (x - 104, x + 90):
            for yy in range(y - 110, y - 16, 8):
                d.rectangle((xx, yy, xx + 12, yy + 5), fill=P["leaf_dark"])
                d.line((xx + 1, yy, xx + 10, yy), fill=P["leaf_light"])
                if yy % 3 == 0:
                    d.rectangle((xx + 4, yy - 1, xx + 6, yy + 1), fill=P["rose_light"])
    for cx, cy in [(520, 470), (920, 470), (520, 800), (920, 800), (128, 470), (1120, 800)]:
        d.ellipse((cx - 22, cy - 14, cx + 22, cy + 14), fill=P["leaf_dark"])
        for _ in range(60):
            x, y = cx + RNG.randint(-19, 19), cy + RNG.randint(-10, 10)
            d.line((x, y, x + 3, y - 3), fill=P["leaf"])
            d.rectangle((x, y - 2, x + 1, y - 1), fill=RNG.choice([P["rose"], P["gold"], P["cream"], P["violet"]]))
    return save(im, "town_ground")


def bookcase():
    im = canvas((112, 112))
    d = ImageDraw.Draw(im)
    wood(d, (2, 9, 109, 110), vertical=True)
    wood(d, (0, 6, 111, 12))
    for row, y in enumerate((33, 58, 83)):
        panel(d, (8, y - 20, 103, y), P["deep"])
        books(d, (11, y - 17, 66, y - 2))
        if row == 1:
            books(d, (74, y - 17, 101, y - 2), horizontal=True)
        else:
            for i, x in enumerate((75, 86, 97)):
                bottle(d, x, y - 17 + i % 2, [P["teal"], P["rose"], P["gold"]][i], h=13)
        wood(d, (5, y + 1, 106, y + 4))
    for x in (8, 56):
        wood(d, (x, 90, x + 46, 106))
        d.rectangle((x + 4, 94, x + 42, 102), outline=P["gold"])
        d.rectangle((x + 21, 98, x + 23, 99), fill=P["deep"])
    pot(d, 18, 7, P["teal"], flowers=True)
    books(d, (77, 0, 103, 6), horizontal=True)
    return save(im, "home_bookcase")


def alchemy():
    im = canvas((120, 88))
    d = ImageDraw.Draw(im)
    panel(d, (4, 35, 115, 85), P["deep"])
    wood(d, (8, 50, 112, 83), vertical=True)
    for x in (12, 64):
        panel(d, (x, 56, x + 44, 79), P["wood"], P["deep"], P["gold"])
        d.rectangle((x + 5, 61, x + 38, 74), outline=P["wood_light"])
        d.rectangle((x + 36, 65, x + 38, 67), fill=P["deep"])
    wood(d, (1, 40, 118, 49))
    wood(d, (6, 10, 113, 16))
    for i, x in enumerate(range(14, 105, 15)):
        bottle(d, x, 0 + i % 3, [P["teal"], P["violet"], P["rose"], P["sage"]][i % 4], w=7, h=11)
    for i, x in enumerate((12, 24, 37)):
        bottle(d, x, 23 + i % 3, [P["blue"], P["rose"], P["gold"]][i], w=7, h=17)
    d.ellipse((53, 31, 78, 43), fill=P["deep"])
    d.ellipse((55, 30, 76, 39), fill=P["stone_light"], outline=P["stone"])
    d.line((60, 35, 73, 24), fill=P["bark"], width=3)
    panel(d, (85, 28, 108, 42), P["linen"], P["deep"])
    d.line((96, 29, 96, 41), fill=P["grain"])
    for y in (32, 35, 38):
        d.line((88, y, 93, y), fill=P["wood"])
        d.line((99, y, 104, y), fill=P["wood"])
    for x in (19, 106):
        d.line((x, 17, x + 2, 26), fill=P["deep"])
        for y in range(20, 29, 3):
            d.line((x - 2, y - 1, x + 4, y + 1), fill=P["sage"])
    return save(im, "home_alchemy")


def kitchen():
    im = canvas((100, 100))
    d = ImageDraw.Draw(im)
    wood(d, (4, 23, 95, 98), vertical=True)
    panel(d, (6, 50, 93, 62), P["stone_light"], P["deep"], P["cream"])
    panel(d, (7, 64, 51, 96), P["teal"], P["deep"], P["teal_light"])
    panel(d, (55, 64, 92, 96), P["wood_mid"], P["deep"], P["gold"])
    panel(d, (12, 70, 46, 88), P["leaf_dark"], highlight=P["stone"])
    for x in range(15, 44, 3):
        d.line((x, 73, x, 85), fill=P["deep"])
    for x in (16, 33, 63, 80):
        d.ellipse((x, 65, x + 3, 68), fill=P["gold"])
    d.ellipse((15, 48, 45, 58), fill=P["deep"])
    d.ellipse((19, 49, 41, 55), fill=P["stone"])
    d.line((35, 48, 35, 38), fill=P["stone_light"], width=2)
    d.arc((30, 35, 39, 44), 180, 360, fill=P["stone_light"], width=2)
    d.ellipse((62, 41, 83, 57), fill=P["deep"])
    d.ellipse((61, 40, 82, 48), fill=P["teal"], outline=P["teal_light"])
    d.rectangle((66, 32, 77, 42), fill=P["teal"])
    d.ellipse((64, 30, 79, 34), fill=P["teal_light"], outline=P["deep"])
    d.line((71, 31, 71, 27), fill=P["gold"], width=2)
    panel(d, (12, 10, 85, 16), P["wood_mid"], P["deep"], P["gold"])
    for i, x in enumerate((16, 28, 42, 61, 76)):
        bottle(d, x, 0 + i % 3, [P["rose"], P["teal"], P["gold"]][i % 3], w=6, h=10)
    d.line((55, 16, 55, 34), fill=P["deep"], width=2)
    d.ellipse((49, 25, 61, 37), fill=P["bark"], outline=P["gold"])
    return save(im, "home_kitchen")


def bed():
    im = canvas((96, 100))
    d = ImageDraw.Draw(im)
    d.ellipse((4, 86, 92, 99), fill="#3f302978")
    wood(d, (8, 11, 86, 95), vertical=True)
    d.rounded_rectangle((10, 9, 84, 87), radius=10, fill=P["deep"])
    d.rounded_rectangle((13, 11, 82, 84), radius=9, fill=P["linen"], outline=P["gold"])
    d.rounded_rectangle((20, 15, 76, 37), radius=7, fill=P["cream"], outline=P["stone_light"])
    for off in (2, 5):
        d.rectangle((23 + off, 18 + off, 73 - off, 33 - off), outline=P["gold"])
    d.rounded_rectangle((14, 38, 82, 82), radius=6, fill=P["rose"], outline=P["wine"])
    for x in range(22, 81, 13):
        d.rectangle((x, 39, x + 4, 80), fill=P["rose_light"])
        d.line((x + 7, 39, x + 7, 80), fill=P["cream"])
        for y in range(45, 78, 12):
            d.polygon([(x + 2, y - 3), (x + 5, y), (x + 2, y + 3), (x - 1, y)], fill=P["linen"])
    d.line((16, 40, 80, 40), fill=P["cream"], width=2)
    for x in (9, 83):
        d.rectangle((x, 86, x + 3, 97), fill=P["bark"])
        d.point((x, 86), fill=P["gold"])
    return save(im, "home_bed")


def sofa():
    im = canvas((98, 70))
    d = ImageDraw.Draw(im)
    d.ellipse((3, 56, 94, 68), fill="#332d2970")
    wood(d, (5, 28, 92, 62))
    d.rounded_rectangle((8, 10, 89, 53), radius=9, fill=P["leaf_dark"])
    d.rounded_rectangle((11, 9, 86, 34), radius=8, fill=P["teal"], outline=P["teal_light"])
    for x in (20, 49, 76):
        d.point((x, 19), fill=P["leaf_dark"])
    for x in (16, 49):
        d.rounded_rectangle((x, 35, x + 31, 54), radius=4, fill=P["sage"], outline=P["teal"])
        d.line((x + 4, 38, x + 27, 38), fill=P["linen"])
    for x in (8, 86):
        d.rounded_rectangle((x - 4, 31, x + 5, 57), radius=3, fill=P["teal"], outline=P["leaf_dark"])
    d.polygon([(20, 20), (35, 15), (43, 32), (28, 37)], fill=P["rose"], outline=P["wine"])
    for x in (27, 31, 35):
        d.line((x, 21, x + 5, 32), fill=P["rose_light"])
    d.polygon([(57, 17), (73, 19), (71, 35), (55, 33)], fill=P["blue"], outline=P["teal"])
    d.line([(60, 21), (69, 22), (68, 31), (59, 30), (60, 21)], fill=P["linen"])
    return save(im, "home_sofa")


def round_table():
    im = canvas((88, 76))
    d = ImageDraw.Draw(im)
    d.ellipse((3, 57, 85, 75), fill="#30251f70")
    d.rectangle((9, 33, 78, 64), fill=P["deep"])
    d.ellipse((9, 48, 78, 72), fill=P["bark"], outline=P["deep"])
    for x in range(13, 76, 7):
        d.line((x, 38, x, 65), fill=P["wood"])
        d.line((x + 1, 43, x + 1, 67), fill=P["grain"])
    d.ellipse((3, 3, 84, 60), fill=P["wood_light"], outline=P["deep"], width=2)
    for off in (5, 9, 14, 19, 24):
        d.ellipse((3 + off, 3 + off // 2, 84 - off, 60 - off // 2), outline=P["wood_mid"])
    d.arc((11, 6, 76, 52), 190, 300, fill=P["gold"])
    panel(d, (33, 16, 55, 29), P["linen"], P["wood"])
    d.line((44, 17, 44, 28), fill=P["grain"])
    for y in (20, 23, 26):
        d.line((36, y, 41, y), fill=P["wood"])
        d.line((47, y, 51, y), fill=P["wood"])
    d.ellipse((61, 32, 72, 41), fill=P["cream"], outline=P["wood"])
    d.ellipse((64, 31, 70, 36), fill=P["teal_light"], outline=P["teal"])
    d.arc((69, 32, 74, 36), 260, 100, fill=P["teal"])
    pot(d, 23, 35, P["teal"], flowers=True)
    return save(im, "home_table")


def stool():
    im = canvas((24, 24))
    d = ImageDraw.Draw(im)
    d.ellipse((2, 17, 22, 23), fill="#30251f60")
    for x in (5, 17):
        d.rectangle((x, 10, x + 2, 22), fill=P["bark"])
    d.ellipse((1, 7, 22, 19), fill=P["wood"], outline=P["deep"])
    d.ellipse((1, 1, 22, 14), fill=P["wood_light"], outline=P["deep"])
    d.ellipse((5, 3, 18, 11), outline=P["gold"])
    d.ellipse((8, 5, 15, 9), outline=P["wood_mid"])
    return save(im, "home_stool")


def writing_desk():
    im = canvas((88, 72))
    d = ImageDraw.Draw(im)
    wood(d, (10, 37, 15, 69), vertical=True)
    wood(d, (70, 37, 75, 69), vertical=True)
    wood(d, (2, 29, 85, 47))
    panel(d, (29, 33, 58, 44), P["cream"], P["deep"])
    for y in (35, 38, 41):
        d.line((34, y, 53 - y % 3, y), fill=P["grain"])
    d.rectangle((61, 37, 68, 43), fill=P["deep"])
    d.line((64, 39, 71, 17), fill=P["gold"])
    d.polygon([(68, 25), (72, 11), (77, 13), (71, 25)], fill=P["cream"], outline=P["stone"])
    books(d, (8, 16, 26, 32), horizontal=True)
    panel(d, (43, 50, 65, 67), P["wood_mid"], P["deep"], P["gold"])
    d.rectangle((50, 58, 57, 60), fill=P["deep"])
    d.ellipse((72, 13, 83, 28), fill=P["stone_light"], outline=P["deep"])
    d.rectangle((76, 15, 80, 24), fill=P["gold"])
    d.line((78, 15, 78, 10), fill=P["cream"])
    return save(im, "home_desk")


def root_border(d, left=True):
    pts = [(39, 90), (57, 79), (70, 94), (79, 114), (74, 146), (67, 175), (73, 209), (68, 245), (76, 277), (72, 304), (78, 343), (75, 374), (84, 404), (85, 438), (108, 462), (121, 479), (20, 479), (24, 451), (39, 420), (38, 393), (28, 363), (28, 335), (22, 306), (30, 270), (23, 235), (28, 204), (21, 173), (28, 140), (29, 109)]
    if not left:
        pts = [(640 - x, y) for x, y in pts]
    d.polygon(pts, fill=P["bark"], outline=P["deep"])
    for i in range(7):
        path = [(38 + i * 4 + round(sin(y / 29 + i) * 3), y) for y in range(111, 453, 5)]
        if not left:
            path = [(640 - x, y) for x, y in path]
        d.line(path, fill=P["wood"] if i % 2 else P["deep"], width=2)
    for x, y in [(47, 184), (56, 300), (60, 384), (47, 431)]:
        xx = x if left else 640 - x
        for off in (0, 3, 6):
            d.arc((xx - 5 - off, y - 7 - off, xx + 5 + off, y + 8 + off), 30, 320, fill=P["deep"] if off % 2 == 0 else P["wood"])
    branches = [[(57, 207), (73, 209), (87, 216), (99, 231), (110, 237), (129, 243)], [(62, 322), (80, 328), (96, 340), (111, 350), (127, 358), (147, 362)], [(62, 421), (82, 422), (104, 427), (119, 434), (137, 443)]]
    for path in branches:
        if not left:
            path = [(640 - x, y) for x, y in path]
        d.line(path, fill=P["deep"], width=7)
        d.line([(x, y - 1) for x, y in path], fill=P["wood"], width=3)


def home_floor():
    im = canvas((640, 480), "#211719")
    floor = canvas((640, 480))
    planks(floor, (48, 86, 592, 479), height=12, width=61)
    mask = Image.new("L", im.size)
    md = ImageDraw.Draw(mask)
    md.polygon([(84, 85), (556, 85), (589, 139), (589, 393), (545, 435), (391, 435), (377, 479), (263, 479), (247, 435), (87, 435), (50, 392), (50, 146)], fill=255)
    im.paste(floor, (0, 0), mask)
    d = ImageDraw.Draw(im)
    for x in range(84, 556, 26):
        wood(d, (x, 48, min(x + 25, 555), 139), vertical=True, shade=(x // 26) % 2)
    wood(d, (83, 137, 556, 148))
    wood(d, (83, 47, 556, 54))
    arch = [(82, 55), (142, 44), (230, 37), (320, 34), (410, 37), (498, 44), (558, 55)]
    d.line(arch, fill=P["deep"], width=8)
    d.line([(x, y - 2) for x, y in arch], fill=P["wood_light"], width=2)
    arched_window(d, (391, 62, 496, 146), curtain=True)
    pot(d, 405, 147, P["cream"], flowers=True)
    pot(d, 439, 147, P["teal"], flowers=True)
    pot(d, 480, 147, P["rose"], flowers=True)
    d.ellipse((324, 72, 350, 104), fill=P["deep"], outline=P["gold"])
    d.ellipse((327, 75, 347, 97), fill=P["cream"], outline=P["wood"])
    d.line((337, 86, 337, 78), fill=P["bark"])
    d.line((337, 86, 343, 91), fill=P["bark"])
    d.line((337, 99, 337, 112), fill=P["gold"])
    d.ellipse((334, 109, 340, 115), fill=P["gold"], outline=P["deep"])
    for x in (352, 364, 375):
        d.line((x, 110, x - 2, 132), fill=P["gold"])
        for y in range(120, 137, 3):
            d.line((x - 5, y, x + 1, y + 1), fill=P["leaf"])
            d.point((x - 4, y), fill=P["violet"])
    d.line((543, 154, 529, 205), fill=P["deep"], width=2)
    d.polygon([(527, 191), (522, 207), (537, 211), (534, 192)], fill=P["gold"], outline=P["bark"])
    for x in range(525, 535, 3):
        d.line((x + 2, 196, x, 208), fill=P["wood_mid"])
    rug(d, (240, 246, 392, 372), P["linen"], P["rose"])
    rug(d, (298, 352, 342, 466), P["red"], P["rose_light"])
    rug(d, (95, 247, 194, 356), P["violet"], P["rose_light"])
    rug(d, (426, 340, 546, 390), P["teal"], P["gold"])
    root_border(d, True)
    root_border(d, False)
    for x in range(268, 375, 18):
        wood(d, (x, 475, x + 16, 479))
    # Quantized dithered window light retains hard, native pixel edges.
    light = canvas(im.size)
    ld = ImageDraw.Draw(light)
    for y in range(151, 295):
        half = 29 + (y - 151) // 4
        level = 26 if y < 203 else (17 if y < 253 else 9)
        for x in range(445 - half, 446 + half):
            if (x + y) % 3 != 0:
                ld.point((x, y), fill=(242, 219, 172, level))
    im = Image.alpha_composite(im, light)
    return save(im, "home_ground")


def plants():
    for kind in ("mushroom", "berry", "herb", "depleted"):
        im = canvas((32, 32))
        d = ImageDraw.Draw(im)
        d.ellipse((2, 23, 29, 30), fill="#30433475")
        if kind == "mushroom":
            for x, y, r in [(10, 18, 6), (21, 23, 5), (20, 11, 4)]:
                d.rectangle((x - 1, y - 2, x + 2, y + 6), fill=P["linen"], outline=P["bark"])
                d.pieslice((x - r, y - r * 2, x + r, y), 180, 360, fill=P["red"], outline=P["deep"])
                d.rectangle((x - r, y - r, x + r, y - r + 2), fill=P["red"])
                d.point((x - 2, y - r - 2), fill=P["cream"])
                d.point((x + 2, y - r), fill=P["cream"])
        elif kind == "berry":
            for x, y in [(8, 18), (16, 10), (22, 18), (17, 23)]:
                d.ellipse((x - 7, y - 6, x + 7, y + 5), fill=P["leaf_dark"])
                d.ellipse((x - 5, y - 6, x + 5, y + 2), fill=P["leaf"])
                d.line((x - 2, y - 4, x + 3, y - 4), fill=P["leaf_light"])
                for xx, yy in [(x - 3, y), (x + 2, y - 2)]:
                    d.rectangle((xx, yy, xx + 2, yy + 2), fill=P["wine"])
                    d.point((xx, yy), fill=P["rose_light"])
        elif kind == "herb":
            for x, y in [(5, 15), (11, 8), (18, 10), (25, 16), (16, 18)]:
                d.line((16, 28, x, y), fill=P["leaf_dark"], width=2)
                for yy in range(y, 25, 5):
                    d.polygon([(x, yy + 2), (x - 5, yy - 1), (x - 4, yy - 3)], fill=P["leaf"])
                    d.polygon([(x, yy + 1), (x + 5, yy - 3), (x + 3, yy - 4)], fill=P["leaf_light"])
                d.point((x, y), fill=P["violet"])
        else:
            for x in range(8, 25, 4):
                d.line((x, 28, x + 2, 23), fill=P["leaf_dark"])
                d.point((x + 1, 23), fill=P["sage"])
        save(im, "gather_" + kind)


def field(grass_marks=11500, include_trees=True):
    im = canvas((640, 360), "#34443b")
    d = ImageDraw.Draw(im)
    d.rectangle((8, 72, 431, 359), fill="#637856")
    for _ in range(grass_marks):
        x, y = RNG.randint(9, 429), RNG.randint(74, 359)
        d.line((x, y, x + RNG.randint(1, 3), y), fill=RNG.choice(["#58704f", "#71835c", "#839269", "#667d57"]))
    d.polygon([(25, 282), (62, 256), (47, 130), (65, 86), (95, 85), (75, 135), (87, 245), (417, 250), (420, 275), (77, 273), (45, 297)], fill="#aa9770")
    d.rectangle((61, 258, 95, 359), fill="#b3a07b")
    for _ in range(260):
        x, y = RNG.randint(13, 425), RNG.randint(78, 295)
        if im.getpixel((x, y))[:3] == (170, 151, 112):
            d.line((x, y, x + 3, y), fill="#c4af85")
    if include_trees:
        t = Image.open(OUT / "town_tree.png").convert("RGBA")
        for x, y in [(18, 97), (107, 82), (179, 78), (263, 80), (346, 83), (413, 112), (4, 208), (423, 211), (194, 323), (313, 326)]:
            im.alpha_composite(t, (x - 32, y - 88))
    d = ImageDraw.Draw(im)
    for x, y in [(198, 141), (331, 210), (100, 251), (403, 129), (234, 283)]:
        d.polygon([(x - 7, y), (x - 4, y - 7), (x + 5, y - 6), (x + 9, y), (x + 6, y + 5), (x - 6, y + 5)], fill=P["stone"], outline=P["leaf_dark"])
        d.line((x - 3, y - 5, x + 3, y - 4), fill=P["stone_light"])
    for _ in range(110):
        x, y = RNG.randint(14, 425), RNG.randint(85, 296)
        if RNG.random() < 0.65:
            d.rectangle((x, y, x + 1, y + 1), fill=RNG.choice([P["cream"], P["rose"], P["violet"]]))
            d.line((x, y + 2, x, y + 4), fill=P["leaf_dark"])
    return save(im, "field_background")


def restaurant():
    im = canvas((640, 360), "#302923")
    planks(im, (8, 72, 431, 301), 10, 49)
    d = ImageDraw.Draw(im)
    for x in range(8, 432, 24):
        wood(d, (x, 64, min(x + 23, 431), 90), vertical=True)
    wood(d, (8, 88, 431, 94))
    for x in (15, 420):
        wood(d, (x, 92, x + 6, 301), vertical=True)
    rug(d, (86, 174, 397, 269), P["red"], P["gold"])
    for x in (65, 225):
        wood(d, (x, 94, x + 99, 113), vertical=True)
        panel(d, (x + 2, 91, x + 97, 99), P["stone_light"], P["deep"], P["cream"])
        for xx in (x + 12, x + 59):
            d.rectangle((xx, 103, xx + 28, 110), outline=P["gold"])
            d.rectangle((xx + 20, 105, xx + 23, 107), fill=P["deep"])
    panel(d, (78, 91, 111, 99), P["teal"], P["deep"], P["teal_light"])
    bottle(d, 132, 79, P["rose"], w=6, h=13)
    bottle(d, 145, 82, P["teal"], w=6, h=10)
    for x in (245, 285):
        d.ellipse((x, 91, x + 23, 98), fill=P["deep"])
        d.ellipse((x + 2, 88, x + 21, 95), fill=P["teal"], outline=P["teal_light"])
        d.line((x + 11, 88, x + 11, 83), fill=P["gold"], width=2)
    arched_window(d, (338, 68, 376, 104), curtain=True)
    pot(d, 351, 110, P["teal"], flowers=True)
    for x in (110, 245, 375):
        d.ellipse((x - 23, 204, x + 23, 218), fill="#39292170")
        for xx in (x - 15, x + 12):
            d.rectangle((xx, 197, xx + 3, 216), fill=P["bark"])
        wood(d, (x - 20, 190, x + 20, 209))
        panel(d, (x - 13, 193, x + 13, 205), P["linen"], P["wood"])
        d.ellipse((x - 4, 193, x + 4, 198), fill=P["cream"], outline=P["stone"])
        d.ellipse((x + 6, 198, x + 11, 202), fill=P["teal_light"], outline=P["teal"])
    wood(d, (34, 272, 86, 290))
    d.line((40, 280, 73, 280), fill=P["cream"])
    d.polygon([(40, 280), (47, 276), (47, 284)], fill=P["cream"])
    return save(im, "restaurant_background")


def compose(layout, ground_name, output):
    im = Image.open(OUT / (ground_name + ".png")).convert("RGBA")
    for item in sorted(layout, key=lambda item: item["y"]):
        sprite = Image.open(OUT / (item["kind"] + ".png")).convert("RGBA")
        extra = 6 if item["kind"] in ("planter", "menu") else 0
        im.alpha_composite(sprite, (int(item["x"] - sprite.width // 2), int(item["y"] - sprite.height + extra)))
    return save(im, output)


def home_preview(home_im):
    witch = Image.open(ROOT / "Art/Character/Storybook/WalalaWitch/walala-witch.png").convert("RGBA").crop((0, 0, 32, 48))
    home_im.alpha_composite(witch, (304, 357))
    return save(home_im, "home_with_witch")


def main():
    layout = json.loads((ROOT / "Scenes/LanternLane/Art/town_layout.json").read_text(encoding="utf-8"))
    layout["buildings"][0]["role"] = "witch_home"
    ground = town_ground(layout)
    for i in range(9):
        building(i)
    tree()
    props()
    plants()
    field()
    restaurant()
    home_floor()
    for fn in (bookcase, alchemy, kitchen, bed, sofa, round_table, stool, writing_desk):
        fn()
    home = {
        "size": [640, 480], "spawn": [320, 405], "exit": [320, 449],
        "walls": [[48, 80, 544, 46], [48, 126, 12, 298], [580, 126, 12, 298], [48, 424, 214, 12], [378, 424, 214, 12], [250, 436, 12, 44], [378, 436, 12, 44], [250, 476, 140, 8]],
        "furniture": [
            {"kind": "home_bookcase", "x": 141, "y": 206, "w": 104, "h": 46},
            {"kind": "home_alchemy", "x": 277, "y": 205, "w": 112, "h": 42},
            {"kind": "home_kitchen", "x": 452, "y": 207, "w": 92, "h": 42},
            {"kind": "home_bed", "x": 141, "y": 330, "w": 82, "h": 70},
            {"kind": "home_sofa", "x": 486, "y": 286, "w": 88, "h": 38},
            {"kind": "home_table", "x": 318, "y": 328, "w": 76, "h": 36},
            {"kind": "home_stool", "x": 265, "y": 280, "w": 18, "h": 10},
            {"kind": "home_stool", "x": 369, "y": 280, "w": 18, "h": 10},
            {"kind": "home_stool", "x": 274, "y": 347, "w": 18, "h": 10},
            {"kind": "home_stool", "x": 362, "y": 347, "w": 18, "h": 10},
            {"kind": "home_desk", "x": 499, "y": 345, "w": 80, "h": 30},
        ],
    }
    for name, data in [("town_layout", layout), ("home_layout", home)]:
        (OUT / (name + ".json")).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    compose(layout["buildings"] + layout["props"], "town_ground", "town_overview")
    home_im = compose(home["furniture"], "home_ground", "home_overview")
    home_preview(home_im)
    manifest = {
        "reference": "game reference screenshot: Touhou Mystia's Izakaya home interior",
        "method": "original native-resolution Pillow raster pixel drawing; no reference pixels copied",
        "pixel_grid": 1, "character_cell": [32, 48], "seed": 10102026,
        "palette": P, "assets": {p.name: list(Image.open(p).size) for p in sorted(OUT.glob("*.png"))},
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    from build_outdoors import build
    build()
    print("HEARTHWOOD ART", len(list(OUT.glob("*.png"))), "PNG assets; town 1280x960; home 640x480")


if __name__ == "__main__":
    main()
