"""Independent Aseprite binary reader and PNG round-trip verification."""
from pathlib import Path
import struct
import zlib
import json
import hashlib
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
NAMES = ['wood', 'stone', 'gold', 'iron_ore', 'witch_coin']
EXPECTED_LAYERS = ['Outline', 'Base color', 'Light and shadow', 'Details']

def validate(name, expected_layer_flags=1):
    source = ROOT / (name + '.aseprite')
    data = source.read_bytes()
    size, magic, frames, width, height, depth = struct.unpack_from('<IHHHHH', data)
    assert size == len(data) and magic == 0xA5E0
    assert (frames, width, height, depth) == (1,16,16,32)
    frame_size, frame_magic, count, duration = struct.unpack_from('<IHHH', data,128)
    assert frame_magic == 0xF1FA and frame_size == len(data)-128 and duration == 100
    position = 144
    layers, cels = [], {}
    for _ in range(count):
        chunk_size, kind = struct.unpack_from('<IH', data, position)
        assert chunk_size >= 6 and position + chunk_size <= len(data)
        payload = data[position+6:position+chunk_size]
        if kind == 0x2004:
            flags, layer_type, child_level, _, _, blend = struct.unpack_from('<HHHHHH',payload)
            assert (flags, layer_type, child_level, blend, payload[12]) == (expected_layer_flags,0,0,0,255)
            length = struct.unpack_from('<H',payload,16)[0]
            assert len(payload) == 18+length
            layers.append(payload[18:].decode('utf-8'))
        elif kind == 0x2005:
            index,x,y,opacity,cel_type,z = struct.unpack_from('<HhhBHh',payload)
            assert (x,y,opacity,cel_type,z) == (0,0,255,2,0)
            assert index not in cels
            w,h = struct.unpack_from('<HH',payload,16)
            assert (w,h) == (16,16)
            pixels = zlib.decompress(payload[20:])
            assert len(pixels) == w*h*4
            image = Image.frombytes('RGBA',(w,h),pixels)
            assert image.getbbox() is not None
            cels[index] = image
        else:
            raise AssertionError(f'Unexpected chunk {kind:x}')
        position += chunk_size
    assert position == len(data) and layers == EXPECTED_LAYERS
    assert count == 8 and set(cels) == set(range(4))
    combined = Image.new('RGBA',(16,16))
    for index in range(4):
        combined = Image.alpha_composite(combined,cels[index])
    with Image.open(ROOT/(name+'.png')) as png:
        assert png.format == 'PNG' and png.mode == 'RGBA' and png.size == (16,16)
        assert set(png.getchannel('A').getdata()) == {0,255}
        assert combined.tobytes() == png.tobytes()
        # Padding must be actually transparent, with no baked checkerboard.
        assert all(png.getpixel((x,y))[3] == 0 for x in range(16) for y in (0,15))
        assert all(png.getpixel((x,y))[3] == 0 for y in range(16) for x in (0,15))
        return {'asset':name, 'size':[16,16], 'mode':'RGBA', 'alpha_values':[0,255],
                'opaque_pixels':sum(a == 255 for a in png.getchannel('A').getdata()),
                'palette_colors':len({p for p in png.getdata() if p[3]}),
                'aseprite_magic':'0xA5E0', 'frames':frames, 'layers':layers,
                'cel_count':len(cels), 'source_png_pixel_match':True,
                'source_sha256':hashlib.sha256(data).hexdigest()}

if __name__ == '__main__':
    result = {'method':'Independent binary parsing, zlib cel decoding, exact RGBA recomposition comparison',
              'aseprite_application_tested':False, 'assets':[validate(n) for n in NAMES]}
    report = ROOT/'validation_report.json'
    report.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))
