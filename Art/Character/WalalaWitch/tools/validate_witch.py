"""Independent native Aseprite parser; does not import the writer."""
from pathlib import Path
import struct,zlib,json,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def main():
    data=(ROOT/'walala_witch.aseprite').read_bytes()
    size,magic,n,w,h,depth=struct.unpack_from('<IHHHHH',data)
    assert (size,magic,n,w,h,depth)==(len(data),0xA5E0,20,16,24,32)
    sheet=Image.open(ROOT/'walala_witch.png')
    assert sheet.mode=='RGBA' and sheet.size==(80,96)
    assert set(sheet.getchannel('A').getdata())=={0,255}
    layers=[]; tags=[]; frames=[]; pos=128
    for frame in range(n):
        length,magic,count,duration=struct.unpack_from('<IHHH',data,pos)
        assert magic==0xF1FA and duration==(400 if frame%5==0 else 110)
        end=pos+length; p=pos+16; cels={}
        for _ in range(count):
            length,kind=struct.unpack_from('<IH',data,p)
            assert length>=6 and p+length<=end
            payload=data[p+6:p+length]
            if kind==0x2004:
                assert frame==0
                flags,typ,level,_,_,blend=struct.unpack_from('<HHHHHH',payload)
                assert (flags,typ,level,blend,payload[12])==(1,0,0,0,255)
                name_len=struct.unpack_from('<H',payload,16)[0]
                assert len(payload)==18+name_len
                layers.append(payload[18:].decode())
            elif kind==0x2018:
                num=struct.unpack_from('<H',payload)[0]; q=10
                for _ in range(num):
                    start,finish,direction,repeat=struct.unpack_from('<HHBH',payload,q)
                    assert direction==0 and repeat==0
                    name_len=struct.unpack_from('<H',payload,q+17)[0]
                    name=payload[q+19:q+19+name_len].decode()
                    tags.append({'name':name,'from':start,'to':finish}); q+=19+name_len
                assert q==len(payload)
            elif kind==0x2005:
                i,x,y,opacity,typ,z=struct.unpack_from('<HhhBHh',payload)
                assert (x,y,opacity,typ,z)==(0,0,255,2,0) and i not in cels
                assert struct.unpack_from('<HH',payload,16)==(16,24)
                raw=zlib.decompress(payload[20:]); assert len(raw)==1536
                cels[i]=Image.frombytes('RGBA',(16,24),raw)
            else: raise AssertionError(hex(kind))
            p+=length
        assert p==end and set(cels)==set(range(5))
        composite=Image.new('RGBA',(16,24))
        for i in range(5): composite=Image.alpha_composite(composite,cels[i])
        row,col=divmod(frame,5)
        tile=sheet.crop((col*16,row*24,col*16+16,row*24+24))
        assert composite.tobytes()==tile.tobytes()
        assert tile.getbbox() and any(tile.getpixel((x,23))[3] for x in range(16))
        frames.append(tile.tobytes()); pos=end
    assert pos==len(data)
    meta=json.loads((ROOT/'animations.json').read_text())
    assert layers==meta['layers'] and tags==meta['tags']
    for row in range(4): assert len(set(frames[row*5+1:row*5+5]))==4
    result={'status':'PASS','method':'Independent chunk parsing and exact layered RGBA/PNG round trip','canvas':[w,h],'sheet':[80,96],'frames':20,'layers':layers,'tags':tags,'unique_walk_frames_per_direction':4,'alpha_values':[0,255],'anchor':[8,24],'aseprite_application_verified':False,'source_sha256':hashlib.sha256(data).hexdigest()}
    (ROOT/'validation_report.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
if __name__=='__main__': main()
