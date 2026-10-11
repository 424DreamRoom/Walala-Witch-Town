"""Add missing editable sources without touching originals. Python + Pillow.

Raster imports retain the entire RGBA canvas in a named layer. Existing authored
sources are never regenerated. SVGs keep their vector originals and get a native
canvas raster counterpart; GIFs retain frames/durations. No work targets MyArt.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import shutil
import zlib
from PIL import Image, ImageSequence

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/aseprite_migration'
PICTURES = {'.png', '.gif', '.svg', '.jpg', '.jpeg', '.webp', '.bmp'}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def protected():
    return {p.relative_to(ROOT).as_posix(): digest(p) for p in (ROOT/'MyArt').rglob('*') if p.is_file()}

def chunk(kind, data):
    return struct.pack('<IH', 6 + len(data), kind) + data

def encode(frames, durations=None, name='Imported pixels'):
    w, h = frames[0].size
    assert w <= 65535 and h <= 65535
    durations = durations or [100] * len(frames)
    body = []
    label = name.encode('utf8')
    for index, image in enumerate(frames):
        chunks = []
        if index == 0:
            chunks.append(chunk(0x2004, struct.pack('<6HB', 1, 0, 0, 0, 0, 0, 255) + bytes(3) + struct.pack('<H',len(label)) + label))
        pixels = image.convert('RGBA').tobytes()
        chunks.append(chunk(0x2005, struct.pack('<HhhBHh',0,0,0,255,2,0) + bytes(5) + struct.pack('<HH', w,h) + zlib.compress(pixels, 9)))
        data = b''.join(chunks)
        body.append(struct.pack('<IHHHHI',16+len(data),0xf1fa,len(chunks),max(1,min(65535,durations[index])),0,0)+data)
    header = bytearray(128)
    struct.pack_into('<I5HIH',header,0,128+sum(map(len,body)),0xa5e0,len(frames),w,h,32,1,100)
    # Header flags at 14; deprecated speed at 18.
    struct.pack_into('<IH', header, 14, 1, 100)
    struct.pack_into('<BBhhHH',header,34,1,1,0,0,16,16)
    return bytes(header)+b''.join(body)

def write_new(path, frames, durations=None, name='Imported pixels'):
    assert not path.is_relative_to(ROOT/'MyArt')
    if path.exists(): return False
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(encode(frames,durations,name))
    return True

def images():
    return sorted([p for folder in ('Art','Scenes/LanternLane/Art') for p in (ROOT/folder).rglob('*') if p.suffix.lower() in PICTURES and 'Verification' not in p.parts] + [ROOT/'icon.svg'])

def godot_bin():
    import os
    candidates = [os.environ.get('GODOT_BIN',''),r'C:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',r'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe']
    return next(str(Path(p)) for p in candidates if p and Path(p).is_file())

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--tiles',action='store_true');args=parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'.gdignore').touch()
    before=protected()
    files=images()
    vectors=[]
    for p in files:
        if p.suffix=='.svg':
            target=OUT/'vectors'/p.relative_to(ROOT).with_suffix('.png')
            target.parent.mkdir(parents=True,exist_ok=True)
            vectors.append({'source':str(p),'target':str(target)})
    (OUT/'vectors.json').write_text(json.dumps(vectors,indent=2),encoding='utf8')
    if vectors:
        fixture=OUT/'vector_project';fixture.mkdir(exist_ok=True)
        (fixture/'project.godot').write_text('config_version=5\n',encoding='utf8')
        shutil.copy2(ROOT/'Art/Source/rasterize_vectors.gd',fixture/'rasterize.gd')
        run=subprocess.run([godot_bin(),'--headless','--path',str(fixture),'--script','res://rasterize.gd','--','--manifest='+str(OUT/'vectors.json')],capture_output=True,text=True,encoding='utf8')
        (OUT/'vectors.log').write_text(run.stdout+run.stderr,encoding='utf8')
        assert run.returncode==0 and 'ERROR:' not in run.stderr, run.stderr
    registry={}; sheets={}; added=0
    for p in files:
        relative=p.relative_to(ROOT).as_posix()
        target=p.with_suffix('.aseprite') if p.suffix=='.png' else p.with_name(p.name+'.aseprite')
        raster=OUT/'vectors'/p.relative_to(ROOT).with_suffix('.png') if p.suffix=='.svg' else p
        with Image.open(raster) as im:
            frames=[frame.convert('RGBA').copy() for frame in ImageSequence.Iterator(im)] if p.suffix=='.gif' else [im.convert('RGBA')]
            durations=[frame.info.get('duration',100) for frame in ImageSequence.Iterator(im)] if p.suffix=='.gif' else [100]
            size=im.size
        added+=write_new(target,frames,durations, 'Imported '+p.suffix[1:].upper()+' pixels')
        raw=target.read_bytes(); count,w,h=struct.unpack_from('<3H',raw,6)
        if p.suffix=='.png':
            assert size[0]%w==0 and size[1]%h==0 and size[0]//w*(size[1]//h)>=count, relative
            columns,rows=size[0]//w,size[1]//h
        else:columns,rows=count,1
        source='res://'+target.relative_to(ROOT).as_posix()
        registry['res://'+relative]={'source':source,'origin':relative,'canvas':list(size),'frames':count,'authored':b'Imported ' not in raw[128:]}
        sheets[source]={'columns':columns,'rows':rows}
    (ROOT/'Art/Source/assets.json').write_text(json.dumps(registry,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    (ROOT/'Art/Source/sheets.json').write_text(json.dumps(sheets,indent=2)+'\n',encoding='utf8')
    if args.tiles: build_tiles()
    assert protected()==before,'MyArt contents changed'
    print('SOURCE BUILD PASS',len(registry),'assets;',added,'new sources; MyArt unchanged')

def build_tiles():
    folder=ROOT/'Art/Environment/Hearthwood';size=16
    targets=sorted(set(folder.glob('*_ground.png')) | set(folder.glob('home_empty_*.png')) | {folder/'field_background.png'})
    report=[]
    for p in targets:
        # Existing editable terrain data belongs to the artist after migration.
        dest=folder/'Tiles'/(p.stem+'.aseprite')
        record=p.with_suffix('.tiles.json')
        if dest.exists() and record.exists():
            data=json.loads(record.read_text(encoding='utf8'))
            report.append({'map':p.stem,'cells':sum(map(len,data['cells'])),'unique_tiles':data['tile_count']})
            continue
        image=Image.open(p).convert('RGBA');cells=[];unique=[];ids={}
        for y in range(0,image.height,size):
            row=[]
            for x in range(0,image.width,size):
                tile=image.crop((x,y,x+size,y+size));key=tile.tobytes()
                if not tile.getbbox():row.append(-1);continue
                if key not in ids:ids[key]=len(unique);unique.append(tile)
                row.append(ids[key])
            cells.append(row)
        columns=min(64,len(unique));atlas=Image.new('RGBA',(columns*size,math.ceil(len(unique)/columns)*size))
        for index,tile in enumerate(unique):atlas.paste(tile,((index%columns)*size,(index//columns)*size))
        write_new(dest,[atlas],name='16x16 terrain tiles')
        data={'tile_size':size,'size':list(image.size),'atlas':'res://'+dest.relative_to(ROOT).as_posix(),'columns':columns,'tile_count':len(unique),'cells':cells}
        p.with_suffix('.tiles.json').write_text(json.dumps(data,separators=(',',':'))+'\n',encoding='utf8')
        report.append({'map':p.stem,'cells':sum(map(len,cells)),'unique_tiles':len(unique)})
    (OUT/'tile_report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print('TILE BUILD PASS',report)

if __name__=='__main__': main()
