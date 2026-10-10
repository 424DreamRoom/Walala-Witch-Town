"""Native pixel-grid originals; no reference image pixels are used."""
from pathlib import Path
import importlib.util
import json
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[2]
module_path = PROJECT/'Art/Icon/Resources16_Original/tools/build_resources.py'
spec = importlib.util.spec_from_file_location('resource_writer',module_path)
writer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(writer)
# O outline, B base, H/S lighting, D/d/e food-specific details.
PALETTES = {
 'pink': ['665052','c58f84','e1b2a1','a66f6c','eed0b4','917779','b7b4a6'],
 'brown':['59493e','b18359','cfaa78','896447','e4d4af','a88b65','f0e3c6'],
 'red':['634b45','ba7160','d99778','95584e','728158','536448','c0b28a'],
 'cream':['686356','d4c9aa','eee3c5','b0a58c','c6b58e','9d8c71','f4ead5'],
 'green':['4f5d46','8d9d70','b8c299','6d805b','e0d9b7','b8bc93','eef0cf'],
 'purple':['514759','8c7397','b19aa9','6b587d','819366','576d4e','d0bbaf'],
 'orange':['6a5140','c58d56','ddb17a','a86f44','829062','5d714c','ebc795'],
 'blue':['484954','837084','ae8a9b','635d75','879466','5f704f','d1a4ae'],
 'yellow':['6d5f42','c8ae68','e3cf91','a98d52','829366','5c754f','efdcaa'],
 'milk':['54616a','c4d1ca','e2e5d7','96aaa9','859bab','657d91','d9bf92'],
}
FOODS = [
('fish_meat','鱼肉','Fish meat','pink',[
'', '', '', '     OOOOO', '   OOHHHHHOO', '  OHBDDBDDBBO', ' OHBDDBDDBBBSO', ' OHBDBDDDBBBSO',' OHBDDBeDDBBSO',' OBBDDBDDBSSSO','  OBSSSSSSSSO','   OeeeeeeeO','    OOOOOOO','','','']),
('chicken_leg','鸡腿','Chicken drumstick','brown',[
'','','   OOOOO','  OHHHBBO',' OHHDBBBBO',' OHBBBBBSO',' OBBBBSSSO','  OBSSSSO','   OOSSO','     ODO','      ODO','       ODO','        OeeO','        OeeO','         OO','']),
('tomato','西红柿','Tomato','red',[
'','','       OdO','    ODDDDDO','   OOBDDBBOO','  OHHBBBBBBBO',' OHHBBBBBBBBSO',' OHBBBBBBBBBSO',' OBBBBBBBBBSSO',' OBBBBBBBBSSSO','  OBBBBBBSSSO','   OOSSSSSOO','     OOOOO','','','']),
('egg','鸡蛋','Egg','cream',[
'','','      OOO','     OHHBO','    OHHHBBO','   OHHHBBBBO','   OHHBBBBBO','  OHHBBBBBBSO','  OHBBBBBBBSO','  OHBBBBBBSSO','  OBBBDBBSSSO','   OBBBBSSSO','    OOSSSOO','      OOO','','']),
('napa_cabbage','白菜','Napa cabbage','green',[
'','     OO OO','    OHBOHBO','   OHBHBBBSO','   OHBDBDBSO','  OHBDDBDDBSO','  OBBDDBDDBSO','   ODDDeDDdO','   ODDDeDDdO','   ODDDeDDdO','   ODDDeDDdO','    ODDeDdO','    ODDeDdO','     ODDDO','      OOO','']),
('eggplant','茄子','Eggplant','purple',[
'','         OdO','        ODDO','       ODDDdO','      OHBBDO','     OHHBBBO','    OHHBBBBO','   OHHBBBBBO','  OHHBBBBBSO','  OHBBBBBSSO','  OBBBBBSSSO','   OBBBSSSO','    OOSSOO','      OO','','']),
('potato','土豆','Potato','brown',[
'','','','    OOOOO','  OOHHHBBOO',' OHHDHHBBBBO',' OHBBBBBdBBSO',' OHBdBBBBBBSO',' OBBBBBBDBSSO',' OBBBdBBBSSSO','  OBBBBSSSSO','   OOSSSSOO','     OOOO','','','']),
('carrot','胡萝卜','Carrot','orange',[
'','        OdO OdO','         ODOdO','       ODDDDO','      OHHBBO','     OHHBBBO','     OHBdBSO','    OHBBBSO','    OHBdBSO','    OBBBSO','    OBdSO','   OBBSO','   OBSO','   OSO','    O','']),
('onion','洋葱','Onion','purple',[
'','       OdO','      ODDO','      ODBO','     OHBBO','   OOHHHBBOO','  OHHDDBDBBSO',' OHHDDBBDDBBSO',' OHHDDBBDDBBSO',' OHBDDBBDDBSSO',' OBBdDBBdDBSSO','  OBBdBdBSSSO','   OOSSSSSOO','      OdO','','']),
('pumpkin','南瓜','Pumpkin','orange',[
'','','      OdO','      ODDO','   OOOBOBOOO','  OHBHHBHHBBO',' OHBHBBDBBBBSO',' OHBHBBDBBBBSO',' OHBHBBDBBBBSO',' OBBHBBDBBBSSO',' OBBDBBDBBBSSO','  OBDBBDBBSSO','   OOSSSSSOO','     OOOOO','','']),
('mushroom','蘑菇','Mushroom','brown',[
'','','     OOOOO','   OOHHHHBOO','  OHHeBBBeBBO',' OHHeeBBBBeeBO',' OHBBBBBBBBBSO',' OOOOOOOOOOOOO','     ODDdO','     ODDdO','     ODDdO','    ODDeDdO','    ODDDDdO','     OOOOO','','']),
('herbs','香草','Herbs','green',[
'','','       OOO','   OO OHHBO','  OHBOOHD SO','  OHHBODDO','   ODDODO OOO','     ODO OHHBO','  OOOOD OHD SO',' OHBBDDOODDO',' OHDDOODO','  OOO ODO','       OdO','        O','','']),
('berries','浆果','Berries','blue',[
'','','     ODDD','    ODDDdO','      OdO','   OOO OOO','  OHBBOHBB O','  OHDBOHDBSO','   OSO OSSO','  OOO OOO OO',' OHBBOHBB OHBO',' OHDBOHDBOHDSO','  OSO OSS OSSO','   OO  OO OO','','']),
('apple','苹果','Apple','red',[
'','       OdO','       ODOOO','      ODO DDO','   OOOBOOOO','  OHHBBBBBBO',' OHHeBBBBBBSO',' OHHeBBBBBBSO',' OHBBBBBBBBSO',' OBBBBBBBBSSO','  OBBBBBBSSO','  OBBBBBBSSO','   OOSOSSOO','     O OO','','']),
('corn','玉米','Corn','yellow',[
'','      OOO','     OHBBO','    OHDHDBO','    OHDHDBO','   ODHDHDBSO','   ODHDHDBSO','  ODDHDHDBdO','  ODDHDHDBdO','   ODDHDDddO','   ODDDDdddO','    ODDdddO','     ODddO','      ODO','       O','']),
('wheat','小麦','Wheat','yellow',[
'','       O','      OHBO','   OO OHDO OO','  OHDOODOOHDO','   OHDOdOHDO','    OHOdOHO','  OO OOdOO OO',' OHDO ODO OHDO','  OHDOODOOHDO','   OHOODOOHO','    OOODOOO','      OdO','      OdO','       O','']),
('shrimp','虾','Shrimp','pink',[
'','','     OOOOO','   OOHHHBBO','  OHHDBDBBBO',' OHDBDBBDBBSO',' OHDBO ODBdSO',' OBBO   ODSO',' OBBO    OO','  OBBO  OOO','   OBBOOHBO','    OBBBBBO','     OOBOO','     OdOdO','','']),
('beef','牛肉','Beef','red',[
'','','','    OOOOOOO','  OOHHHHHHBO',' OHHeBBBeBBBO',' OHBBeeBBeBBSO',' OHBBBBeeBBBSO',' OBBBeBBBBBBSO',' OBBeeBBeBBSSO','  OBBBBeBBSSO','   OeeeeeeeO','    OOOOOOO','','','']),
('milk','牛奶','Milk','milk',[
'','      OOOO','     ODDDDO','     OOOOOO','     OHBBBO','    OHHBBBBO','   OHHBBBBBSO','   OHBBBBBBSO','   OHBDDDBBSO','   OHBDDDBBSO','   OHBDDDBBSO','   OHBBBBBBSO','   OBBBBBBSSO','    OOOOOOO','','']),
('cheese','奶酪','Cheese','yellow',[
'','','','         OO','       OOHO','     OOHHHBO','   OOHHdHHBO','  OHHHHHHHBO',' OOOOOOOOOBBO',' OHBBdBBBBBSO',' OHBddBBdBBSO',' OHBBBBBBBBSO','  OBBBBBSSSSO','   OOOOOOOOO','',''])
]

