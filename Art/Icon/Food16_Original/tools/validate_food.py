"""Reuse independent binary parser; additionally enforce complete food manifest."""
from pathlib import Path
import importlib.util
import json
import hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT.parents[2]
parser_path=PROJECT/'Art/Icon/Resources16_Original/tools/validate_resources.py'
spec=importlib.util.spec_from_file_location('resource_validator',parser_path)
parser=importlib.util.module_from_spec(spec)
spec.loader.exec_module(parser)
parser.ROOT=ROOT
EXPECTED=[('fish_meat','鱼肉'),('chicken_leg','鸡腿'),('tomato','西红柿'),('egg','鸡蛋'),('napa_cabbage','白菜'),('eggplant','茄子'),('potato','土豆'),('carrot','胡萝卜'),('onion','洋葱'),('pumpkin','南瓜'),('mushroom','蘑菇'),('herbs','香草'),('berries','浆果'),('apple','苹果'),('corn','玉米'),('wheat','小麦'),('shrimp','虾'),('beef','牛肉'),('milk','牛奶'),('cheese','奶酪')]
def main():
    manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
    assets=manifest['assets']
    assert manifest['count']==len(assets)==20
    assert [(a['slug'],a['name_zh']) for a in assets]==EXPECTED
    assert len({a['name_en'] for a in assets})==20
    names={n for n,cn in EXPECTED}
    assert {p.stem for p in ROOT.glob('*.aseprite')}==names
    assert {p.stem for p in ROOT.glob('*.png')}==names|{'preview_nearest_12x'}
    results=[]
    hashes=[]
    for asset in assets:
        n=asset['slug']
        assert asset['png']==n+'.png' and asset['aseprite']==n+'.aseprite'
        result=parser.validate(n)
        result.update(name_zh=asset['name_zh'],name_en=asset['name_en'])
        with Image.open(ROOT/asset['png']) as im:
            digest=hashlib.sha256(im.tobytes()).hexdigest()
            hashes.append(digest)
            result['png_pixel_sha256']=digest
            assert all(p==(0,0,0,0) for p in im.getdata() if p[3]==0)
        results.append(result)
    assert len(set(hashes))==20, 'Duplicate pixel content'
    with Image.open(ROOT/'preview_nearest_12x.png') as preview:
        assert preview.size==(1120,1008)
    report={'passed':True,'asset_count':20,'unique_pixel_content_count':20,'missing':[], 'duplicates':[],
            'method':'Reused independent Aseprite binary parser, zlib cel decode, 4 nonempty layers, exact RGBA recomposition; full manifest and unique pixel hashes',
            'aseprite_application_tested':False,'limitation':'No Aseprite CLI found on PATH; no application-open test performed',
            'preview':'preview_nearest_12x.png','assets':results}
    (ROOT/'validation_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('PASS: 20 unique complete assets; 16x16 RGBA alpha 0/255; transparent padding; valid four-layer Aseprite structures; exact source/PNG pixel match.')
if __name__=='__main__': main()
