"""Compose six explorable places from Hearthwood's native pixels. MyArt is read-only.

Ground, map preview, collision and gameplay all consume the same layout. No source
image is recoloured or overwritten. Run from any directory with Pillow installed.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import hashlib
import json
import math
import random
import struct
import zlib

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'Art/WorldPolish'
NATIVE = ROOT / 'Art/Environment/Hearthwood'


def hashes():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (ROOT / 'MyArt').rglob('*') if p.is_file()}


def aseprite(image):
    w, h = image.size
    name = b'Native terrain composition'
    layer = struct.pack('<HHHHHHB', 1, 0, 0, 0, 0, 0, 255) + bytes(3) + struct.pack('<H', len(name)) + name
    cel = struct.pack('<HhhBHh', 0, 0, 0, 255, 2, 0) + bytes(5) + struct.pack('<HH', w, h) + zlib.compress(image.convert('RGBA').tobytes())
    chunks = b''.join(struct.pack('<IH', len(v) + 6, t) + v for t, v in [(0x2004, layer), (0x2005, cel)])
    frame = struct.pack('<IHHHHI', len(chunks) + 16, 0xF1FA, 2, 140, 0, 0) + chunks
    header = bytearray(128)
    struct.pack_into('<IHHHHHIH', header, 0, 128 + len(frame), 0xA5E0, 1, w, h, 32, 1, 140)
    struct.pack_into('<HBBhhHH', header, 32, 0, 1, 1, 0, 0, w, h)
    return bytes(header) + frame


def spec(id, points, route, water, resources, props, landmark):
    return dict(id=id, size=[640, 360], spawn=[60, 280], exit=[24, 280],
                gather_points=points, routes=route, water=water,
                resources=resources, props=props, landmark=landmark,
                fishing={'position': [500, 210], 'anchor': [500, 232], 'water': [500, 178]})


def prop(kind, x, y, w=0, h=0):
    return dict(kind=kind, x=x, y=y, w=w, h=h, solid=w > 0)


# The lower return path and fishing approach remain consistent across places.
SPECS = [
    spec('grove', [[126, 162], [246, 124], [344, 188], [202, 242], [376, 286], [556, 282]],
         [[[24, 280], [106, 280], [174, 210], [246, 174], [342, 236], [500, 232], [566, 288]],
          [[174, 210], [126, 162]], [[246, 174], [246, 124]]],
         [[448, 112, 112, 80], [432, 128, 144, 48], [464, 96, 80, 112]],
         [[190, 278], [330, 278]],
         [prop('outdoor_log', 292, 164, 30, 12), prop('outdoor_fern', 400, 210),
          prop('outdoor_birch', 188, 128, 20, 14), prop('outdoor_flowerbed', 128, 218),
          prop('outdoor_bush', 418, 298, 28, 12)], [300, 156]),
    spec('quarry', [[124, 152], [230, 182], [346, 140], [390, 266], [554, 286], [156, 318]],
         [[[24, 280], [112, 280], [164, 220], [276, 220], [352, 188], [408, 232], [500, 232], [562, 288]],
          [[164, 220], [124, 152]], [[276, 220], [230, 182]], [[352, 188], [346, 140]]],
         [[448, 128, 128, 64], [464, 112, 96, 96]],
         [[218, 288], [348, 286]],
         [prop('outdoor_rock', 280, 162, 38, 20), prop('outdoor_ore', 402, 164, 24, 12),
          prop('outdoor_crates', 104, 218, 28, 16), prop('outdoor_barrel', 148, 230, 18, 14),
          prop('outdoor_rock', 588, 310, 38, 20)], [280, 160]),
    spec('marsh', [[126, 152], [250, 154], [348, 224], [206, 286], [418, 302], [560, 274]],
         [[[24, 280], [112, 280], [160, 232], [250, 232], [320, 272], [416, 272], [500, 232], [564, 274]],
          [[160, 232], [126, 152]], [[250, 232], [250, 154]], [[320, 272], [348, 224]]],
         [[80, 96, 480, 32], [160, 128, 48, 112], [288, 112, 32, 112],
          [384, 112, 64, 96], [448, 112, 128, 96]],
         [[192, 320], [366, 320]],
         [prop('outdoor_herbs', 364, 172), prop('outdoor_fern', 106, 190),
          prop('outdoor_bush', 582, 214, 28, 12), prop('outdoor_log', 410, 250, 30, 12)], [250, 154]),
    spec('ruins', [[126, 174], [236, 130], [350, 180], [224, 284], [400, 290], [566, 286]],
         [[[24, 280], [112, 280], [192, 220], [284, 220], [352, 250], [500, 232], [566, 286]],
          [[192, 220], [126, 174]], [[284, 220], [236, 130]], [[284, 220], [350, 180]]],
         [[448, 112, 128, 80], [464, 96, 96, 112]],
         [[168, 310], [334, 310]],
         [prop('outdoor_rock', 174, 156, 38, 20), prop('outdoor_rock', 300, 148, 38, 20),
          prop('outdoor_crates', 390, 210, 28, 16), prop('outdoor_fern', 260, 176),
          prop('outdoor_barrel', 412, 222, 18, 14)], [284, 148]),
    spec('ridge', [[126, 190], [232, 144], [346, 180], [212, 286], [402, 304], [558, 276]],
         [[[24, 280], [104, 280], [152, 232], [228, 232], [288, 192], [358, 232], [500, 232], [558, 276]],
          [[152, 232], [126, 190]], [[228, 232], [232, 144]], [[288, 192], [346, 180]]],
         [[448, 112, 128, 80], [464, 96, 96, 112]],
         [[184, 320], [336, 306]],
         [prop('outdoor_rock', 180, 184, 38, 20), prop('outdoor_rock', 306, 154, 38, 20),
          prop('outdoor_pine', 404, 182, 22, 14), prop('outdoor_ore', 412, 256, 24, 12)], [306, 152]),
    spec('observatory', [[126, 176], [236, 144], [354, 164], [216, 286], [394, 288], [560, 280]],
         [[[24, 280], [112, 280], [190, 224], [286, 224], [364, 244], [500, 232], [560, 280]],
          [[190, 224], [126, 176]], [[286, 224], [236, 144]], [[286, 224], [354, 164]]],
         [[448, 112, 128, 80], [464, 96, 96, 112]],
         [[170, 310], [338, 304]],
         [prop('outdoor_rock', 286, 146, 38, 20), prop('outdoor_lamp', 400, 218, 12, 10),
          prop('outdoor_lamp', 174, 206, 12, 10), prop('outdoor_flowerbed', 370, 124)], [286, 144]),
]


def compose(s, ordinal):
    rng = random.Random(880 + ordinal)
    native = Image.open(NATIVE / 'field_background.png').convert('RGBA')
    # Native unaltered grass swatches retain the shared environment palette.
    swatches = [native.crop((x, y, x + 16, y + 16)) for x, y in [(288, 72), (304, 72), (320, 72), (336, 72)]]
    dirt = [native.crop((x, 256, x + 16, 272)) for x in [112, 144, 176, 208]]
    ground = Image.new('RGBA', (640, 368))
    for y in range(0, 368, 16):
        for x in range(0, 640, 16): ground.alpha_composite(rng.choice(swatches), (x, y))
    p = ImageDraw.Draw(ground)
    rocky = s['id'] in ('quarry', 'ruins', 'ridge', 'observatory')
    # Material patches break up the map silhouette instead of covering it in noise.
    if rocky:
        for box in [(84, 102, 398, 196), (208, 152, 418, 232)]:
            p.rounded_rectangle(box, radius=28, fill='#8c8972' if s['id'] != 'ridge' else '#a0a296')
        for _ in range(130):
            x, y = rng.randrange(94, 400), rng.randrange(112, 222)
            p.line((x, y, x + rng.randrange(2, 6), y), fill='#b3ac8b')
    water_mask = Image.new('1', ground.size)
    wm = ImageDraw.Draw(water_mask)
    for x, y, w, h in s['water']: wm.rectangle((x, y, x+w-1, y+h-1), fill=1)
    # Broad paths form a legible loop. Marsh boardwalks cut crossings into water.
    path_mask = Image.new('1', ground.size)
    pm = ImageDraw.Draw(path_mask)
    for route in s['routes']:
        route = [tuple(point) for point in route]
        pm.line(route, fill=1, width=28)
        for x, y in route: pm.ellipse((x-14, y-14, x+14, y+14), fill=1)
    for y in range(56, 352):
        for x in range(8, 632):
            if water_mask.getpixel((x,y)):
                ground.putpixel((x,y), (87,131,132,255))
                if y%9 == 0 and (x + y*3)%29 < 8: ground.putpixel((x,y),(139,176,163,255))
            if path_mask.getpixel((x,y)):
                if s['id'] == 'marsh' and water_mask.getpixel((x,y)):
                    ground.putpixel((x,y), (121,93,62,255) if y%7 == 0 else (166,131,83,255))
                else:
                    ground.putpixel((x,y), dirt[(x//16+y//16)%4].getpixel((x%16,y%16)) if not rocky else (156,146,117,255))
                    if rocky and rng.randrange(130) == 0: ground.putpixel((x,y),(181,169,139,255))
    # Pixel banks use the occupancy mask; bridges have a visibly continuous deck.
    p = ImageDraw.Draw(ground)
    for y in range(56,352):
        for x in range(8,632):
            if water_mask.getpixel((x,y)) and not path_mask.getpixel((x,y)):
                if not water_mask.getpixel((x,y-1)): p.point((x,y),fill='#c0bb88')
                elif not water_mask.getpixel((x-1,y)): p.point((x,y),fill='#465f55')
    # Original small landmarks use the environment's pixel palette and do not
    # replace any authored source asset. Their footprints are part of this data.
    landmark_solids=[]
    if s['id']=='quarry':
        cx,cy=s['landmark']
        p.polygon([(cx-48,cy-8),(cx-48,cy-44),(cx-32,cy-64),(cx+26,cy-66),(cx+48,cy-44),(cx+48,cy-8)],fill='#69736a',outline='#46594d')
        p.rectangle((cx-25,cy-44,cx+25,cy-8),fill='#353e39')
        for x in [cx-31,cx+26]:
            p.rectangle((x,cy-45,x+6,cy-6),fill='#9b754c',outline='#544d3b')
            p.line((x+2,cy-42,x+2,cy-10),fill='#c09a62')
        p.rectangle((cx-35,cy-48,cx+35,cy-41),fill='#a18154',outline='#544d3b')
        p.line((cx-33,cy-47,cx+33,cy-47),fill='#c09a62')
        for x in [cx-12,cx+10]:p.line((x,cy-8,x+10,cy+12),fill='#5b6358',width=2)
        landmark_solids.append([cx-38,cy-12,76,10])
    elif s['id']=='ruins':
        cx,cy=s['landmark']
        for x,top in [(cx-58,cy-60),(cx-20,cy-70),(cx+20,cy-47)]:
            p.rectangle((x,top,x+19,cy-5),fill='#7a8579',outline='#46594d')
            p.line((x+3,top+2,x+3,cy-8),fill='#adb49a',width=2)
            for y in range(top+12,cy-5,12):p.line((x+1,y,x+18,y),fill='#535f53')
            p.rectangle((x-3,cy-7,x+23,cy-2),fill='#596b55')
            landmark_solids.append([x-3,cy-7,26,6])
        p.polygon([(cx-58,cy-63),(cx+2,cy-76),(cx+7,cy-66),(cx-56,cy-54)],fill='#89917e',outline='#46594d')
    elif s['id']=='observatory':
        cx,cy=s['landmark']
        p.ellipse((cx-69,cy-55,cx+69,cy+45),fill='#626e67',outline='#b1b79d',width=2)
        p.ellipse((cx-54,cy-43,cx+54,cy+32),outline='#b49f70',width=2)
        p.line((cx-62,cy-5,cx+62,cy-5),fill='#b49f70')
        p.line((cx,cy-50,cx,cy+40),fill='#b49f70')
        p.polygon([(cx,cy-32),(cx+7,cy-12),(cx+30,cy-5),(cx+7,cy+2),(cx,cy+23),(cx-7,cy+2),(cx-30,cy-5),(cx-7,cy-12)],fill='#c5b98a',outline='#46594d')
    elif s['id']=='ridge':
        cx, cy = s['landmark']
        for step in range(3):
            x, y = cx-52+step*6, cy-24-step*9
            p.rectangle((x,y,cx+52-step*6,y+8),fill='#626d68',outline='#4d5550')
            p.line((x+2,y,cx+50-step*6,y),fill='#b0b4a0')
            for seam in range(x+16,cx+50-step*6,16):p.line((seam,y+2,seam,y+6),fill='#4d5550')
        for x in range(96,382,40):
            p.rectangle((x,94,x+3,114),fill='#665641')
        p.line((98,99,378,99),fill='#bdab7c',width=2)
    # Water collision is made of exact horizontal cell runs, excluding bridges.
    solids = []
    for gy in range(4,22):
        start = None
        for gx in range(1,40):
            blocked = gx < 39 and bool(water_mask.getpixel((gx*16+8,gy*16+8))) and not bool(path_mask.getpixel((gx*16+8,gy*16+8)))
            if blocked and start is None: start = gx
            if not blocked and start is not None:
                solids.append([start*16, gy*16, (gx-start)*16, 16]); start=None
    s['solids'] = solids + landmark_solids
    # Different tree masses frame the same safe lower entrance.
    edge_kind = 'outdoor_birch' if s['id'] in ('grove','marsh') else 'outdoor_pine'
    for x,y in [(26,134),(72,104),(142,98),(422,96),(584,104),(620,152),(608,336)]:
        s['props'].append(prop(edge_kind,x,y,20,12))
    for x,y in [(44,224),(86,330),(288,340),(440,338),(584,326)]:
        s['props'].append(prop('outdoor_fern' if s['id'] in ('grove','marsh') else 'outdoor_rock',x,y))
    # Preview includes precisely the same feet-sorted native assets as the world.
    preview=ground.crop((0,0,640,360))
    preview_objects=list(s['props'])
    # Mutable resources are composited separately by the in-game map.
    preview_objects.append(prop('dock_fishing_post',500,210))
    for o in sorted(preview_objects,key=lambda v:v['y']):
        im=Image.open(NATIVE/(o['kind']+'.png')).convert('RGBA')
        preview.alpha_composite(im,(round(o['x']-im.width/2),round(o['y']-im.height)))
    s['ground']='res://Art/WorldPolish/'+s['id']+'_ground.aseprite'
    s['preview']='res://Art/WorldPolish/'+s['id']+'_preview.aseprite'
    (OUT/(s['id']+'_ground.aseprite')).write_bytes(aseprite(ground))
    (OUT/(s['id']+'_preview.aseprite')).write_bytes(aseprite(preview))
    ground.save(OUT/(s['id']+'_ground.png'))
    preview.save(OUT/(s['id']+'_preview.png'))
    (OUT/(s['id']+'.json')).write_text(json.dumps(s,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return preview


def main():
    original=hashes()
    OUT.mkdir(parents=True,exist_ok=True)
    previews=[compose(s,i) for i,s in enumerate(SPECS)]
    sheet=Image.new('RGB',(1280,1080),'#393d35')
    for i,im in enumerate(previews): sheet.paste(im,(i%2*640,i//2*360))
    sheet.save(OUT/'regions_overview.png')
    assert original==hashes(), 'Protected source hashes changed'
    (OUT/'manifest.json').write_text(json.dumps({'regions':[s['id'] for s in SPECS], 'protected_sources':original},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('WORLD POLISH: six native region compositions; protected sources unchanged')


if __name__=='__main__': main()
