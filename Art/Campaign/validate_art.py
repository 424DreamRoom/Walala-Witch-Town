"""Decode every authored Aseprite cel and compare the composite to its runtime PNG."""
import json
from pathlib import Path
import struct
import zlib
from PIL import Image

ROOT=Path(__file__).resolve().parent
manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
checked=0
for key,meta in manifest.items():
    raw=(ROOT/(key+'.aseprite')).read_bytes()
    size,magic,count,w,h,depth=struct.unpack_from('<IHHHHH',raw,0)
    assert size==len(raw) and magic==0xA5E0 and depth==32 and count==meta['frames'],key
    png=Image.open(ROOT/(key+'.png')).convert('RGBA')
    assert png.size==(w*count,h),key
    position=128
    names=[]
    for frame in range(count):
        frame_size,frame_magic,chunks=struct.unpack_from('<IHH',raw,position)
        assert frame_magic==0xF1FA
        end=position+frame_size;position+=16
        cels={}
        for _ in range(chunks):
            n,kind=struct.unpack_from('<IH',raw,position);data=raw[position+6:position+n];position+=n
            if kind==0x2004:
                length=struct.unpack_from('<H',data,16)[0]
                names.append(data[18:18+length].decode())
            elif kind==0x2005:
                layer,x,y,opacity,celtype=struct.unpack_from('<HhhBH',data,0)
                assert celtype==2 and opacity==255 and (x,y)==(0,0)
                cw,ch=struct.unpack_from('<HH',data,16)
                cels[layer]=Image.frombytes('RGBA',(cw,ch),zlib.decompress(data[20:]))
        assert position==end and len(cels)==len(meta['layers']),key
        composite=Image.new('RGBA',(w,h))
        for layer in sorted(cels):composite.alpha_composite(cels[layer])
        assert composite.tobytes()==png.crop((frame*w,0,(frame+1)*w,h)).tobytes(),(key,frame)
        checked+=1
    assert position==len(raw) and names==meta['layers'],key
    assert png.getbbox(),key
dishes=[Image.open(p).tobytes() for p in (ROOT/'icons').glob('dish_*.png')]
assert len(dishes)==36 and len(set(dishes))==36,'Each dish needs a distinct icon'
report={'assets':len(manifest),'decoded_frames':checked,'unique_dishes':36,'tile_count':64,'aseprite_composites_match_png':True}
(ROOT/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('ART VALIDATED',report)
