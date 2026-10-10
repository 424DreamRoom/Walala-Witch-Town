"""Original native-resolution sprite authoring; no input image or resampling.
Run from project root: python Art/Icon/Resources16_Original/tools/build_resources.py
Outputs are guarded against overwriting. Only preview uses nearest-neighbor enlargement.
"""
from pathlib import Path
import struct
import zlib
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
LAYERS = ['Outline', 'Base color', 'Light and shadow', 'Details']
# Each character is one authored pixel. D/d/e are material or emblem details.
SPECS = {
    'wood': {
        'palette': {'O':'51473f', 'B':'907455', 'S':'705d49', 'H':'b49a72', 'D':'c4a67b', 'd':'8a694c', 'e':'a58660'},
        'rows': [
            '', '', '        OOOO', '     OOOHHBBO', '   OOHBBBBBBBO',
            '  OHDHOBBddBBSO', ' OHDDeOBBBBBBSO', ' OHDeDdOBddBBSO',
            ' OHDeDeOBBBSSSO', ' OBDeDdOBddSSSO', ' OBDDeeOBSSSSO',
            '  OBeeOBSSSSO', '   OOOOSSSOO', '      OOOO', '', ''],
    },
    'stone': {
        'palette': {'O':'4f5054', 'B':'92968f', 'S':'707873', 'H':'b6b9aa', 'D':'a4a99d', 'd':'666e6b'},
        'rows': [
            '', '', '      OOO', '    OOHHHOO', '   OHHHHHBBBO',
            '  OHHHDBBBBBBO', '  OHDBBBBBBBBBO', ' OBBBBDDBBBSSSO',
            ' OBBBBBBBDSSSSO', ' OBBDdBBSSSSSSO', '  OBBdSSSSSSSO',
            '   OSSSSSSSSO', '    OOOOOOOO', '', '', ''],
    },
    'gold': {
        'palette': {'O':'69573e', 'B':'c5aa69', 'S':'9b8050', 'H':'e0ca8d', 'D':'eee0ad', 'd':'b69959'},
        'rows': [
            '', '', '', '     OOOOOOO', '    OHHDHHHHO',
            '   OHHHHHHHHO', '  OHHHHHHHHHBO', ' OOOOOOOOOOOBBO',
            ' OBBBBBBBBBBBSO', '  OBBdBBBBBBSSO', '  OBBBBBBBSSSO',
            '   OSSSSSSSSO', '    OOOOOOOO', '', '', ''],
    },
    'iron_ore': {
        'palette': {'O':'454951', 'B':'777f87', 'S':'59636c', 'H':'9ba5a7', 'D':'c49a78', 'd':'936d57', 'e':'ddbd94'},
        'rows': [
            '', '', '     OOOO', '   OOHBBBOO', '  OHHeDBBBBO',
            '  OHBDdBBHBBO', ' OHBBBBBHeDBBO', ' OBBBBSBBBDdBO',
            ' OHBeDBBSSBSSO', ' OBBDdSSBSSSSO', '  OBBSSSDeSSO',
            '   OSSSSdSSO', '    OOOOOOO', '', '', ''],
    },
    'witch_coin': {
        'palette': {'O':'554b62', 'B':'ada0b7', 'S':'80758f', 'H':'d0bfd0', 'D':'51465d', 'd':'ead3a4', 'e':'b99b74'},
        'rows': [
            '', '     OOOOOO', '   OOHHHHHBOO', '  OHHBBBBBBBBO',
            '  OHBBBDDBddBO', ' OHBBBDDBdBBBSO', ' OHBBDDDDBddBSO',
            ' OHBBDDDDBBBBSO', ' OHBDDeeDBBBBSO',
            ' OHBDDDDDDBBBSO', '  OBBBBBBBBBSO', '  OBSSSSSSSSSO',
            '   OOSSSSSSOO', '     OOOOOO', '', ''],
    },
}

def chunk(kind, payload):
    return struct.pack('<IH', len(payload) + 6, kind) + payload

def aseprite_bytes(layers):
    chunks = []
    for name in LAYERS:
        encoded = name.encode('utf-8')
        payload = struct.pack('<HHHHHHB', 1, 0, 0, 0, 0, 0, 255) + bytes(3)
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
    targets = [ROOT / (name + ext) for name in SPECS for ext in ('.png', '.aseprite')]
    targets += [ROOT/'preview_nearest_16x.png']
    for path in targets:
        if path.exists():
            raise FileExistsError(f'Refusing to overwrite {path}')
    sprites = {}
    for name, spec in SPECS.items():
        layers, image = author(spec)
        (ROOT/(name+'.aseprite')).write_bytes(aseprite_bytes(layers))
        image.save(ROOT/(name+'.png'))
        sprites[name] = image
    # Checkerboard is confined to this review image, not the asset PNGs.
    preview = Image.new('RGB', (1440, 348), '#24252c')
    draw = ImageDraw.Draw(preview)
    font = ImageFont.load_default(size=18)
    for i, (name, image) in enumerate(sprites.items()):
        left, top = 16 + i*288, 20
        for y in range(16):
            for x in range(16):
                fill = '#44454d' if (x//2+y//2)%2 else '#383940'
                draw.rectangle((left+x*16,top+y*16,left+x*16+15,top+y*16+15), fill=fill)
        preview.paste(image.resize((256,256), Image.Resampling.NEAREST), (left,top), image.resize((256,256), Image.Resampling.NEAREST))
        draw.text((left, 290), name.replace('_',' ').upper(), fill='#ded6c9', font=font)
        draw.text((left, 317), '16 x 16 / RGBA / 4 layers', fill='#9a989f', font=ImageFont.load_default(size=13))
    preview.save(ROOT/'preview_nearest_16x.png')
    print('Created 5 native 16x16 PNGs, 5 four-layer Aseprite sources, and preview.')

if __name__ == '__main__':
    main()
