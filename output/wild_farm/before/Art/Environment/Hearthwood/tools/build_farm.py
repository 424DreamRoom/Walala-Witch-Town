"""Moonbud farm, using Hearthwood's native palette and existing house/props."""
import json
import random
from PIL import Image, ImageDraw
import build_art as art

OUT = art.OUT
SEED = 11102026


def build():
    rng = random.Random(SEED)
    im = art.canvas((960, 720), "#71845e")
    d = ImageDraw.Draw(im)
    for box, color in [((38, 48, 490, 316), "#7d8d63"), ((610, 110, 932, 692), "#637d57"),
                       ((62, 330, 635, 682), "#7a8860")]:
        d.ellipse(box, fill=color)
    for _ in range(11000):
        x, y = rng.randrange(960), rng.randrange(720)
        d.line((x, y, x + rng.randrange(1, 4), y), fill=rng.choice(["#627953", "#87956b", "#728760", "#96a175"]))
    paths = [dict(points=[[270, 276], [270, 324], [820, 324]], width=36, surface="dirt"),
             dict(points=[[620, 324], [620, 652], [176, 652]], width=28, surface="dirt"),
             dict(points=[[620, 540], [700, 540], [700, 572]], width=28, surface="dirt"),
             # The eastern apron matches the town's 52px stone road.
             dict(points=[[820, 324], [884, 364], [992, 364]], width=52, surface="stone")]
    mask = Image.new("L", im.size)
    md = ImageDraw.Draw(mask)
    for item in paths:
        points = [tuple(p) for p in item["points"]]
        md.line(points, fill=255, width=item["width"], joint="curve")
        for x, y in points:
            r = item["width"] // 2
            md.ellipse((x-r, y-r, x+r, y+r), fill=255)
    dirt = art.canvas(im.size, "#b3a07b")
    dd = ImageDraw.Draw(dirt)
    for _ in range(14000):
        x, y = rng.randrange(960), rng.randrange(720)
        dd.line((x, y, x+2, y), fill=rng.choice(["#c3af84", "#a9946c", "#baa67d"]))
    im.paste(dirt, (0, 0), mask)
    stone_mask = Image.new("L", im.size)
    sd = ImageDraw.Draw(stone_mask)
    points = [tuple(p) for p in paths[-1]["points"]]
    sd.line(points, fill=255, width=52, joint="curve")
    for x, y in points:
        sd.ellipse((x-26, y-26, x+26, y+26), fill=255)
    stone = art.canvas(im.size, "#b3a07b")
    sd = ImageDraw.Draw(stone)
    for y in range(0, 720, 10):
        for x in range(-8 if (y // 10) % 2 else 0, 960, 17):
            sd.rectangle((x, y, x+15, y+8), fill=rng.choice(["#b6a481", "#bfae88", "#ae9d7c", "#c7b591", "#a9a184"]))
            sd.line((x+1, y+1, x+14, y+1), fill="#d0bd96")
            sd.line((x+1, y+8, x+15, y+8), fill="#958769")
    im.paste(stone, (0, 0), stone_mask)
    d = ImageDraw.Draw(im)
    # A single broad, unworked field: individual tiles appear only when tilled.
    d.rectangle((184, 360, 583, 631), fill="#8d8059", outline="#5b6242", width=2)
    d.rectangle((192, 368, 575, 623), fill="#a08d65")
    for _ in range(1700):
        x, y = rng.randrange(194, 574), rng.randrange(370, 622)
        d.point((x, y), fill=rng.choice(["#b09b70", "#94805d", "#aa9369"]))
    # Pond and an accessible southern refill ledge.
    d.ellipse((688, 438, 858, 564), fill="#526c50", outline="#b7ad7d", width=3)
    d.ellipse((696, 446, 850, 556), fill="#638b88", outline="#354b4b", width=2)
    for _ in range(110):
        x, y = rng.randrange(712, 830), rng.randrange(463, 536)
        d.line((x, y, x+rng.randrange(3, 10), y), fill=rng.choice(["#84aaa0", "#749d96", "#a3beb0"]))
    d.rectangle((756, 550, 790, 575), fill="#ad9976", outline="#756d51")
    for y in range(554, 575, 7):
        d.line((758, y, 787, y), fill="#c7b591")
    for y in range(252, 293, 8):
        d.rounded_rectangle((254, y, 286, y+5), radius=2, fill=art.P["stone_light"], outline=art.P["stone"])
    art.save(im, "farm_ground")
    props = []

    def add(kind, x, y, w=0, h=0):
        props.append(dict(kind="outdoor_"+kind, x=x, y=y, w=w, h=h, solid=w > 0))

    for x, y, kind in [(75, 142, "birch"), (92, 274, "pine"), (82, 448, "birch"), (92, 622, "pine"),
                       (458, 138, "pine"), (558, 170, "birch"), (686, 132, "pine"), (834, 186, "birch"),
                       (884, 434, "pine"), (878, 644, "birch"), (686, 682, "pine")]:
        add(kind, x, y, 10, 8)
    for x in range(166, 587, 60):
        add("fence", x, 344, 60, 5)
    for spec in [("mailbox", 166, 288, 12, 6), ("flowerbed", 370, 290, 0, 0),
                 ("well", 480, 292, 26, 18), ("bench", 766, 270, 50, 12),
                 ("lamp", 388, 305, 8, 6), ("lamp", 884, 330, 8, 6),
                 ("crates", 638, 238, 34, 12), ("barrel", 676, 238, 22, 12),
                 ("flowerbed", 712, 286, 0, 0), ("herbs", 820, 594, 0, 0),
                 ("bush", 122, 520, 0, 0), ("fern", 852, 550, 0, 0)]:
        add(*spec)
    # Keep the path from the front door to the field free through the fence.
    props = [p for p in props if not (p["kind"] == "outdoor_fence" and 220 <= p["x"] <= 300)]
    layout = dict(size=[960, 720], spawn=[918, 364], home=[270, 276], exit=[952, 364],
                  refill=[774, 580], well=[480, 310], plots=[192, 368, 12, 8, 32], paths=paths,
                  buildings=[dict(kind="shop_0", x=270, y=250, w=160, h=96, role="witch_home")],
                  props=props, water=[[708, 452, 128, 98]])
    (OUT / "farm_layout.json").write_text(json.dumps(layout, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    art.compose(layout["buildings"]+props, "farm_ground", "farm_overview")
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for name in ("farm_ground.png", "farm_overview.png"):
        manifest.setdefault("assets", {})[name] = [960, 720]
    manifest["farm"] = dict(size=[960, 720], plantable_tiles=96, crop="herb", growth_days=3,
                            house="shop_0.png, relocated from town", seed=SEED,
                            rebuild="python Art/Environment/Hearthwood/tools/build_farm.py")
    manifest_path.write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    print("FARM BUILT: 960x720, relocated house, 96 plantable tiles, pond and well")


if __name__ == "__main__":
    build()
