"""Original native-resolution sprite authoring; no input image or resampling.
Run from project root: python Art/Icon/Resources16_Original/tools/build_resources.py
Use --replace to refresh existing exports. Only review previews are enlarged.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import zlib
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
LAYERS = ['Outline', 'Base color', 'Light and shadow', 'Details']
# Each character is one authored pixel. D/d/e are material or emblem details.
SPECS = {
    'wood': {
        'palette': {'O':'493338', 'B':'a66e49', 'S':'774934', 'H':'c99460', 'D':'e5bd80', 'd':'835034', 'e':'b17b4e'},
        'rows': [
            '', '', '        OOOO', '      OOHBBBO', '    OOHBBBBBO',
            '   ODDOBddBBSO', '  ODHDDOBBBBSO', ' ODHdeDOBddBSO',
            ' ODHeeDOBBBSSO', ' ODHedDOBdSSSO', ' OBDeeDOBSSSO',
            '  OBDDOOSSSO', '   OOOOSSOO', '      OOO', '', ''],
    },
    'stone': {
        'palette': {'O':'41424e', 'B':'89959d', 'S':'596878', 'H':'b5c0ba', 'D':'d4d8c2', 'd':'6d7c87'},
        'rows': [
            '', '', '       OOO', '     OOHHHO', '    OHDDHHBOO',
            '   OHDDHHBBBBBO', '  OHHHHBBBBBBBO', '  OHBBBBBBddBSO',
            ' OBBBBBBddBBSSO', ' OBBBBdBBBSSSSO', '  OBBdBBSSSSSO',
            '   OBBSSSSSSO', '    OOSSSSOO', '      OOOO', '', ''],
    },
    'gold': {
        'palette': {'O':'654039', 'B':'d89f49', 'S':'a96539', 'H':'f0cb72', 'D':'fff0ae', 'd':'b77c38'},
        'rows': [
            '', '', '', '      OOOOOOO', '     OHDDHHHHO',
            '    OHHHHHHHHO', '   OHHHHHHHHBO', '  ODDHHHHHHBBSO',
            ' OHHBBBBBBBSSSO', ' OBBBBBdBBSSSSO', ' OBBBddBSSSSSO',
            '  OBBBSSSSSSO', '   OOOOOOOOO', '', '', ''],
    },
    'iron_ore': {
        'palette': {'O':'423d4d', 'B':'767f92', 'S':'505a71', 'H':'a0afbb', 'D':'c98d60', 'd':'8f5943', 'e':'f0c18a'},
        'rows': [
            '', '', '      OOO', '    OOHBBOO', '   OHHeeDBBO',
            '  OHHHeDDdBBO', '  OHBBBddBBBO', ' OHBBBBBBeDDSO',
            ' OBeDDBBBDDdSO', ' OBDDdBSSddSSO', '  OddBBSSSSSO',
            '   OBSSSSSSO', '    OOSSSOO', '      OOO', '', ''],
    },
    'iron': {
        'palette': {'O':'3b3e50', 'B':'94adb5', 'S':'5b7188', 'H':'ccd8ce', 'D':'f1f0d8', 'd':'7793a4'},
        'rows': [
            '', '', '', '      OOOOOOO', '     OHDDHHHHO',
            '    OHHHHHHHHO', '   OHHHHHHHHBO', '  ODDHHHHHHBBSO',
            ' OHHBBBBBBBSSSO', ' OBBBBBdBBSSSSO', ' OBBBddBSSSSSO',
            '  OBBBSSSSSSO', '   OOOOOOOOO', '', '', ''],
    },
    'fish': {
        'palette': {'O':'35404b', 'B':'719f9e', 'S':'4e6e82', 'H':'a9c6b3', 'D':'e4dfb5', 'd':'263b49', 'e':'ca9b73'},
        'rows': [
            '', '', '', '         OO', '        OHSO',
            '  OO  OOHHHBOO', '  OBSOHBBBBBBBO', '  OBBSHBBBBdBBO',
            '   OSHBBBBBdBeO', '  OBBSBBBBBBBBO', '  OBSODDDDDDdO',
            '  OO  OOSSSOO', '        OSO', '         O', '', ''],
    },
    'witch_coin': {
        'palette': {'O':'493846', 'B':'d9ab62', 'S':'a46b45', 'H':'f4d88d', 'D':'68516f', 'd':'fff0b8', 'e':'99768d'},
        'rows': [
            '', '      OOOO', '    OOHHHBOO', '   OHdHHBBBBO',
            '  OHdBBBBBBBSO', '  OHBBBBDBdBSO', ' OHBBBBDDBBBBSO',
            ' OHBBBDDeDBBBSO', ' OHBBBDDDDBBBSO', ' OHBBDDeeDDBBSO',
            '  OBDDDDDDBBSO',
            '  OBBBBBBBBSSO', '   OBSSSSSSSO', '    OOSSSSOO', '      OOOO', ''],
    },
}

def chunk(kind, payload):
    return struct.pack('<IH', len(payload) + 6, kind) + payload

def aseprite_bytes(layers, layer_flags=1):
    chunks = []
    for name in LAYERS:
        encoded = name.encode('utf-8')
        payload = struct.pack('<HHHHHHB', layer_flags, 0, 0, 0, 0, 0, 255) + bytes(3)
        chunks.append(chunk(0x2004, payload + struct.pack('<H', len(encoded)) + encoded))
    for i, im in enumerate(layers):
        payload = struct.pack('<HhhBHh', i, 0, 0, 255, 2, 0) + bytes(5)
        payload += struct.pack('<HH', 16, 16) + zlib.compress(im.tobytes())
        chunks.append(chunk(0x2005, payload))
    body = b''.join(chunks)
    frame = struct.pack('<IHHHHI', len(body)+16, 0xF1FA, len(chunks), 100, 0, 0) + body
    header = bytearray(128)
    struct.pack_into('<IHHHHHIH', header, 0, 128+len(frame), 0xA5E0, 1, 16, 16, 32, 1, 100)
    struct.pack_into('<HBBhhHH', header, 32, 0, 1, 1, 0, 0, 16, 16)
    return bytes(header) + frame

def author(spec):
    images = [Image.new('RGBA', (16,16)) for _ in LAYERS]
    assert len(spec['rows']) == 16
    for y, row in enumerate(spec['rows']):
        assert len(row) <= 16, (y, row)
        for x, char in enumerate(row):
            if char == ' ':
                continue
            color = tuple(bytes.fromhex(spec['palette'][char])) + (255,)
            layer = 0 if char == 'O' else 1 if char == 'B' else 2 if char in 'SH' else 3
            images[layer].putpixel((x,y), color)
    composite = Image.new('RGBA', (16,16))
    for im in images:
        composite = Image.alpha_composite(composite, im)
    return images, composite

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--replace', action='store_true', help='Explicitly refresh this resource set')
    args = parser.parse_args()
    targets = [ROOT / (name + ext) for name in SPECS for ext in ('.png', '.aseprite')]
    targets += [ROOT/'preview_nearest_16x.png']
    for path in targets:
        if path.exists() and not args.replace:
            raise FileExistsError(f'Refusing to overwrite {path}')
    sprites = {}
    for name, spec in SPECS.items():
        layers, image = author(spec)
        (ROOT/(name+'.aseprite')).write_bytes(aseprite_bytes(layers))
        image.save(ROOT/(name+'.png'))
        sprites[name] = image
    # Checkerboard is confined to this review image, not the asset PNGs.
    preview = Image.new('RGB', (len(sprites)*200+24, 392), '#24252c')
    draw = ImageDraw.Draw(preview)
    font = ImageFont.load_default(size=18)
    for i, (name, image) in enumerate(sprites.items()):
        left, top = 24 + i*200, 20
        for y in range(16):
            for x in range(16):
                fill = '#44454d' if (x//2+y//2)%2 else '#383940'
                draw.rectangle((left+x*10,top+y*10,left+x*10+9,top+y*10+9), fill=fill)
        enlarged = image.resize((160,160), Image.Resampling.NEAREST)
        preview.paste(enlarged, (left,top), enlarged)
        draw.text((left, 198), name.replace('_',' ').upper(), fill='#ded6c9', font=font)
        draw.text((left, 226), '16 x 16 / RGBA / 4 layers', fill='#9a989f', font=ImageFont.load_default(size=13))
        for column, background in enumerate(('#f3e2bd', '#302839')):
            x = left+column*84
            draw.rectangle((x,260,x+71,331),fill=background)
            actual = image.resize((48,48), Image.Resampling.NEAREST)
            preview.paste(actual,(x+12,272),actual)
        preview.paste(image,(left+12,352),image)
        draw.text((left+40,354),'1x native',fill='#9a989f',font=ImageFont.load_default(size=13))
    preview.save(ROOT/'preview_nearest_16x.png')
    # Preserve the established preview filename for existing links.
    manifest = {'revision':2, 'canvas':[16,16], 'light':'upper-left', 'alpha':[0,255],
                'method':'Authored native pixel maps; no image resampling or reference pixel extraction',
                'assets':{name:{'png':name+'.png','source':name+'.aseprite',
                               'layers':LAYERS,'png_sha256':hashlib.sha256((ROOT/(name+'.png')).read_bytes()).hexdigest()}
                          for name in SPECS}}
    (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(f'Created {len(sprites)} native 16x16 PNGs, layered Aseprite sources, manifest and preview.')

if __name__ == '__main__':
    main()
