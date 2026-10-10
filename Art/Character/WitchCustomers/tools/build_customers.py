"""Native 16x24 customer pixel authoring. No reference image is resized or sampled."""
from pathlib import Path
import json, struct, sys, zlib
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT
LAYERS = ["Shoes", "Outfit", "Hair", "Hat", "Details"]
CUSTOMERS = [
    ("green_braids", "绿帽棕辫", "3f8f65", "7b4b35", "c88f58", "6f9b68"),
    ("blue_blonde", "蓝帽浅金", "4774b5", "e7c879", "e8b97d", "6d82b5"),
    ("burgundy_curls", "酒红帽深卷发", "8d3f55", "30243a", "9c5a48", "8d5367"),
    ("orange_short", "橙帽黑短发", "d77a3d", "252936", "c27f68", "b86b43"),
    ("cyan_gray", "青帽灰发", "3da9a3", "9aa5ad", "d4a27a", "5c8790"),
    ("pink_longblue", "粉帽深蓝长发", "d56e9b", "273d73", "c58d70", "9c6b9d"),
]

def rgba(hexv): return tuple(bytes.fromhex(hexv)) + (255,)
def chunk(kind,payload): return struct.pack('<IH',len(payload)+6,kind)+payload

def author(variant, frame):
    hat, hair, skin, outfit = [rgba(x) for x in CUSTOMERS[variant][2:]]
    layers=[Image.new('RGBA',(16,24)) for _ in LAYERS]
    def p(li,x,y,c):
        if 0<=x<16 and 0<=y<24: layers[li].putpixel((x,y),c)
    # Layered silhouette: hat, hair silhouette, apron/outfit, shoes, tiny eating prop.
    bob = 0 if frame < 2 else (-1 if frame in (2,4) else 0)
    # shoes
    for x in (5,9):
        for y,c in [(21,(45,35,48,255)),(22,(73,53,61,255))]: p(0,x,y,c); p(0,x+1,y,c)
    # outfit / apron varies per character
    for y in range(15+bob,21+bob):
        width = 3 if y < 17+bob else 5
        for x in range(8-width//2,8+width//2+1): p(1,x,y,outfit)
    p(1,7,17+bob,(245,221,170,255)); p(1,8,17+bob,(245,221,170,255)); p(1,9,17+bob,(245,221,170,255))
    if variant in (0,4): p(1,6,19+bob,(245,221,170,255)); p(1,10,19+bob,(245,221,170,255))
    # hair and face, with distinct silhouettes
    if variant == 0: # braids
        for y in range(10+bob,17+bob): p(2,5,y,hair); p(2,10,y,hair)
        p(2,4,15+bob,hair); p(2,11,15+bob,hair)
    elif variant == 1: # light bob
        for y in range(9+bob,14+bob):
            for x in range(5,11): p(2,x,y,hair)
        p(2,5,14+bob,hair); p(2,10,14+bob,hair)
    elif variant == 2: # curls
        for x,y in [(4,10),(5,9),(10,9),(11,10),(4,12),(11,12),(5,14),(10,14)]: p(2,x,y,hair)
    elif variant == 3: # short
        for x in range(5,11): p(2,x,10+bob,hair)
        for x in (5,10): p(2,x,11+bob,hair)
    elif variant == 4: # gray side locks
        for y in range(9+bob,16+bob): p(2,5,y,hair); p(2,10,y,hair)
        for x in range(6,10): p(2,x,9+bob,hair)
    else: # long dark blue
        for y in range(9+bob,19+bob): p(2,5,y,hair); p(2,10,y,hair)
        for x in range(6,10): p(2,x,9+bob,hair)
    # face
    for x in range(6,10):
        for y in range(11+bob,15+bob): p(2,x,y,skin)
    p(4,6,13+bob,(50,38,46,255)); p(4,9,13+bob,(50,38,46,255))
    # hat with variant-specific brim/crown
    for x in range(3,13): p(3,x,8+bob,hat)
    for x in range(5,11): p(3,x,7+bob,hat)
    for x in range(6,10): p(3,x,6+bob,hat)
    p(3,7,5+bob,hat); p(3,8,4+bob,hat); p(3,9,5+bob,hat)
    if variant == 0: p(3,11,7+bob,(226,208,119,255))
    elif variant == 1: p(3,6,7+bob,(210,227,244,255))
    elif variant == 2: p(3,9,6+bob,(240,185,112,255))
    elif variant == 3: p(3,5,8+bob,(247,194,85,255))
    elif variant == 4: p(3,10,7+bob,(227,238,208,255))
    else: p(3,6,8+bob,(250,188,220,255))
    # simple eating animation: spoon/cup near face, hand changes per frame
    if frame >= 2:
        handx = 10 if frame in (2,4) else 6
        p(4,handx,16+bob,(245,221,170,255)); p(4,handx,15+bob,(245,221,170,255))
        p(4,handx-1 if handx==10 else handx+1,14+bob,(247,231,178,255))
    return layers

def aseprite(frames,tags):
    output=[]
    for fi,layers in enumerate(frames):
        chunks=[]
        if fi==0:
            for name in LAYERS:
                s=name.encode(); chunks.append(chunk(0x2004,struct.pack('<HHHHHHB',1,0,0,0,0,0,255)+bytes(3)+struct.pack('<H',len(s))+s))
            payload=struct.pack('<H',len(tags))+bytes(8)
            for tag in tags:
                s=tag['name'].encode(); payload+=struct.pack('<HHBH',tag['from'],tag['to'],0,0)+bytes(6)+bytes((136,97,170,0))+struct.pack('<H',len(s))+s
            chunks.append(chunk(0x2018,payload))
        for li,im in enumerate(layers):
            payload=struct.pack('<HhhBHh',li,0,0,255,2,0)+bytes(5)+struct.pack('<HH',16,24)+zlib.compress(im.tobytes())
            chunks.append(chunk(0x2005,payload))
        body=b''.join(chunks); duration=400 if fi<2 else 180
        output.append(struct.pack('<IHHHHI',len(body)+16,0xF1FA,len(chunks),duration,0,0)+body)
    header=bytearray(128); struct.pack_into('<IHHHHHIH',header,0,128+sum(map(len,output)),0xA5E0,len(frames),16,24,32,1,100); struct.pack_into('<HBBhhHH',header,32,0,1,1,0,0,16,24)
    return bytes(header)+b''.join(output)

def main():
    all_sheet=Image.new('RGBA',(16*6,24*6)); preview=Image.new('RGB',(16*8*6,24*8*6),'#302d3b'); d=ImageDraw.Draw(preview)
    manifest=[]
    for v,(slug,label,*_) in enumerate(CUSTOMERS):
        frames=[]; sheet=Image.new('RGBA',(96,144)); tags=[{'name':'idle','from':0,'to':1},{'name':'eat','from':2,'to':5}]
        for f in range(6):
            layers=author(v,f); comp=Image.new('RGBA',(16,24))
            for im in layers: comp=Image.alpha_composite(comp,im)
            frames.append(layers); sheet.paste(comp,((f%6)*16,(f//6)*24)); all_sheet.paste(comp,(f*16,v*24))
            tile=comp.resize((128,192),Image.Resampling.NEAREST); preview.paste(tile,(f*128,v*192),tile)
        sheet.save(OUT/(slug+'.png')); (OUT/(slug+'.aseprite')).write_bytes(aseprite(frames,tags))
        manifest.append({'id':v,'slug':slug,'label':label,'frames':6,'frame_size':[16,24],'tags':tags,'layers':LAYERS})
    all_sheet.save(OUT/'witch_customers_all.png'); preview.save(OUT/'preview_nearest_8x.png')
    (OUT/'customers.json').write_text(json.dumps({'frame_size':[16,24],'variants':manifest,'reference':'media-generation visual reference only; native pixel authoring'},ensure_ascii=False,indent=2)+'\n')
    print('Created 6 variants, 36 native 16x24 frames, layered Aseprite sources, sheets and previews.')
if __name__=='__main__': main()
