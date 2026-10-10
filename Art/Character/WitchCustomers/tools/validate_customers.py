"""Independent validation for native customer sources and PNG sheets."""
from pathlib import Path
import json, struct, zlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def main():
    meta=json.loads((ROOT/'customers.json').read_text())
    assert meta['frame_size']==[16,24] and len(meta['variants'])==6
    for v in meta['variants']:
        png=Image.open(ROOT/(v['slug']+'.png'))
        assert png.mode=='RGBA' and png.size==(96,144)
        assert set(png.getchannel('A').getdata()).issubset({0,255})
        data=(ROOT/(v['slug']+'.aseprite')).read_bytes()
        size,magic,n,w,h,depth=struct.unpack_from('<IHHHHH',data)
        assert size==len(data) and magic==0xA5E0 and n==6 and (w,h,depth)==(16,24,32)
        pos=128; tags=[]; layers=[]
        for fi in range(n):
            length,magic,count,duration=struct.unpack_from('<IHHH',data,pos); assert magic==0xF1FA
            end=pos+length; p=pos+16; cels={}
            for _ in range(count):
                clen,kind=struct.unpack_from('<IH',data,p); payload=data[p+6:p+clen]
                if kind==0x2004:
                    name_len=struct.unpack_from('<H',payload,16)[0]; layers.append(payload[18:18+name_len].decode())
                elif kind==0x2018:
                    num=struct.unpack_from('<H',payload)[0]; q=10
                    for _ in range(num):
                        a,b,d,r=struct.unpack_from('<HHBH',payload,q); ln=struct.unpack_from('<H',payload,q+17)[0]; tags.append((payload[q+19:q+19+ln].decode(),a,b)); q+=19+ln
                elif kind==0x2005:
                    li=struct.unpack_from('<H',payload)[0]; raw=zlib.decompress(payload[20:]); assert len(raw)==1536; cels[li]=Image.frombytes('RGBA',(16,24),raw)
                p+=clen
            assert p==end and set(cels)==set(range(5)); pos=end
        assert pos==len(data) and layers[:5]==['Shoes','Outfit','Hair','Hat','Details'] and tags==[('idle',0,1),('eat',2,5)]
    out={'status':'PASS','variants':6,'frames_per_variant':6,'native_frame':[16,24],'alpha':'only 0/255','aseprite_application_verified':False}
    (ROOT/'validation_report.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n'); print(json.dumps(out,ensure_ascii=False))
if __name__=='__main__': main()