def food_palette(name, palette):
    colors = dict(zip('OBHSDde',PALETTES[palette]))
    if name == 'beef': colors.update(D='e4c9ae', d='a67b6a', e='ead5b8')
    if name == 'pumpkin': colors['D']='a97045'
    if name == 'onion': colors.update(D='d7c2b4', d='907184')
    if name == 'fish_meat': colors['D']='ead0b8'
    if name == 'chicken_leg': colors.update(D='e4d4af',d='b9ab8a')
    if name == 'carrot': colors['d']='a97045'
    if name == 'corn': colors['D']='e3c17f'
    if name == 'cheese': colors.update(D='ad8a51',d='937440')
    return colors

def main():
    names = [f[0] for f in FOODS]
    assert len(names)==len(set(names))==20
    targets=[ROOT/(n+e) for n in names for e in ('.png','.aseprite')]
    targets += [ROOT/'manifest.json',ROOT/'preview_nearest_12x.png']
    assert not any(p.exists() for p in targets), 'Refusing to overwrite existing output'
    assets=[]
    sprites=[]
    for name,cn,en,palette,rows in FOODS:
        colors=food_palette(name,palette)
        layers,image=writer.author({'palette':colors,'rows':rows})
        assert all(im.getbbox() for im in layers), name
        sprites.append(image)
        assets.append({'name_zh':cn,'name_en':en,'slug':name,'png':name+'.png','aseprite':name+'.aseprite'})
    # Authoring is validated before any binary output is created.
    for food,image in zip(FOODS,sprites):
        name,cn,en,palette,rows=food
        layers,_=writer.author({'palette':food_palette(name,palette),'rows':rows})
        with (ROOT/(name+'.aseprite')).open('xb') as out: out.write(writer.aseprite_bytes(layers))
        image.save(ROOT/(name+'.png'))
    make_preview(sprites)
    with (ROOT/'manifest.json').open('x',encoding='utf-8') as out:
        json.dump({'count':20,'size':[16,16],'layers':writer.LAYERS,'assets':assets},out,ensure_ascii=False,indent=2)
    print('Created 20 PNGs, 20 four-layer Aseprite sources, manifest and nearest-neighbor preview.')

def make_preview(sprites):
    preview=Image.new('RGB',(1120,1008),'#24252c')
    draw=ImageDraw.Draw(preview)
    for i,(food,image) in enumerate(zip(FOODS,sprites)):
        x,y=16+(i%5)*224,16+(i//5)*252
        for py in range(16):
            for px in range(16):
                fill='#44454d' if (px//2+py//2)%2 else '#383940'
                draw.rectangle((x+px*12,y+py*12,x+px*12+11,y+py*12+11),fill=fill)
        big=image.resize((192,192),Image.Resampling.NEAREST)
        preview.paste(big,(x,y),big)
        draw.text((x,y+201),f'{i+1:02d} '+food[2],font=ImageFont.load_default(size=15),fill='#ded6c9')
        draw.text((x,y+225),'16x16 / RGBA / 4 layers',font=ImageFont.load_default(size=11),fill='#aaa6ac')
    preview.save(ROOT/'preview_nearest_12x.png')
if __name__=='__main__': main()
