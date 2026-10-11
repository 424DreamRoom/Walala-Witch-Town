"""Extend the project's native pixel authoring; export real layered Aseprite sources."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import random
import struct
import zlib
from PIL import Image, ImageDraw, ImageColor

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
D = json.loads((ROOT/'Scenes/Campaign/content.json').read_text(encoding='utf-8'))
INK='#4d354e'
CREAM='#fff0d5'
GREEN='#65896a'
manifest={}


def shade(color, factor):
    return tuple(max(0,min(255,round(v*factor))) for v in ImageColor.getrgb('#'+color.lstrip('#')))+(255,)


def chunk(kind, payload):
    return struct.pack('<IH',len(payload)+6,kind)+payload


def aseprite(layers, tags=None):
    """RGBA compressed cels, named visible layers and animation tags, Aseprite 1.3."""
    frames=len(layers[0][1]); w,h=layers[0][1][0].size
    result=[]
    for frame in range(frames):
        chunks=[]
        if frame==0:
            for name,images in layers:
                encoded=name.encode('utf-8')
                chunks.append(chunk(0x2004,struct.pack('<HHHHHHB',1,0,0,0,0,0,255)+bytes(3)+struct.pack('<H',len(encoded))+encoded))
            if tags:
                data=struct.pack('<H',len(tags))+bytes(8)
                for name,start,end in tags:
                    name=name.encode()
                    data+=struct.pack('<HHBH',start,end,0,0)+bytes(6)+bytes((160,128,183,0))+struct.pack('<H',len(name))+name
                chunks.append(chunk(0x2018,data))
        for index,(name,images) in enumerate(layers):
            payload=struct.pack('<HhhBHh',index,0,0,255,2,0)+bytes(5)+struct.pack('<HH',w,h)+zlib.compress(images[frame].convert('RGBA').tobytes())
            chunks.append(chunk(0x2005,payload))
        body=b''.join(chunks)
        result.append(struct.pack('<IHHHHI',len(body)+16,0xF1FA,len(chunks),140,0,0)+body)
    header=bytearray(128)
    struct.pack_into('<IHHHHHIH',header,0,128+sum(map(len,result)),0xA5E0,frames,w,h,32,1,140)
    struct.pack_into('<HBBhhHH',header,32,0,1,1,0,0,w,h)
    return bytes(header)+b''.join(result)


def save(id, layers, folder='icons', tags=None):
    dest=OUT/folder; dest.mkdir(parents=True,exist_ok=True)
    frames=[]
    for frame in range(len(layers[0][1])):
        im=Image.new('RGBA',layers[0][1][frame].size)
        for _,images in layers: im.alpha_composite(images[frame])
        frames.append(im)
    sheet=Image.new('RGBA',(frames[0].width*len(frames),frames[0].height))
    for i,im in enumerate(frames): sheet.alpha_composite(im,(i*im.width,0))
    sheet.save(dest/(id+'.png'))
    (dest/(id+'.aseprite')).write_bytes(aseprite(layers,tags))
    manifest[folder+'/'+id]={'size':list(frames[0].size),'frames':len(frames),'layers':[x[0] for x in layers],'tags':tags or [],'sha256':hashlib.sha256((dest/(id+'.png')).read_bytes()).hexdigest()}
    return sheet


def icon(item, seed=False):
    shadow=Image.new('RGBA',(32,32)); p=ImageDraw.Draw(shadow); p.ellipse((5,25,27,29),fill=(58,43,62,65))
    art=Image.new('RGBA',(32,32)); p=ImageDraw.Draw(art)
    color='#'+item['color'].lstrip('#'); dark=shade(color,.7); light=shade(color,1.18)
    shape=item['shape']
    if seed or shape=='bag':
        p.polygon([(8,6),(23,6),(22,10),(26,26),(6,26),(10,10)],fill=color,outline=INK)
        p.line((10,10,22,10),fill=dark,width=2)
        p.rectangle((11,15,21,22),fill=CREAM,outline=dark)
        p.ellipse((14,17,18,20),fill=GREEN)
    elif shape in ('leaf','flower','grain','corn','pod'):
        p.line((16,27,16,9),fill=INK,width=3);p.line((16,26,16,9),fill=GREEN,width=1)
        for y in (12,18,23):
            for side in (-1,1):
                x=16+side*7;p.polygon([(16,y+3),(x,y),(x,y-4),(16,y)],fill=color,outline=INK)
        if shape=='flower':
            p.ellipse((9,4,22,15),fill=color,outline=INK);p.ellipse((14,7,18,11),fill=CREAM)
        if shape in ('grain','corn'):
            p.rounded_rectangle((12,5,20,21),radius=3,fill=color,outline=INK)
            for y in (8,12,16):p.line((14,y,18,y),fill=dark)
    elif shape in ('round','root','pumpkin','carrot','long','pepper','berry'):
        box=(8,10,25,26) if shape not in ('carrot','long','pepper') else (12,8,22,28)
        if shape=='carrot':p.polygon([(9,9),(23,9),(16,29)],fill=color,outline=INK)
        else:p.ellipse(box,fill=color,outline=INK)
        p.line((16,11,18,4),fill=INK,width=3);p.line((17,8,24,5),fill=GREEN,width=3)
        p.line((10,16,12,13),fill=light,width=2)
        if shape=='pumpkin':
            for x in (13,18,22):p.arc((x-4,11,x+3,25),270,90,fill=dark)
        if shape=='berry':
            for x,y in ((12,17),(18,20),(22,16)):p.point((x,y),fill=CREAM)
    elif shape=='mushroom':
        p.rectangle((12,16,20,27),fill=CREAM,outline=INK);p.pieslice((4,4,28,26),180,360,fill=color,outline=INK)
        p.ellipse((10,10,13,12),fill=light);p.ellipse((21,12,24,14),fill=light)
    elif shape=='fish':
        p.polygon([(5,15),(1,9),(1,23),(7,19)],fill=dark,outline=INK)
        p.ellipse((5,9,29,23),fill=color,outline=INK);p.line((12,10,17,5,21,10),fill=dark,width=2)
        p.point((25,14),fill=INK);p.line((10,14,18,14),fill=light,width=2)
    elif shape in ('bottle','jar','cup'):
        p.rounded_rectangle((8,10,24,27),radius=3,fill=color,outline=INK)
        p.rectangle((11,4,21,11),fill=color,outline=INK);p.rectangle((11,4,21,6),fill=dark)
        p.rectangle((12,15,21,21),fill=CREAM);p.line((10,13,10,23),fill=light)
    elif shape in ('plate','soup','pie'):
        p.ellipse((3,10,29,28),fill=INK);p.ellipse((4,9,28,25),fill=CREAM)
        p.ellipse((8,11,25,22),fill=color,outline=dark)
        if shape=='pie':
            for x in (10,15,20):p.line((x,12,x+2,21),fill=light,width=2)
        else:
            for x,y in ((12,15),(19,18),(21,13)):p.rectangle((x,y,x+2,y+2),fill=GREEN)
            p.line((13,7,12,4,14,2),fill='#c3b4c7');p.line((21,7,20,4),fill='#c3b4c7')
    elif shape=='egg':p.ellipse((9,4,23,27),fill=color,outline=INK);p.arc((11,6,22,24),90,210,fill=light,width=2)
    elif shape in ('log','bar'):
        p.polygon([(5,12),(21,7),(28,13),(12,20),(5,17)],fill=color,outline=INK);p.polygon([(12,20),(28,13),(28,22),(12,28)],fill=dark,outline=INK)
    elif shape=='gear':
        for a in range(8):
            x=16+int(math.cos(a*math.pi/4)*10);y=16+int(math.sin(a*math.pi/4)*10);p.rectangle((x-3,y-3,x+3,y+3),fill=color,outline=INK)
        p.ellipse((7,7,25,25),fill=color,outline=INK);p.ellipse((12,12,20,20),fill=dark,outline=INK)
    else:
        p.polygon([(8,24),(6,15),(15,3),(25,10),(27,23),(18,28)],fill=color,outline=INK);p.line((15,4,18,26,25,11),fill=light,width=2)
    highlights=Image.new('RGBA',(32,32));q=ImageDraw.Draw(highlights);q.point((7,25),fill=CREAM)
    return [('shadow',[shadow]),('outline-and-paint',[art]),('highlights',[highlights])]


def dish_art(recipe, index):
    """Distinct dish silhouettes and ingredient colors, rather than recolored menu placeholders."""
    shadow=Image.new('RGBA',(32,32));ImageDraw.Draw(shadow).ellipse((3,25,29,29),fill=(58,43,62,55))
    im=Image.new('RGBA',(32,32));p=ImageDraw.Draw(im)
    colors=[D['items'][id]['color'] for id in recipe['cost']]
    main='#'+colors[0]
    sweet=index in (1,6,14,19,21,25,35)
    drink=index in (9,26,27)
    soup=index in (0,2,3,5,7,10,11,15,18,20,22,23,24,28,30)
    if drink:
        p.rounded_rectangle((7,9,24,26),radius=3,fill=CREAM,outline=INK)
        p.arc((20,12,30,23),270,90,fill=INK,width=2)
        p.ellipse((7,7,24,14),fill=main,outline=INK)
        p.line((12,5,11,2,13,0),fill='#bba9bc')
        if index==9:p.rectangle((9,15,22,22),fill='#dfacc0');p.line((20,8,23,1),fill=GREEN,width=2)
        if index==27:p.polygon([(11,10),(15,8),(18,11),(14,13)],fill='#edc86d')
    elif sweet:
        p.ellipse((3,22,29,28),fill=CREAM,outline=INK)
        if index in (1,6):
            p.ellipse((5,10,27,24),fill='#cba271',outline=INK);p.ellipse((8,12,24,21),fill=main)
            if index==1:
                for x in (9,15,21):p.line((x,12,x+3,21),fill='#edd2a3',width=2)
            else:
                for x,y in ((10,14),(17,12),(20,17)):p.polygon([(x,y),(x+4,y),(x+2,y+5)],fill='#de7589',outline=INK)
        elif index==21:
            p.rounded_rectangle((5,10,28,24),radius=6,fill='#dcb178',outline=INK)
            for x in (10,16,22):p.line((x,12,x-2,18),fill='#f0d6a4',width=2)
        elif index==19:
            p.ellipse((6,11,27,24),fill='#ba7d8a',outline=INK);p.ellipse((13,11,26,23),fill='#e8c28a',outline=INK)
        elif index==14:
            p.polygon([(8,16),(25,16),(20,26),(13,26)],fill='#b8c9cd',outline=INK)
            for x,y in ((12,12),(20,11),(17,6)):p.ellipse((x-5,y-5,x+5,y+5),fill='#d5d39a',outline=INK)
            p.line((21,5,24,1),fill=GREEN,width=2)
        else:
            p.rectangle((7,12,26,24),fill='#b69acc',outline=INK)
            p.rectangle((8,16,25,18),fill=CREAM);p.ellipse((7,7,26,16),fill='#e0c7db',outline=INK)
            for x,y in ((12,9),(20,10),(17,5)):p.ellipse((x-2,y-2,x+2,y+2),fill=main,outline=INK)
            if index==35:p.line((17,7,17,2),fill=INK);p.ellipse((16,0,18,3),fill='#f3ce82')
    else:
        p.ellipse((2,12,30,28),fill=INK);p.ellipse((3,11,29,25),fill='#e9dfc9',outline=INK)
        if soup:
            p.pieslice((4,13,28,31),0,180,fill='#ad8e8d',outline=INK)
            p.ellipse((5,11,27,22),fill=main,outline=INK)
            p.line((11,8,10,5,12,2),fill='#b5a5b6');p.line((21,8,20,4),fill='#b5a5b6')
        # Food toppings encode each recipe's actual ingredients.
        if index in (5,7,15,20,30):
            p.ellipse((7,12,26,22),fill='#eee0b9')
            for x,y in ((10,15),(14,19),(21,17),(17,14)):p.line((x,y,x+2,y),fill='#c9b88e')
        if index in (10,22):
            for y in (14,17,20):p.arc((8,y-2,26,y+3),0,290,fill='#efcd8d',width=2)
        if index in (13,29,31,32,33):
            fishcolor=['#b7c7ce','#9eafc5','#d8afc4','#bdd9e6','#dcbd8e'][(13,29,31,32,33).index(index)]
            p.polygon([(8,17),(4,12),(4,23),(10,20)],fill=fishcolor,outline=INK);p.ellipse((8,12,27,23),fill=fishcolor,outline=INK)
            p.point((24,16),fill=INK)
            for x in (13,17,21):p.line((x,15,x-1,20),fill='#786a78')
        elif index==12:
            for x,y in ((9,16),(17,20),(24,15)):
                p.ellipse((x-5,y-4,x+4,y+4),fill=INK);p.ellipse((x-4,y-3,x+3,y+3),fill=CREAM);p.ellipse((x-2,y-2,x+1,y+2),fill=GREEN)
        elif index==8:
            p.pieslice((6,9,28,26),10,180,fill='#e9c377',outline=INK)
            for x in (12,17,22):p.line((x,16,x+1,18),fill=GREEN)
        elif index==34:
            for x,y,c in ((9,15,'#e7d8bb'),(21,15,'#d87865'),(9,21,'#d9a069'),(22,21,'#b9d3b5')):p.ellipse((x-4,y-3,x+4,y+3),fill=c,outline=INK)
        else:
            for j,(x,y) in enumerate(((11,15),(20,14),(16,20))):
                color='#'+colors[j%len(colors)]
                if index in (0,2,28):
                    p.pieslice((x-3,y-3,x+4,y+3),180,360,fill=color,outline=INK);p.line((x,y,x,y+2),fill=CREAM)
                elif index in (4,16,23):p.polygon([(x-4,y),(x,y-4),(x+4,y+2),(x,y+3)],fill=color,outline=GREEN)
                elif index in (17,30):p.ellipse((x-4,y-2,x+4,y+3),fill=color,outline=INK);p.line((x-2,y,x+2,y),fill=CREAM)
                else:p.rounded_rectangle((x-3,y-2,x+3,y+3),radius=1,fill=color,outline=shade(color,.7))
        if index in (13,31,33):p.ellipse((5,8,10,12),fill='#cf7869',outline=INK)
    highlight=Image.new('RGBA',(32,32));ImageDraw.Draw(highlight).point((6+(index%4),25),fill=CREAM)
    return [('shadow',[shadow]),('dish-and-ingredients',[im]),('glaze',[highlight])]


def furniture(item):
    base=Image.new('RGBA',(64,64));p=ImageDraw.Draw(base);p.ellipse((7,52,56,61),fill=(58,43,62,55))
    im=Image.new('RGBA',(64,64));p=ImageDraw.Draw(im);color='#'+item['color'];dark=shade(color,.72);light=shade(color,1.18)
    shape=item['shape']
    if shape in ('chair','bench','sofa'):
        p.rounded_rectangle((10,18,54,44),radius=4,fill=color,outline=INK);p.rectangle((8,39,56,50),fill=dark,outline=INK)
        p.rectangle((13,50,17,59),fill=INK);p.rectangle((48,50,52,59),fill=INK)
        p.line((15,23,49,23),fill=light,width=2)
    elif shape in ('table','bed','rug'):
        p.polygon([(6,27),(39,13),(59,30),(25,46)],fill=color,outline=INK);p.line((7,29,25,48,58,33),fill=dark,width=3)
        if shape!='rug':
            for x,y in ((9,32),(25,46),(54,35)):p.rectangle((x,y,x+3,59),fill=INK)
        if shape=='bed':p.polygon([(14,28),(27,23),(36,29),(24,34)],fill=CREAM,outline=INK)
    elif shape in ('shelf','tank','painting','sign'):
        p.rectangle((10,8,54,54),fill=dark,outline=INK);p.rectangle((14,12,50,49),fill=color,outline=INK)
        for y in (26,42):p.line((14,y,50,y),fill=INK,width=2)
        for x in (18,25,32,42):p.rectangle((x,15,x+4,24),fill=light,outline=INK)
        if shape=='tank':p.rectangle((14,17,50,45),fill='#8aafb3');p.ellipse((28,27,41,34),fill='#e5b583',outline=INK)
    elif shape in ('lamp','clock','trophy'):
        p.rectangle((29,27,34,55),fill=dark,outline=INK);p.ellipse((17,52,46,60),fill=color,outline=INK)
        p.polygon([(16,26),(22,8),(43,8),(49,26)],fill=color,outline=INK);p.line((20,24,44,24),fill=CREAM,width=2)
        if shape=='clock':p.ellipse((18,7,47,34),fill=CREAM,outline=INK);p.line((32,12,32,22,40,25),fill=INK,width=2)
    else:
        p.polygon([(16,37),(48,37),(43,57),(21,57)],fill=color,outline=INK)
        for x,y in ((20,28),(33,17),(44,28)):
            p.line((32,38,x,y),fill=GREEN,width=3);p.ellipse((x-7,y-7,x+7,y+7),fill=light,outline=INK)
    return [('shadow',[base]),('furniture',[im])]


for item in D['items'].values():save(item['id'],icon(item))
for crop in D['crops']:
    save('seed_'+crop['id'],icon(crop,True))
    stages=[]
    for stage in range(4):
        im=Image.new('RGBA',(32,32));p=ImageDraw.Draw(im)
        if stage<3:
            h=5+stage*6;p.line((16,29,16,29-h),fill=INK,width=3)
            for side in (-1,1):p.ellipse((16+side*6-4,25-h,16+side*6+4,30-h),fill=GREEN,outline=INK)
        else:
            for _,frames in icon(crop):im.alpha_composite(frames[0])
        stages.append(im)
    save(crop['id'],[('growth',stages)],'crops',[('seedling',0,0),('young',1,1),('growing',2,2),('ripe',3,3)])
for index,recipe in enumerate(D['recipes']):save('dish_'+recipe['id'],dish_art(recipe,index))
for item in D['furniture']:save(item['id'],furniture(item),'furniture')
for i,id in enumerate(['pot','pan','oven','board','kettle','sprinkler','mill','hive','greenhouse','rod','fertilizer']):
    save(id,icon(dict(color=['c9a77d','a2b4bf','e0c08c'][i%3],shape=['gear','jar','bag'][i%3])))

spec=importlib.util.spec_from_file_location('storybook_author',ROOT/'Art/Character/Storybook/tools/build_characters.py')
author=importlib.util.module_from_spec(spec);spec.loader.exec_module(author)
for index,npc in enumerate(D['npcs']):
    design=dict(id=npc['id'],hair_style=npc['hair_style'],hat='#'+npc['color'],hair=['#b98065','#e0c28e','#655575','#d5d2dd'][index%4],skin=['#ecc5a3','#f0d5bb','#d09b88'][index%3],outfit='#'+npc['color'])
    frames=[];tags=[]
    for direction in ('down','up','right','left'):
        start=len(frames)
        for phase in range(4):frames.append(author.author(design,direction,phase=phase,idle=False))
        tags.append(('walk_'+direction,start,len(frames)-1))
    for f in range(6):frames.append(author.author(design,customer_frame=f))
    tags += [('idle',16,17),('eat',18,21)]
    layers=[(name,[frame.layers[name] for frame in frames]) for name in author.LAYERS]
    save(npc['id'],layers,'npcs',tags)
    portrait=frames[16].composite().resize((64,96),Image.Resampling.NEAREST)
    save(npc['id']+'_portrait',[('portrait',[portrait])],'portraits')

atlas=Image.new('RGBA',(128,128))
for index in range(64):
    tile=Image.new('RGBA',(16,16));p=ImageDraw.Draw(tile);rng=random.Random(940+index)
    palette=['#88a47b','#c5b590','#9b969b','#8eafbd','#8e6240','#68503b','#d5e1da','#b5a2c1']
    color=palette[index//8];tile.paste(color,(0,0,16,16))
    for _ in range(16):
        x,y=rng.randrange(16),rng.randrange(16);p.point((x,y),fill=shade(color,1.13 if rng.random()<.5 else .9))
    if index//8 in (1,2):
        p.line((0,0,15,0),fill=shade(color,.8));p.line((0,0,0,15),fill=shade(color,.8))
    if index//8==3:
        for y in (4,11):p.line((index%8,y,index%8+6,y),fill='#c4d7cf')
    if index//8 in (4,5):
        for y in (3,8,13):p.line((2,y,13,y),fill=shade(color,.78))
    atlas.alpha_composite(tile,((index%8)*16,(index//8)*16))
save('terrain_atlas',[('terrain',[atlas])],'tiles')
tres=['[gd_resource type="TileSet" load_steps=3 format=3]','[ext_resource type="Texture2D" path="res://Art/Campaign/tiles/terrain_atlas.png" id="1"]','[sub_resource type="TileSetAtlasSource" id="Atlas"]','texture = ExtResource("1")','texture_region_size = Vector2i(16, 16)']
for i in range(64):tres.append(f'{i%8}:{i//8}/0 = 0')
tres += ['[resource]','tile_size = Vector2i(16, 16)','sources/0 = SubResource("Atlas")']
(OUT/'tiles/terrain.tres').write_text('\n'.join(tres)+'\n',encoding='utf-8')

for index,region in enumerate(D['regions']):
    overview=Image.new('RGBA',(640,368));tiles=[]
    for y in range(23):
        row=[]
        for x in range(40):
            kind=6 if region['id']=='ridge' else 2 if region['resource']=='ore' else 0
            if abs(y-17)<2 or abs(x-4)<2:kind=1
            if 27<=x<=36 and 6<=y<=12:kind=3
            n=kind*8+(x*3+y*5+index)%8;row.append(n)
            overview.alpha_composite(atlas.crop(((n%8)*16,(n//8)*16,(n%8+1)*16,(n//8+1)*16)),(x*16,y*16))
        tiles.append(row)
    dest=OUT/'maps';dest.mkdir(exist_ok=True)
    overview.save(dest/(region['id']+'.png'))
    (dest/(region['id']+'.json')).write_text(json.dumps(dict(id=region['id'],tile_size=16,tiles=tiles,water=[432,96,160,112],spawn=[60,280],gather_points=[[120+x*130,120+y*80] for y in range(2) for x in range(3)]),indent=2)+'\n',encoding='utf-8')

icons=[Image.open(OUT/(key+'.png')).convert('RGBA') for key in manifest if key.startswith('icons/')]
sheet=Image.new('RGBA',(16*40,math.ceil(len(icons)/16)*40),'#e6d7c6')
for i,im in enumerate(icons):sheet.alpha_composite(im,((i%16)*40+4,(i//16)*40+4))
sheet.resize((sheet.width*2,sheet.height*2),Image.Resampling.NEAREST).save(OUT/'icon_catalog.png')
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(f'CAMPAIGN ART: {len(manifest)} PNG + layered Aseprite pairs, 64 tiles, 6 maps')
