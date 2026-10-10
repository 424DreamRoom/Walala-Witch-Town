"""Native 16x24 original pixel authoring. Never reads/resizes reference artwork.
Aseprite chunk encoding adapted from resource-icons agent; original files untouched.
Run from project root. Existing outputs are guarded.
"""
from pathlib import Path
import struct, zlib, json, sys
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[1]
LAYERS = ['Boots', 'Cloak', 'Hair and face', 'Purple pointed hat', 'Details']
PAL = {'.':(0,0,0,0)}
for k,v in {'O':'201d30','P':'65428b','H':'8861aa','S':'49335f','B':'322f46','L':'474359','T':'685078','W':'edf0ed','G':'b9bdcc','g':'85889f','F':'f1d1b8','f':'c99b96','E':'30263f','C':'d4b476','K':'332d39','k':'696071'}.items():
    PAL[k]=tuple(bytes.fromhex(v))+(255,)
# All strokes are integer pixels on the destination canvas. No resampling.
HAT = [
'................','.........OO.....','........OPPO....','.......OHPPOO...','......OHPPPSPO..',
'......OHPPPSOO..','.....OHPPPSSO...','.....OPPPSSSO...','....OTTTTTTSO...',
'..OOOPPPPPPSSOO.','.OSSSSSSSSSSSSSO','..OOOOOOOOOOOOO.']
FRONT = ['....OGWWWGGO....','....OWFFFFGO....','....OGFFFFGO....','.....OFFFOO.....']
BACK = ['....OGWWWGGO....','....OWGWGWGO....','....OGWGWGGO....','.....OGGGO......']
SIDE = ['....OGWWWGO.....','....OFFGWGO.....','....OFEGWGO.....','.....OFGGO......']
CLOAK = ['......OBBO......','.....OLBBLO.....','.....OLBBBO.....','....OLBBBBBO....','....OLBBBBBO....','...OTBBBBBBTO...','....OTTTTTTO....']

def author(direction, phase, idle=False):
    layers=[Image.new('RGBA',(16,24)) for _ in LAYERS]
    def px(layer,x,y,c):
        if 0<=x<16 and 0<=y<24 and c!='.': layers[layer].putpixel((x,y),PAL[c])
    def rows(layer,data,y0,dx=0,dy=0):
        for y,row in enumerate(data):
            assert len(row)==16
            for x,c in enumerate(row): px(layer,x+dx,y+y0+dy,c)
    # Contact, passing, opposite contact, passing: feet and cape change independently.
    bob=-1 if (not idle and phase in (1,3)) else 0
    sway=(0,1,0,-1)[phase] if not idle else 0
    rows(1,CLOAK,15,dx=sway if direction in ('down','up') else 0,dy=bob)
    face=FRONT if direction=='down' else BACK if direction=='up' else SIDE
    rows(2,face,11,dy=bob)
    rows(3,HAT,0,dy=bob)
    if direction!='up':
        px(4,11,8+bob,'C'); px(4,11,9+bob,'O'); px(4,7,16+bob,'C')
    if direction=='down':
        px(4,6,13+bob,'E'); px(4,9,13+bob,'E')
        px(4,6,12+bob,'W'); px(4,9,12+bob,'W')
    if not idle and direction in ('left','right') and phase==3:
        px(1,10,19,'T'); px(1,11,20,'O')
    # Distinct side profile; mirror whole layered artwork for right, not a new palette.
    feet = ([(5,21),(9,21)] if idle or phase in (1,3) else
            [(4,21),(9,20)] if phase==0 else [(5,20),(10,21)])
    if direction in ('left','right'):
        feet=([(6,21),(8,21)] if idle or phase in (1,3) else
              [(4,21),(9,20)] if phase==0 else [(5,20),(10,21)])
    for x,y in feet:
        for xx,yy,c in [(x,y,'O'),(x+1,y,'K'),(x,y+1,'k'),(x+1,y+1,'K'),(x,y+2,'O'),(x+1,y+2,'O')]: px(0,xx,yy,c)
    if direction=='right': layers=[im.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for im in layers]
    composite=Image.new('RGBA',(16,24))
    for im in layers: composite=Image.alpha_composite(composite,im)
    return layers,composite

