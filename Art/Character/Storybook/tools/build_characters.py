"""Original 32x48 character authoring from a locked, layered pixel contract."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct
import zlib

from PIL import Image, ImageColor, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CELL = (32, 48)
LAYERS = ["shadow", "body", "outfit", "hair", "equipment", "fx"]
INK = "#4d354e"
CREAM = ["#92738b", "#d5bac4", "#eddacf", "#fff0d5"]
GOLD = ["#79535a", "#c29367", "#efd09b", "#fff1c0"]
CUSTOMERS = [
    {"id": "green_braids", "hair_style": "braids", "hat": "#77976e", "hair": "#ad7856", "skin": "#ecc5a3", "outfit": "#88a47b"},
    {"id": "blue_blonde", "hair_style": "bob", "hat": "#7898b8", "hair": "#edcc8a", "skin": "#f5d9b7", "outfit": "#8e9fbd"},
    {"id": "burgundy_curls", "hair_style": "curls", "hat": "#ab7187", "hair": "#69516d", "skin": "#d09b88", "outfit": "#b08098"},
    {"id": "orange_short", "hair_style": "short", "hat": "#d2a079", "hair": "#555368", "skin": "#e5b09a", "outfit": "#c69b80"},
    {"id": "cyan_gray", "hair_style": "locks", "hat": "#77a8a2", "hair": "#d0cbd9", "skin": "#f0cbb3", "outfit": "#89aaa7"},
    {"id": "pink_longblue", "hair_style": "long", "hat": "#c78ea5", "hair": "#707599", "skin": "#e2b6a3", "outfit": "#b28ead"},
]
HERO = {"id": "walala-witch", "hair_style": "silver-bob", "hat": "#a080b7", "hair": "#e6e3ed", "skin": "#f7dcc4", "outfit": "#a78db5"}


def rgba(color):
    return ImageColor.getrgb(color) + (255,)


def mix(color, target, amount):
    a, b = ImageColor.getrgb(color), ImageColor.getrgb(target)
    return "#" + "".join(f"{round(x * (1 - amount) + y * amount):02x}" for x, y in zip(a, b))


def ramp(color):
    return [mix(color, INK, .55), mix(color, INK, .22), color, mix(color, "#fff1dd", .35)]


class Pencil:
    def __init__(self):
        self.layers = {name: Image.new("RGBA", CELL) for name in LAYERS}
        self.draw = {name: ImageDraw.Draw(im) for name, im in self.layers.items()}

    def poly(self, layer, points, color, outline=None):
        self.draw[layer].polygon(points, fill=rgba(color), outline=rgba(outline) if outline else None)

    def rect(self, layer, box, color, outline=None):
        self.draw[layer].rectangle(box, fill=rgba(color), outline=rgba(outline) if outline else None)

    def line(self, layer, points, color):
        self.draw[layer].line(points, fill=rgba(color), width=1)

    def dot(self, layer, x, y, color):
        if 0 <= x < 32 and 0 <= y < 48:
            self.layers[layer].putpixel((x, y), rgba(color))

    def composite(self):
        result = Image.new("RGBA", CELL)
        for name in LAYERS:
            result.alpha_composite(self.layers[name])
        return result


def boots(p, direction, phase, idle, hero=False):
    if idle:
        feet = [(12, 43, 47), (19, 43, 47)]
    else:
        feet = [
            [(11, 42, 47), (19, 43, 46)],
            [(13, 43, 47), (18, 43, 46)],
            [(12, 43, 46), (20, 42, 47)],
            [(13, 43, 46), (18, 43, 47)],
        ][phase]
    if hero:
        feet = [(x + 1 if x < 16 else x - 1, top, bottom) for x, top, bottom in feet]
    if direction == "left":
        feet = [(x - (1 if phase == 0 and not idle else 0), top, bottom) for x, top, bottom in feet]
    elif direction == "right":
        feet = [(x + (1 if phase == 2 and not idle else 0), top, bottom) for x, top, bottom in feet]
    for x, top, bottom in feet:
        p.rect("body", (x - 1, top, x + 1, bottom), "#715366", INK)
        p.line("body", [(x - 1, bottom - 1), (x + 1, bottom - 1)], "#b5939c")
        p.dot("body", x, top + 1, "#c4abb3")


def hero_outfit(p, spec, direction, bob, sway):
    cloth, skin = ramp(spec["outfit"]), ramp(spec["skin"])
    y = lambda value: value + bob
    cx = 15 if direction == "left" else 17 if direction == "right" else 16
    back = direction == "up"
    side = direction in ("left", "right")
    shoulder, waist, hem = (3, 2, 4) if side else (4, 3, 6)
    p.poly("outfit", [(cx - shoulder, y(30)), (cx + shoulder, y(30)), (cx + shoulder + 1, y(33)), (cx + waist, y(36)), (cx + hem + sway, y(41)), (cx + hem - 1, y(42)), (cx - hem + 1, y(42)), (cx - hem + sway, y(41)), (cx - waist, y(36)), (cx - shoulder - 1, y(33))], cloth[2], INK)
    p.poly("outfit", [(cx - shoulder + 1, y(31)), (cx - 1, y(32)), (cx - 1, y(35)), (cx - hem + 2 + sway, y(40)), (cx - hem + 1 + sway, y(40))], cloth[3])
    p.poly("outfit", [(cx + 1, y(32)), (cx + shoulder - 1, y(32)), (cx + waist - 1, y(36)), (cx + hem - 1 + sway, y(40)), (cx + 2, y(41))], cloth[1])
    p.line("outfit", [(cx - waist, y(36)), (cx + waist, y(36))], cloth[0])
    p.line("outfit", [(cx, y(37)), (cx - 1 + sway, y(40))], cloth[0])
    p.line("outfit", [(cx - hem + 1 + sway, y(41)), (cx - 2, y(42)), (cx + 1, y(41)), (cx + hem - 1 + sway, y(41))], CREAM[2] if back else CREAM[3])
    if back:
        p.line("outfit", [(cx - 3, y(31)), (cx + 3, y(31))], CREAM[2])
    else:
        p.poly("outfit", [(cx - shoulder + 1, y(31)), (cx, y(33)), (cx + shoulder - 1, y(31)), (cx + 1, y(34)), (cx - 1, y(34))], CREAM[3], CREAM[0])
        p.dot("equipment", cx, y(34), GOLD[3])
        p.dot("equipment", cx, y(35), GOLD[1])
    sleeves = [cx - shoulder - 1, cx + shoulder + 1] if not side else [cx - 2 if direction == "left" else cx + 2]
    for index, x in enumerate([] if getattr(p, "tool_pose", False) else sleeves):
        arm_y = y(32) + (sway if index == 0 else -sway)
        p.poly("outfit", [(x, arm_y), (x + 1, arm_y + 1), (x + 1, arm_y + 4), (x - 1, arm_y + 4), (x - 1, arm_y + 1)], cloth[3], INK)
        p.line("outfit", [(x - 1, arm_y + 3), (x + 1, arm_y + 3)], CREAM[3])
        p.rect("body", (x, arm_y + 4, x + 1, arm_y + 6), skin[2], skin[1])
    bag_x = cx + (3 if side else 5)
    p.line("equipment", [(cx - 2, y(31)), (cx + 1, y(35)), (bag_x + 1, y(38))], GOLD[1])
    p.rect("equipment", (bag_x, y(37), bag_x + 3, y(41)), GOLD[1], GOLD[0])
    p.line("equipment", [(bag_x + 1, y(38)), (bag_x + 2, y(38))], GOLD[2])
    p.dot("equipment", bag_x + 1, y(40), CREAM[3])


def outfit(p, spec, direction, bob, sway, hero, eating):
    if hero:
        hero_outfit(p, spec, direction, bob, sway)
        return
    cloth = ramp(spec["outfit"])
    y = lambda value: value + bob
    if direction == "up":
        p.poly("outfit", [(10, y(31)), (21, y(31)), (24, y(34)), (27 + sway, y(42)), (23, y(44)), (8, y(44)), (5 + sway, y(42)), (7, y(35))], cloth[2], INK)
        p.poly("outfit", [(11, y(32)), (16, y(33)), (14, y(41)), (8, y(42)), (9, y(36))], cloth[3])
        p.poly("outfit", [(19, y(33)), (23, y(36)), (25 + sway, y(41)), (20, y(42))], cloth[1])
        p.line("outfit", [(16, y(34)), (17, y(40)), (15, y(43))], cloth[0])
        p.line("outfit", [(8, y(43)), (12, y(44)), (20, y(44)), (24, y(42))], CREAM[1])
        p.line("outfit", [(12, y(32)), (18, y(32))], CREAM[2])
        return
    side = direction in ("left", "right")
    cx = 15 if direction == "left" else 17 if direction == "right" else 16
    p.poly("outfit", [(cx - 6, y(31)), (cx + 6, y(31)), (cx + 8, y(34)), (cx + 7 + sway, y(41)), (cx + 8, y(43)), (cx + 5, y(44)), (cx - 6, y(44)), (cx - 8, y(42)), (cx - 7, y(34))], cloth[2], INK)
    p.poly("outfit", [(cx - 6, y(33)), (cx - 2, y(33)), (cx - 2, y(40)), (cx - 6, y(41))], cloth[3])
    p.poly("outfit", [(cx + 3, y(33)), (cx + 6, y(33)), (cx + 6, y(42)), (cx + 2, y(43))], cloth[1])
    p.line("outfit", [(cx, y(37)), (cx - 1, y(41)), (cx - 2, y(43))], cloth[0])
    p.line("outfit", [(cx + 3, y(39)), (cx + 4, y(43))], cloth[0])
    p.line("outfit", [(cx - 6, y(43)), (cx - 3, y(44)), (cx + 1, y(43)), (cx + 4, y(44)), (cx + 6, y(43))], CREAM[3])
    p.poly("outfit", [(cx - 5, y(32)), (cx, y(34)), (cx + 5, y(32)), (cx + 3, y(35)), (cx - 2, y(35))], CREAM[3], CREAM[0])
    p.dot("equipment", cx, y(35), GOLD[3])
    p.dot("equipment", cx, y(36), GOLD[1])
    if spec["hair_style"] in ("braids", "locks"):
        p.poly("outfit", [(cx - 3, y(36)), (cx + 3, y(36)), (cx + 4, y(42)), (cx - 4, y(42))], CREAM[2], CREAM[0])
        p.line("outfit", [(cx - 2, y(40)), (cx + 1, y(40))], CREAM[3])
        p.dot("outfit", cx + 2, y(41), CREAM[1])
    sleeves = [cx - 7, cx + 7]
    if side:
        sleeves = [cx - 3 if direction == "left" else cx + 3]
    skin = ramp(spec["skin"])
    for index, x in enumerate(sleeves):
        arm_y = y(34) + (sway if index == 0 else -sway)
        p.poly("outfit", [(x - 1, arm_y), (x + 1, arm_y), (x + 2, arm_y + 3), (x, arm_y + 5), (x - 2, arm_y + 3)], cloth[3], INK)
        p.line("outfit", [(x - 1, arm_y + 3), (x + 1, arm_y + 3)], CREAM[3])
        p.rect("body", (x - 1, arm_y + 4, x + 1, arm_y + 6), skin[2], skin[1])
    if eating:
        hand_y = y((33, 30, 29, 34)[eating - 1])
        x = cx + (5, 4, 3, 6)[eating - 1]
        p.line("fx", [(x + 1, y(37)), (x + 2, y(34)), (x, hand_y + 2)], cloth[0])
        p.rect("fx", (x - 1, hand_y, x + 1, hand_y + 2), skin[2], skin[1])
        p.poly("fx", [(cx - 1, y(33)), (cx + 2, y(33)), (cx + 3, y(36)), (cx + 1, y(37)), (cx - 1, y(36))], CREAM[3], CREAM[0])
        p.line("fx", [(cx, y(34)), (cx + 1, y(34))], GOLD[1])
        p.line("fx", [(x, hand_y), (x - 1, hand_y - 3)], CREAM[3])
        p.dot("fx", x - 1, hand_y - 3, GOLD[2])


def hero_face(p, spec, direction, bob):
    if direction != "down":
        face(p, spec, direction, bob, False, False)
        return
    skin = ramp(spec["skin"])
    y = lambda value: value + bob
    p.poly("body", [(11, y(20)), (20, y(20)), (22, y(23)), (22, y(27)), (20, y(29)), (17, y(31)), (14, y(31)), (11, y(29)), (9, y(27)), (9, y(23))], skin[2], mix(spec["skin"], "#a06e83", .48))
    p.poly("body", [(11, y(22)), (15, y(21)), (20, y(23)), (20, y(28)), (16, y(30)), (12, y(28)), (10, y(25))], skin[3])
    for x in (11, 18):
        p.rect("body", (x, y(24), x + 2, y(27)), "#5c344f")
        p.line("body", [(x + 1, y(26)), (x + 2, y(26))], "#b87365")
        p.line("body", [(x + 1, y(27)), (x + 2, y(27))], "#dfab75")
        p.dot("body", x, y(24), "#fff6df")
    for x in (10, 20):
        p.line("body", [(x, y(28)), (x + 1, y(28))], "#e4a4ae")
    p.line("body", [(15, y(29)), (16, y(29))], "#c99099")


def face(p, spec, direction, bob, blink, eating):
    skin = ramp(spec["skin"])
    y = lambda value: value + bob
    if direction == "up":
        p.rect("body", (13, y(29), 19, y(33)), skin[2], skin[1])
        return
    if direction == "down":
        points = [(10, y(20)), (21, y(20)), (23, y(22)), (23, y(28)), (21, y(31)), (18, y(32)), (13, y(32)), (10, y(30)), (8, y(27)), (8, y(23))]
        p.poly("body", points, skin[2], mix(spec["skin"], "#a06e83", .48))
        p.poly("body", [(10, y(22)), (14, y(21)), (21, y(23)), (20, y(29)), (12, y(30)), (9, y(27))], skin[3])
        p.line("body", [(12, y(31)), (18, y(31)), (21, y(29))], skin[1])
        for x in (11, 19):
            if blink:
                p.line("body", [(x, y(27)), (x + 2, y(27))], INK)
            else:
                p.rect("body", (x, y(25), x + 2, y(28)), "#5c344f")
                p.line("body", [(x + 1, y(27)), (x + 2, y(27))], "#b87365")
                p.line("body", [(x + 1, y(28)), (x + 2, y(28))], "#dfab75")
                p.dot("body", x, y(25), "#fff6df")
                p.dot("body", x - 1, y(26), INK)
        p.line("body", [(9, y(29)), (10, y(29))], "#e4a4ae")
        p.line("body", [(21, y(29)), (22, y(29))], "#e4a4ae")
        p.line("body", [(15, y(30)), (16, y(30))], "#bd798b" if eating else "#c99099")
        return
    right = direction == "right"
    points = ([(13, y(21)), (21, y(21)), (23, y(23)), (23, y(26)), (25, y(27)), (23, y(28)), (23, y(30)), (19, y(32)), (14, y(31)), (12, y(28))]
              if right else [(10, y(21)), (18, y(21)), (20, y(23)), (20, y(29)), (17, y(32)), (12, y(32)), (8, y(30)), (8, y(28)), (6, y(27)), (8, y(25)), (8, y(23))])
    p.poly("body", points, skin[2], mix(spec["skin"], "#a06e83", .48))
    p.poly("body", ([(15, y(22)), (21, y(23)), (22, y(28)), (19, y(30)), (15, y(28))]
                    if right else [(10, y(23)), (15, y(22)), (18, y(25)), (16, y(29)), (10, y(30)), (8, y(27))]), skin[3])
    x = 20 if right else 9
    if blink:
        p.line("body", [(x, y(27)), (x + 2, y(27))], INK)
    else:
        p.rect("body", (x, y(25), x + 2, y(28)), "#5c344f")
        p.dot("body", x, y(25), "#fff6df")
        p.line("body", [(x + 1, y(28)), (x + 2, y(28))], "#dfab75")
    p.line("body", [(x, y(30)), (x + 1, y(30))], "#e4a4ae")


def hero_hair(p, spec, direction, bob):
    c = ramp(spec["hair"])
    y = lambda value: value + bob
    if direction == "up":
        p.poly("hair", [(11, y(18)), (20, y(18)), (24, y(21)), (24, y(26)), (22, y(29)), (20, y(31)), (12, y(31)), (8, y(28)), (7, y(23)), (9, y(20))], c[2], c[0])
        p.poly("hair", [(10, y(20)), (15, y(19)), (18, y(21)), (16, y(27)), (11, y(29)), (9, y(26))], c[3])
        for x in (12, 18, 22):
            p.line("hair", [(x, y(23)), (x - 1, y(26)), (x, y(29))], c[1])
        p.line("hair", [(10, y(29)), (12, y(30)), (16, y(29)), (18, y(31)), (21, y(29))], c[1])
    elif direction == "down":
        p.poly("hair", [(11, y(18)), (20, y(18)), (23, y(20)), (24, y(25)), (23, y(29)), (21, y(31)), (21, y(28)), (22, y(26)), (22, y(22)), (20, y(23)), (18, y(21)), (16, y(24)), (14, y(21)), (12, y(23)), (10, y(22)), (9, y(27)), (10, y(29)), (10, y(31)), (8, y(29)), (7, y(25)), (8, y(21))], c[2], c[0])
        p.poly("hair", [(10, y(20)), (13, y(19)), (15, y(20)), (12, y(21)), (10, y(21)), (9, y(25)), (8, y(24))], c[3])
        p.line("hair", [(19, y(20)), (22, y(21)), (23, y(25)), (22, y(28))], c[1])
        p.line("hair", [(8, y(25)), (9, y(28))], c[3])
    elif direction == "right":
        p.poly("hair", [(11, y(18)), (20, y(18)), (23, y(21)), (22, y(23)), (20, y(22)), (18, y(24)), (17, y(22)), (15, y(24)), (16, y(27)), (15, y(30)), (12, y(31)), (9, y(29)), (8, y(25)), (8, y(22))], c[2], c[0])
        p.poly("hair", [(11, y(20)), (16, y(19)), (18, y(21)), (14, y(23)), (12, y(28)), (10, y(27)), (9, y(24))], c[3])
        p.line("hair", [(13, y(24)), (12, y(27)), (13, y(30))], c[1])
    else:
        p.poly("hair", [(11, y(18)), (20, y(18)), (23, y(21)), (24, y(25)), (23, y(29)), (20, y(31)), (18, y(30)), (16, y(27)), (16, y(24)), (13, y(22)), (11, y(24)), (10, y(22)), (8, y(23)), (8, y(21))], c[2], c[0])
        p.poly("hair", [(13, y(19)), (18, y(19)), (21, y(21)), (22, y(24)), (20, y(22)), (17, y(22))], c[3])
        p.line("hair", [(21, y(25)), (22, y(28)), (20, y(30))], c[1])


def hair(p, spec, direction, bob, sway):
    c = ramp(spec["hair"])
    y = lambda value: value + bob
    if direction == "up":
        p.poly("hair", [(10, y(18)), (21, y(18)), (25, y(21)), (25, y(28)), (23, y(32)), (20, y(34)), (11, y(34)), (7, y(31)), (6, y(23)), (8, y(20))], c[2], c[0])
        p.poly("hair", [(9, y(20)), (15, y(19)), (18, y(21)), (16, y(29)), (10, y(31)), (8, y(28))], c[3])
        for x in (12, 18, 22):
            p.line("hair", [(x, y(24)), (x - 1, y(28)), (x, y(32))], c[1])
        p.line("hair", [(8, y(31)), (10, y(33)), (13, y(32)), (16, y(34)), (20, y(32)), (23, y(31))], c[1])
        return
    if direction in ("left", "right"):
        right = direction == "right"
        points = ([(10, y(18)), (20, y(18)), (23, y(21)), (23, y(24)), (21, y(23)), (19, y(25)), (17, y(23)), (15, y(25)), (16, y(29)), (15, y(33)), (11, y(34)), (7, y(31)), (6, y(23))]
                  if right else [(11, y(18)), (21, y(18)), (25, y(21)), (25, y(29)), (23, y(33)), (18, y(34)), (16, y(31)), (16, y(25)), (13, y(23)), (11, y(25)), (10, y(23)), (8, y(24)), (8, y(21))])
        p.poly("hair", points, c[2], c[0])
        if right:
            p.poly("hair", [(10, y(20)), (16, y(19)), (18, y(21)), (14, y(24)), (11, y(30)), (9, y(29)), (8, y(24))], c[3])
            p.line("hair", [(13, y(25)), (12, y(29)), (13, y(32))], c[1])
            p.dot("hair", 14, y(33), c[3])
        else:
            p.poly("hair", [(13, y(19)), (18, y(19)), (22, y(22)), (21, y(25)), (19, y(23)), (17, y(23))], c[3])
            p.line("hair", [(21, y(26)), (23, y(29)), (21, y(32))], c[1])
            p.dot("hair", 19, y(33), c[3])
        return
    # Bangs leave the two eye clusters and the cheek highlights unobstructed.
    p.poly("hair", [(10, y(18)), (21, y(18)), (25, y(21)), (26, y(28)), (24, y(33)), (21, y(34)), (21, y(31)), (23, y(28)), (23, y(23)), (20, y(24)), (18, y(22)), (16, y(25)), (14, y(22)), (11, y(24)), (9, y(23)), (8, y(29)), (10, y(32)), (10, y(34)), (6, y(32)), (5, y(27)), (6, y(22))], c[2], c[0])
    p.poly("hair", [(8, y(20)), (13, y(19)), (15, y(20)), (12, y(22)), (9, y(21)), (7, y(25)), (6, y(25)), (7, y(22))], c[3])
    p.line("hair", [(18, y(20)), (20, y(21)), (23, y(22)), (24, y(27)), (23, y(31))], c[1])
    p.line("hair", [(7, y(26)), (7, y(30)), (9, y(32))], c[3])
    style = spec["hair_style"]
    if style == "braids":
        for x in (7, 24):
            for index in range(5):
                yy = y(31 + index * 2)
                dx = (index + (sway != 0)) % 2
                p.poly("hair", [(x + dx, yy), (x + 2 + dx, yy + 1), (x + 1 + dx, yy + 2), (x - 1 + dx, yy + 1)], c[2], c[0])
                p.dot("hair", x + dx, yy, c[3])
            p.line("equipment", [(x, y(40)), (x + 2, y(40))], GOLD[2])
    elif style == "curls":
        for x, yy in [(5, 24), (24, 23), (5, 29), (24, 29), (7, 33), (22, 33)]:
            p.poly("hair", [(x, y(yy)), (x + 2, y(yy)), (x + 3, y(yy + 2)), (x + 1, y(yy + 3)), (x - 1, y(yy + 2))], c[2], c[0])
            p.dot("hair", x, y(yy + 1), c[3])
    elif style == "long":
        for x in (6, 24):
            p.poly("hair", [(x, y(27)), (x + 2, y(27)), (x + 3 + sway, y(38)), (x + 1, y(41)), (x - 1, y(39))], c[2], c[0])
            p.line("hair", [(x + 1, y(30)), (x + 1, y(37))], c[3])
            p.line("equipment", [(x, y(32)), (x + 2, y(32))], CREAM[2])
    elif style == "short":
        p.line("hair", [(6, y(27)), (8, y(29))], c[0])
        p.line("hair", [(23, y(27)), (25, y(29))], c[0])


def hat(p, spec, direction, bob, hero):
    c = ramp(spec["hat"])
    y = lambda value: value + bob
    if direction == "left":
        crown = [(8, y(18)), (10, y(14)), (13, y(10)), (17, y(7)), (19, y(5)), (23, y(6)), (21, y(8)), (20, y(11)), (23, y(16)), (24, y(19))]
    elif direction == "right":
        crown = [(8, y(19)), (10, y(14)), (12, y(10)), (13, y(7)), (17, y(5)), (19, y(6)), (18, y(8)), (19, y(11)), (23, y(15)), (24, y(19))]
    else:
        crown = [(8, y(18)), (11, y(13)), (15, y(9)), (19, y(7)), (21, y(5)), (24, y(6)), (22, y(8)), (21, y(10)), (22, y(13)), (25, y(18))]
    p.poly("equipment", crown, c[2], c[0])
    p.poly("equipment", [(11, y(15)), (15, y(11)), (19, y(9)), (18, y(13)), (14, y(17)), (10, y(18))], c[3])
    p.poly("equipment", [(21, y(11)), (23, y(15)), (24, y(18)), (18, y(18)), (19, y(15))], c[1])
    p.line("equipment", [(9, y(17)), (14, y(16)), (21, y(16)), (24, y(17))], CREAM[1])
    p.line("equipment", [(10, y(18)), (15, y(17)), (22, y(17))], CREAM[3])
    if hero:
        p.poly("equipment", [(7, y(18)), (11, y(18)), (16, y(19)), (23, y(18)), (26, y(19)), (27, y(20)), (24, y(21)), (20, y(21)), (15, y(20)), (9, y(21)), (4, y(20)), (5, y(19))], c[2], c[0])
        p.line("equipment", [(6, y(19)), (8, y(19)), (11, y(19))], c[3])
        p.line("equipment", [(20, y(20)), (24, y(20)), (26, y(19))], c[1])
    else:
        p.poly("equipment", [(5, y(18)), (11, y(18)), (16, y(19)), (24, y(18)), (28, y(19)), (29, y(20)), (25, y(21)), (20, y(21)), (15, y(20)), (8, y(21)), (2, y(20)), (3, y(19))], c[2], c[0])
        p.line("equipment", [(4, y(19)), (8, y(19)), (11, y(19))], c[3])
        p.line("equipment", [(20, y(20)), (25, y(20)), (28, y(19))], c[1])
    if direction != "up":
        x = 10 if direction == "left" else 23
        if hero:
            p.line("equipment", [(x + 1, y(16)), (x, y(17)), (x, y(18)), (x + 1, y(19)), (x + 2, y(19))], GOLD[2])
            p.dot("equipment", x + 1, y(17), GOLD[3])
        else:
            p.poly("equipment", [(x, y(16)), (x + 2, y(17)), (x + 1, y(19)), (x - 1, y(18))], GOLD[2], GOLD[0])
            p.dot("equipment", x, y(17), CREAM[3])


def author(spec, direction="down", phase=0, idle=True, customer_frame=None, tool_pose=False):
    p = Pencil()
    p.tool_pose = tool_pose
    hero = customer_frame is None
    eating = 0 if hero or customer_frame < 2 else customer_frame - 1
    bob = (-1 if phase in (1, 3) and not idle else 0) if hero else (-1 if customer_frame in (1, 2, 4) else 0)
    sway = (0, 1, 0, -1)[phase] if not idle else 0
    blink = not hero and customer_frame == 1
    boots(p, direction, phase, idle, hero)
    if hero:
        hero_face(p, spec, direction, bob)
    else:
        face(p, spec, direction, bob, blink, eating)
    outfit(p, spec, direction, bob, sway, hero, eating)
    if hero:
        hero_hair(p, spec, direction, bob)
    else:
        hair(p, spec, direction, bob, sway)
    hat(p, spec, direction, bob, hero)
    return p


def animation(name, start, end, duration):
    return {"name": name, "from": start, "to": end, "duration_ms": duration, "direction": "forward", "loop": True}


def manifest(spec, hero):
    animations = []
    if hero:
        for row, direction in enumerate(("down", "up", "right", "left")):
            animations.extend([animation("idle-" + direction, row * 5, row * 5, 400), animation("walk-" + direction, row * 5 + 1, row * 5 + 4, 110)])
    else:
        animations = [animation("idle", 0, 1, 400), animation("eat", 2, 5, 500)]
    return {
        "version": 1, "character_id": spec["id"], "family": "ally-sheet" if hero else "map-npc",
        "canvas": {"width": 32, "height": 48}, "pivot": {"x": 16, "y": 48}, "layers": LAYERS,
        "frame_source": {"count": 20 if hero else 6, "layers": {name: "frames/{index:03d}-" + name + ".png" for name in LAYERS}},
        "required_animation_tags": [item["name"] for item in animations], "animations": animations,
        "export": {"columns": 5 if hero else 6},
        "validation": {"binary_alpha": True, "palette_max_per_frame": 48, "expected_baseline": 47},
        "design": spec, "reference_note": "See ../STYLE.md; original native pixel drawing, no reference pixels copied",
    }


def chunk(kind, payload):
    return struct.pack("<IH", len(payload) + 6, kind) + payload


def aseprite(frames, data):
    durations = [100] * len(frames)
    for tag in data["animations"]:
        for index in range(tag["from"], tag["to"] + 1):
            durations[index] = tag["duration_ms"]
    output = []
    for index, p in enumerate(frames):
        chunks = []
        if index == 0:
            for name in LAYERS:
                encoded = name.encode()
                chunks.append(chunk(0x2004, struct.pack("<HHHHHHB", 1, 0, 0, 0, 0, 0, 255) + bytes(3) + struct.pack("<H", len(encoded)) + encoded))
            payload = struct.pack("<H", len(data["animations"])) + bytes(8)
            for tag in data["animations"]:
                name = tag["name"].encode()
                payload += struct.pack("<HHBH", tag["from"], tag["to"], 0, 0) + bytes(6) + bytes((160, 128, 183, 0)) + struct.pack("<H", len(name)) + name
            chunks.append(chunk(0x2018, payload))
        for layer, name in enumerate(LAYERS):
            im = p.layers[name]
            payload = struct.pack("<HhhBHh", layer, 0, 0, 255, 2, 0) + bytes(5) + struct.pack("<HH", *CELL) + zlib.compress(im.tobytes())
            chunks.append(chunk(0x2005, payload))
        body = b"".join(chunks)
        output.append(struct.pack("<IHHHHI", len(body) + 16, 0xF1FA, len(chunks), durations[index], 0, 0) + body)
    header = bytearray(128)
    struct.pack_into("<IHHHHHIH", header, 0, 128 + sum(map(len, output)), 0xA5E0, len(frames), *CELL, 32, 1, 100)
    struct.pack_into("<HBBhhHH", header, 32, 0, 1, 1, 0, 0, *CELL)
    return bytes(header) + b"".join(output)


def contact_sheet(images, labels, columns, scale, path):
    rows = (len(images) + columns - 1) // columns
    cell_w, cell_h = 32 * scale + 16, 48 * scale + 28
    canvas = Image.new("RGB", (columns * cell_w, rows * cell_h), "#ddd8dc")
    draw = ImageDraw.Draw(canvas)
    for index, im in enumerate(images):
        x, y = (index % columns) * cell_w + 8, (index // columns) * cell_h + 20
        draw.text((x, y - 16), labels[index], fill="#5a485a")
        tile = im.resize((32 * scale, 48 * scale), Image.Resampling.NEAREST)
        canvas.paste(tile, (x, y), tile)
    canvas.save(path)


def folder_for(spec, hero):
    return ROOT / ("WalalaWitch" if hero else "WitchCustomers/" + spec["id"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--design-only", action="store_true")
    parser.add_argument("--hero-only", action="store_true")
    args = parser.parse_args()
    specs = [(HERO, True)] + ([] if args.hero_only else [(item, False) for item in CUSTOMERS])
    for spec, hero in specs:
        folder = folder_for(spec, hero)
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "character-manifest.json").write_text(json.dumps(manifest(spec, hero), indent=2) + "\n", encoding="utf-8")
    designs = [author(HERO, direction).composite() for direction in ("down", "up", "right", "left")]
    designs += [author(spec, customer_frame=0).composite() for spec in CUSTOMERS]
    contact_sheet(designs, ["witch " + d for d in ("down", "up", "right", "left")] + [s["id"] for s in CUSTOMERS], 5, 5, ROOT / "design-preview.png")
    if args.design_only:
        print("Created native design keys and", len(specs), "production manifests.")
        return
    for spec, hero in specs:
        folder = folder_for(spec, hero)
        data = manifest(spec, hero)
        frames = ([author(spec, direction, max(0, column - 1), idle=column == 0) for direction in ("down", "up", "right", "left") for column in range(5)]
                  if hero else [author(spec, customer_frame=frame) for frame in range(6)])
        source = folder / "frames"
        source.mkdir(exist_ok=True)
        for index, p in enumerate(frames):
            for name, im in p.layers.items():
                im.save(source / f"{index:03d}-{name}.png")
        (folder / (spec["id"] + ".aseprite")).write_bytes(aseprite(frames, data))
        contact_sheet([p.composite() for p in frames], [str(i) for i in range(len(frames))], 5 if hero else 6, 4, folder / "contact-sheet.png")
    print("Created", len(specs), "layered 32x48 characters and Aseprite-compatible masters.")


if __name__ == "__main__":
    main()
