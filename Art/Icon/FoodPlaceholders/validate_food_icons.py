"""Check source provenance, native pixels, complete coverage, and MyArt protection."""
from pathlib import Path
from io import BytesIO
import hashlib
import json
import struct
import zipfile
import zlib
from PIL import Image

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]
manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
content = json.loads((PROJECT / "Scenes/Campaign/content.json").read_text(encoding="utf-8"))
required = set(content["items"]) - {"wood", "ore", "iron", "scrap", "crystal"}
required |= {"dish_" + recipe["id"] for recipe in content["recipes"]}
assert required <= manifest["icons"].keys()
sha = lambda data: hashlib.sha256(data).hexdigest()
for name, digest in manifest["archives"].items():
    assert sha((ROOT / "sources" / name).read_bytes()) == digest
for source, digest in manifest["myart_sha256"].items():
    assert sha((PROJECT / source).read_bytes()) == digest, "MyArt source changed"
for entry in manifest["assets"]:
    output = Image.open(PROJECT / entry["png"]).convert("RGBA")
    assert list(output.size) == entry["size"] and output.getbbox()
    assert sha(output.tobytes()) == entry["rgba_sha256"]
    assert output.getchannel("A").getextrema()[0] == 0, entry["id"]
    if entry["origin"] == "CC0":
        if entry["archive"].endswith(".png"):
            data = (ROOT / "sources" / entry["archive"]).read_bytes()
            x,y,w,h = entry["member"]
            expected = Image.open(BytesIO(data)).convert("RGBA").crop((x,y,x+w,y+h))
        else:
            with zipfile.ZipFile(ROOT / "sources" / entry["archive"]) as archive:
                data = archive.read(entry["member"])
            expected = Image.open(BytesIO(data)).convert("RGBA")
        assert sha(data) == entry["source_sha256"]
    else:
        data = (PROJECT / entry["source"]).read_bytes()
        assert sha(data) == entry["source_sha256"]
        if Path(entry["source"]).suffix == ".png":
            expected = Image.open(BytesIO(data)).convert("RGBA")
        else:
            # The three actual originals each contain one visible, full-opacity cel.
            w,h = struct.unpack_from("<HH",data,8)
            assert struct.unpack_from("<H",data,6)[0] == 1
            position, chunks, cells = 144, struct.unpack_from("<H",data,134)[0], []
            for _ in range(chunks):
                length,kind = struct.unpack_from("<IH",data,position)
                if kind == 0x2005: cells.append(data[position+6:position+length])
                position += length
            assert len(cells) == 1
            cel = cells[0]
            x,y,opacity,kind = struct.unpack_from("<hhBH",cel,2)
            cw,ch = struct.unpack_from("<HH",cel,16)
            assert opacity == 255 and kind == 2
            expected = Image.new("RGBA",(w,h))
            expected.paste(Image.frombytes("RGBA",(cw,ch),zlib.decompress(cel[20:])),(x,y))
    assert expected.size == output.size and expected.tobytes() == output.tobytes(), entry["id"]
for key in ["egg", "tomato", "bread", "dish_wheat_bread"]:
    assert next(e for e in manifest["assets"] if e["id"] == key)["origin"] == "MyArt"
print("FOOD SOURCE VALIDATION PASS", len(manifest["assets"]), "native PNGs;", len(required), "required foods; MyArt hashes and pixels match")
