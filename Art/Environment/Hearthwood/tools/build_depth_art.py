"""Separate restaurant floor and fixtures for feet-based occlusion; preserve the preview."""
from PIL import ImageDraw
import build_art as art


def build():
    p = art.P
    floor = art.canvas((640, 360), "#302923")
    art.planks(floor, (8, 72, 431, 301), 10, 49)
    d = ImageDraw.Draw(floor)
    for x in range(8, 432, 24):
        art.wood(d, (x, 64, min(x + 23, 431), 90), vertical=True)
    art.wood(d, (8, 88, 431, 94))
    for x in (15, 420):
        art.wood(d, (x, 92, x + 6, 301), vertical=True)
    art.rug(d, (86, 174, 397, 269), p["red"], p["gold"])
    art.arched_window(d, (338, 68, 376, 104), curtain=True)
    art.pot(d, 351, 110, p["teal"], flowers=True)
    art.wood(d, (34, 272, 86, 290))
    d.line((40, 280, 73, 280), fill=p["cream"])
    d.polygon([(40, 280), (47, 276), (47, 284)], fill=p["cream"])
    art.save(floor, "restaurant_ground")
    fixtures = art.canvas((640, 360))
    d = ImageDraw.Draw(fixtures)
    for x in (65, 225):
        art.wood(d, (x, 94, x + 99, 113), vertical=True)
        art.panel(d, (x + 2, 91, x + 97, 99), p["stone_light"], p["deep"], p["cream"])
        for xx in (x + 12, x + 59):
            d.rectangle((xx, 103, xx + 28, 110), outline=p["gold"])
            d.rectangle((xx + 20, 105, xx + 23, 107), fill=p["deep"])
    art.panel(d, (78, 91, 111, 99), p["teal"], p["deep"], p["teal_light"])
    art.bottle(d, 132, 79, p["rose"], w=6, h=13)
    art.bottle(d, 145, 82, p["teal"], w=6, h=10)
    for x in (245, 285):
        d.ellipse((x, 91, x + 23, 98), fill=p["deep"])
        d.ellipse((x + 2, 88, x + 21, 95), fill=p["teal"], outline=p["teal_light"])
        d.line((x + 11, 88, x + 11, 83), fill=p["gold"], width=2)
    art.save(fixtures.crop((65, 78, 165, 114)), "restaurant_prep")
    art.save(fixtures.crop((225, 78, 325, 114)), "restaurant_kitchen")
    table = art.canvas((48, 30))
    d = ImageDraw.Draw(table)
    x = 24
    d.ellipse((x - 23, 14, x + 23, 28), fill="#39292170")
    for xx in (x - 15, x + 12):
        d.rectangle((xx, 7, xx + 3, 26), fill=p["bark"])
    art.wood(d, (x - 20, 0, x + 20, 19))
    art.panel(d, (x - 13, 3, x + 13, 15), p["linen"], p["wood"])
    d.ellipse((x - 4, 3, x + 4, 8), fill=p["cream"], outline=p["stone"])
    d.ellipse((x + 6, 8, x + 11, 12), fill=p["teal_light"], outline=p["teal"])
    art.save(table, "restaurant_table")
    print("DEPTH ART 4 restaurant layers")


if __name__ == "__main__":
    build()
