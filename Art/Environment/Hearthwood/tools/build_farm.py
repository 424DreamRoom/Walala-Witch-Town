"""Overgrown 1440x960 homestead. Exports never target source art."""
import json
import random
from collections import Counter
from PIL import ImageDraw
import build_art as art

OUT = art.OUT
SEED = 11102026
SIZE = (1440, 960)
TILE = 32
COLUMNS, ROWS = 43, 29


def build():
    rng = random.Random(SEED)
    im = art.canvas(SIZE, "#71845e")
    d = ImageDraw.Draw(im)
    for box, color in [((38, 48, 490, 316), "#7d8d63"), ((610, 110, 1390, 910), "#637d57"),
                       ((62, 330, 790, 942), "#7a8860")]:
        d.ellipse(box, fill=color)
    for _ in range(22000):
        x, y = rng.randrange(SIZE[0]), rng.randrange(SIZE[1])
        d.line((x, y, x + rng.randrange(1, 4), y), fill=rng.choice(["#627953", "#87956b", "#728760", "#96a175"]))
    # Only the town-side stone apron and original doorstep remain built.
    paths = [dict(points=[[1328, 364], [1472, 364]], width=52, surface="stone")]
    # Mortar stays on the road surface; grass must not show through brick gaps.
    d.rectangle((1328, 338, 1472, 390), fill="#b3a07b")
    for y in range(339, 390, 10):
        for x in range(1320 - (8 if (y // 10) % 2 else 0), 1440, 17):
            if x + 15 < 1328:
                continue
            d.rectangle((max(1328, x), y, x + 15, min(y + 8, 390)), fill=rng.choice(["#b6a481", "#bfae88", "#ae9d7c", "#c7b591"]))
            d.line((max(1328, x + 1), y + 1, x + 14, y + 1), fill="#d0bd96")
    for y in range(252, 293, 8):
        d.rounded_rectangle((254, y, 286, y + 5), radius=2, fill=art.P["stone_light"], outline=art.P["stone"])
    art.save(im, "farm_ground")

    # IDs 0..95 retain their original world positions for existing saves.
    cells = [(5 + i % 12, 11 + i // 12) for i in range(96)]
    cells += [(x, y) for y in range(ROWS) for x in range(COLUMNS) if not (5 <= x < 17 and 11 <= y < 19)]
    indices = {cell: index for index, cell in enumerate(cells)}
    props, occupied = [], set()
    house = (166, 50, 398, 298)
    corridor = [(270, 276), (270, 324), (1296, 324), (1376, 364), (1456, 364)]

    def intersects(a, b):
        return a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]

    def distance_to_segment(x, y, a, b):
        dx, dy = b[0] - a[0], b[1] - a[1]
        t = max(0, min(1, ((x - a[0]) * dx + (y - a[1]) * dy) / (dx * dx + dy * dy)))
        return ((x - a[0] - t * dx) ** 2 + (y - a[1] - t * dy) ** 2) ** 0.5

    def add(kind, cell, resource_type):
        x, y = 48 + cell[0] * TILE, 40 + cell[1] * TILE
        tree = kind in ("outdoor_pine", "outdoor_birch")
        roots = (x - 24, y - 38, x + 24, y + 8) if tree else (x - 15, y - 28, x + 15, y + 2)
        if intersects(roots, house) or any(distance_to_segment(x, y, a, b) < (60 if tree else 42) for a, b in zip(corridor, corridor[1:])):
            return
        blocked = [index for index, (cx, cy) in enumerate(cells)
                   if intersects(roots, (32 + cx * TILE, 16 + cy * TILE, 64 + cx * TILE, 48 + cy * TILE))]
        if occupied.intersection(blocked):
            return
        occupied.update(blocked)
        w, h = (14, 12) if tree else (28, 16) if resource_type == "ore" else (18, 12)
        props.append(dict(kind=kind, x=x, y=y, w=w, h=h, solid=True,
                          resource_id="farm_%s_%d" % (resource_type, indices[cell]),
                          resource_type=resource_type, tiles=blocked, anchor=[x, y + 18]))

    for cy in range(3, ROWS - 1, 3):
        for cx in range(1, COLUMNS - 1, 3):
            if rng.random() < 0.86:
                add(rng.choice(["outdoor_birch", "outdoor_pine"]), (cx + rng.randrange(2), min(ROWS - 1, cy + rng.randrange(3))), "wood")
    candidates = cells.copy()
    rng.shuffle(candidates)
    for cell in candidates:
        if rng.random() < 0.10:
            add("outdoor_rock", cell, "ore")
    for cell in candidates:
        if rng.random() < 0.52:
            add(rng.choice(["outdoor_bush", "outdoor_fern"]), cell, "weed")
    layout = dict(size=list(SIZE), spawn=[1398, 364], home=[270, 276], exit=[1432, 364],
                  refill=[366, 276], plots=[32, 16, COLUMNS, ROWS, TILE], paths=paths,
                  clearance_routes=[dict(points=corridor, width=52)], lights=[[276, 218]],
                  unplantable=[[174, 58, 192, 208]],
                  buildings=[dict(kind="shop_0", x=270, y=250, w=160, h=96, role="witch_home")],
                  props=props, water=[])
    (OUT / "farm_layout.json").write_text(json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    art.compose(layout["buildings"] + props, "farm_ground", "farm_overview")
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for name in ("farm_ground.png", "farm_overview.png"):
        manifest.setdefault("assets", {})[name] = list(SIZE)
    manifest["farm"] = dict(size=list(SIZE), plantable_tiles=len(cells), crop="herb", growth_days=3,
                            house="shop_0.png, relocated from town", seed=SEED, initial_state="overgrown",
                            obstacles=dict(Counter(item["resource_type"] for item in props)),
                            tile_ids="0..95 preserve the old field; remaining cells follow row order",
                            rebuild="python Art/Environment/Hearthwood/tools/build_farm.py")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("FARM BUILT: 1440x960, house only, freely tillable land, obstacles", manifest["farm"]["obstacles"])


if __name__ == "__main__":
    build()