def chunk(kind,payload): return struct.pack('<IH',len(payload)+6,kind)+payload

def source(frames,tags):
    output=[]
    for index,(layers,_) in enumerate(frames):
        chunks=[]
        if index==0:
            for name in LAYERS:
                s=name.encode(); chunks.append(chunk(0x2004,struct.pack('<HHHHHHB',1,0,0,0,0,0,255)+bytes(3)+struct.pack('<H',len(s))+s))
            payload=struct.pack('<H',len(tags))+bytes(8)
            for tag in tags:
                s=tag['name'].encode()
                payload+=struct.pack('<HHBH',tag['from'],tag['to'],0,0)+bytes(6)+bytes((136,97,170,0))+struct.pack('<H',len(s))+s
            chunks.append(chunk(0x2018,payload))
        for i,im in enumerate(layers):
            payload=struct.pack('<HhhBHh',i,0,0,255,2,0)+bytes(5)+struct.pack('<HH',16,24)+zlib.compress(im.tobytes())
            chunks.append(chunk(0x2005,payload))
        body=b''.join(chunks)
        duration=400 if index%5==0 else 110
        output.append(struct.pack('<IHHHHI',len(body)+16,0xF1FA,len(chunks),duration,0,0)+body)
    header=bytearray(128)
    struct.pack_into('<IHHHHHIH',header,0,128+sum(map(len,output)),0xA5E0,len(frames),16,24,32,1,100)
    struct.pack_into('<HBBhhHH',header,32,0,1,1,0,0,16,24)
    return bytes(header)+b''.join(output)

def main():
    targets=['walala_witch.aseprite','walala_witch.png','preview_nearest_12x.png','animations.json']
    for name in targets:
        if (ROOT/name).exists() and '--replace-generated' not in sys.argv: raise FileExistsError(ROOT/name)
    frames=[]; tags=[]
    sheet=Image.new('RGBA',(80,96))
    for row,direction in enumerate(('down','up','right','left')):
        start=len(frames)
        tags.extend([{'name':'idle_'+direction,'from':start,'to':start}, {'name':'walk_'+direction,'from':start+1,'to':start+4}])
        for col in range(5):
            layers,im=author(direction,max(0,col-1),idle=col==0)
            frames.append((layers,im)); sheet.paste(im,(col*16,row*24))
    sheet.save(ROOT/'walala_witch.png')
    (ROOT/'walala_witch.aseprite').write_bytes(source(frames,tags))
    meta={'frame_size':[16,24],'sheet_size':[80,96],'columns':5,'directions':['down','up','right','left'],'anchor':[8,24],'idle_fps':2.5,'walk_fps':9,'run_fps':13,'layers':LAYERS,'tags':tags}
    (ROOT/'animations.json').write_text(json.dumps(meta,indent=2)+'\n')
    preview=Image.new('RGB',(1080,1240),'#242332'); d=ImageDraw.Draw(preview)
    for row,direction in enumerate(meta['directions']):
        y=35+row*300
        d.text((8,y+120),direction,fill='#ded5ef')
        for col in range(5):
            x=95+col*194
            for py in range(24):
                for px in range(16):
                    d.rectangle((x+px*12,y+py*12,x+px*12+11,y+py*12+11),fill='#454251' if (px//2+py//2)%2 else '#383542')
            tile=sheet.crop((col*16,row*24,col*16+16,row*24+24)).resize((192,288),Image.Resampling.NEAREST)
            preview.paste(tile,(x,y),tile)
    d.text((95,10),'IDLE             WALK 1           WALK 2           WALK 3           WALK 4',fill='#ded5ef')
    preview.save(ROOT/'preview_nearest_12x.png')
    print('Created 20 original 16x24 frames, five editable layers, eight tags.')
if __name__=='__main__': main()
