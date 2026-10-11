"""Check both ends of each outdoor road, including the actual raster edge."""
import json
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parents[1]
town = json.loads((OUT / "town_layout.json").read_text(encoding="utf-8"))
connections = [("farm", "stone", 52, "left", "right"),
               ("field", "dirt", 34, "top", "bottom"),
               ("dock", "wood", 42, "right", "left")]


def road_at(layout, point, surface, width):
    x, y = point
    for route in layout["paths"]:
        if route["surface"] != surface or route["width"] != width:
            continue
        for (ax, ay), (bx, by) in zip(route["points"], route["points"][1:]):
            dx, dy = bx-ax, by-ay
            t = max(0, min(1, ((x-ax)*dx+(y-ay)*dy)/(dx*dx+dy*dy)))
            if (x-ax-t*dx)**2 + (y-ay-t*dy)**2 <= (width/2)**2:
                return True
    return False


def edge_point(layout, gate, edge):
    w, h = layout["size"]
    x, y = gate
    return {"left": (0, y), "right": (w-1, y),
            "top": (x, 0), "bottom": (x, h-1)}[edge]


for region, surface, width, source_edge, target_edge in connections:
    other = json.loads((OUT / (region + "_layout.json")).read_text(encoding="utf-8"))
    for layout, gate, edge, name in [(town, town["gates"][region], source_edge, "town"),
                                     (other, other["exit"], target_edge, region)]:
        point = edge_point(layout, gate, edge)
        assert road_at(layout, point, surface, width), (name, "road stops before edge")
        assert road_at(layout, gate, surface, width), (name, "gate is off road")
        file = "field_background.png" if name == "field" else name + "_ground.png"
        with Image.open(OUT / file).convert("RGB") as image:
            # Every pixel across the exit stays on the road, never grass/water.
            for offset in range(-width//2 + 2, width//2 - 1):
                x, y = point
                x, y = (x, y+offset) if edge in ("left", "right") else (x+offset, y)
                r, g, b = image.getpixel((x, y))
                assert r > g and r > b, (name, "broken raster edge", x, y, (r, g, b))
    assert road_at(other, other["spawn"], surface, width), (region, "arrival is off road")
    print("ROAD CONNECTION PASS", region, surface, width, "pixels, opposing edges and arrival")
