"""Build bare native pixel room shells from the gameplay expansion geometry."""
import re
import random
from pathlib import Path
from PIL import ImageDraw
import build_art as art


def build():
    source = (art.ROOT / 'Scenes/Building/house_catalog.gd').read_text(encoding='utf-8')
    floors = re.findall(r'Rect2\((\d+), (\d+), (\d+), (\d+)\)', source.split('const FLOORS :=', 1)[1].split('\n', 1)[0])
    for level, values in enumerate(floors):
        x, y, width, height = map(int, values)
        art.RNG = random.Random(20261011 + level)
        image = art.canvas((640, max(480, y + height // 2 + 180)), '#211719')
        art.planks(image, (x, y, x + width - 1, y + height - 1), height=12, width=61)
        art.planks(image, (296, 416, 343, 475), height=12, width=48)
        draw = ImageDraw.Draw(image)
        for wall_x in range(x - 12, x + width + 12, 24):
            art.wood(draw, (wall_x, y - 48, min(wall_x + 23, x + width + 11), y - 1), vertical=True)
        art.wood(draw, (x - 12, y - 51, x + width + 11, y - 45))
        art.wood(draw, (x - 12, y - 5, x + width + 11, y + 1))
        for wall_x in (x - 12, x + width):
            art.wood(draw, (wall_x, y - 48, wall_x + 11, 427), vertical=True, shade=0)
        for left, right in ((x - 12, 295), (344, x + width + 11)):
            art.wood(draw, (left, 416, right, 427))
        for wall_x in (284, 344):
            art.wood(draw, (wall_x, 428, wall_x + 11, 479), vertical=True)
        # A structural window, with no furnishings, ornaments or floor coverings.
        art.panel(draw, (302, y - 40, 337, y - 9), art.P['deep'], highlight=art.P['gold'])
        draw.rectangle((306, y - 36, 333, y - 13), fill='#b4c3b1')
        draw.rectangle((306, y - 36, 333, y - 29), fill='#8ba8aa')
        draw.line((320, y - 36, 320, y - 13), fill=art.P['wood_light'], width=2)
        draw.line((306, y - 25, 333, y - 25), fill=art.P['wood_light'], width=2)
        art.save(image, 'home_empty_%d' % level)
        print('EMPTY HOME', level, (width, height), image.size)

    sign = art.canvas((32, 40))
    draw = ImageDraw.Draw(sign)
    art.wood(draw, (13, 14, 16, 37), vertical=True)
    draw.polygon([(3, 7), (24, 7), (29, 15), (24, 23), (3, 23)], fill=art.P['wood'], outline=art.P['deep'])
    draw.line((5, 8, 23, 8), fill=art.P['gold'])
    draw.line((5, 21, 23, 21), fill=art.P['grain'])
    # A chair silhouette identifies the furniture retailer without text.
    draw.rectangle((10, 10, 14, 16), fill=art.P['cream'])
    draw.rectangle((10, 16, 21, 18), fill=art.P['gold'])
    draw.line((11, 18, 11, 21), fill=art.P['cream'])
    draw.line((20, 18, 20, 21), fill=art.P['cream'])
    art.save(sign, 'outdoor_sign_furniture_store')


if __name__ == '__main__':
    build()
