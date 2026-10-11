"""Author NPCs inside Aseprite, then export and independently verify native cels.

MyArt is read-only. All generated output is constrained to Art/Characters/NPC32.
Existing sources are never replaced without --replace-generated.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import zlib

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parents[1]
PROJECT = OUT.parents[2]
LAYERS = ["Boots", "Clothing", "Face and hands", "Hair", "Headwear", "Accessories"]
SPECS = [
    dict(id="mori", name="茉莉", kind="resident", style="braids", hat="7c9c7a", cloth="7c9c7a", hair="b98065", skin="ecc5a3", prop="leaf", apron="efdec1"),
    dict(id="ember", name="余烬", kind="resident", style="short", head="cap", hat="b68b76", cloth="b68b76", hair="e0c28e", skin="f0d5bb", prop="hammer", apron="795759"),
    dict(id="nagi", name="澪", kind="resident", style="bob", hat="7b9eb9", cloth="7b9eb9", hair="655575", skin="d09b88", prop="satchel", tip=-1),
    dict(id="lumi", name="露米", kind="resident", style="long", hat="bc92ad", cloth="bc92ad", hair="d5d2dd", skin="ecc5a3", prop="book", tip=1),
    dict(id="aster", name="星芒", kind="resident", style="locks", hat="8aa7ad", cloth="8aa7ad", hair="b98065", skin="f0d5bb", prop="star", tip=1),
    dict(id="toma", name="陶陶", kind="resident", style="curls", head="beret", hat="b18499", cloth="b18499", hair="e0c28e", skin="d09b88", prop="spoon", apron="efdec1"),
    dict(id="pip", name="皮普", kind="resident", style="short", head="cap", hat="c5a16f", cloth="c5a16f", hair="655575", skin="ecc5a3", prop="goggles"),
    dict(id="reed", name="芦苇", kind="resident", style="braids", hat="89a590", cloth="89a590", hair="d5d2dd", skin="f0d5bb", prop="reeds", wide=True, tip=-1),
    dict(id="yuki", name="霜铃", kind="resident", style="bob", hat="b4b8d2", cloth="b4b8d2", hair="b98065", skin="d09b88", prop="letter", tip=1),
    dict(id="orla", name="奥萝", kind="resident", style="locks", hat="b9a481", cloth="b9a481", hair="e0c28e", skin="ecc5a3", prop="book", wide=True),
    dict(id="green_braids", name="绿帽棕辫", kind="customer", style="braids", hat="77976e", cloth="88a47b", hair="ad7856", skin="ecc5a3", prop="leaf", apron="efdec1"),
    dict(id="blue_blonde", name="蓝帽浅金", kind="customer", style="bob", hat="7898b8", cloth="8e9fbd", hair="edcc8a", skin="f5d9b7", prop="satchel", tip=-1),
    dict(id="burgundy_curls", name="酒红帽卷发", kind="customer", style="curls", hat="ab7187", cloth="b08098", hair="69516d", skin="d09b88", prop="book", tip=1),
    dict(id="orange_short", name="橙帽短发", kind="customer", style="short", hat="d2a079", cloth="c69b80", hair="555368", skin="e5b09a", prop="satchel"),
    dict(id="cyan_gray", name="青帽灰发", kind="customer", style="locks", hat="77a8a2", cloth="89aaa7", hair="d0cbd9", skin="f0cbb3", prop="star", tip=-1),
    dict(id="pink_longblue", name="粉帽深蓝长发", kind="customer", style="long", hat="c78ea5", cloth="b28ead", hair="707599", skin="e2b6a3", prop="letter", tip=1),
    dict(id="yingluo", name="萤萝", kind="guide", style="bob", hat="668578", cloth="91a487", hair="a49bb7", skin="f0cbb3", prop="lantern", tip=-1),
]


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def originals():
    return {p.relative_to(PROJECT).as_posix(): sha(p)
            for p in sorted((PROJECT / "MyArt").rglob("*")) if p.is_file()}


def lua(value):
    if isinstance(value, dict):
        return "{" + ",".join(k + "=" + lua(v) for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(map(lua, value)) + "}"
    if isinstance(value, bool):
        return "true" if value else "false"
    return json.dumps(value, ensure_ascii=False)


def run(args):
    result = subprocess.run(list(map(str, args)), cwd=PROJECT, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=90)
    if result.returncode or "Error" in result.stdout or "Error" in result.stderr:
        raise RuntimeError(f"Aseprite failed: {result.stdout}\n{result.stderr}")
    return result.stdout.strip() or result.stderr.strip()


def decode(source):
    """Independent reader, including trimmed and linked Aseprite cels."""
    data = source.read_bytes()
    length, magic, count, w, h, depth = struct.unpack_from("<IHHHHH", data)
    assert (length, magic, w, h, depth) == (len(data), 0xA5E0, 32, 32, 32), source
    pos, layers, cached, frames, durations = 128, [], {}, [], []
    for f in range(count):
        size, marker, chunks, ms = struct.unpack_from("<IHHH", data, pos)
        assert marker == 0xF1FA
        durations.append(ms)
        end = pos + size
        chunks = struct.unpack_from("<I", data, pos + 12)[0] or chunks
        pos += 16
        cels = {}
        for _ in range(chunks):
            n, kind = struct.unpack_from("<IH", data, pos)
            p = data[pos + 6:pos + n]
            pos += n
            if kind == 0x2004:
                flags, layer_type = struct.unpack_from("<HH", p)
                name_length = struct.unpack_from("<H", p, 16)[0]
                assert flags & 1 and flags & 2 and layer_type == 0
                layers.append(p[18:18 + name_length].decode("utf-8"))
            elif kind == 0x2005:
                layer, x, y, opacity, typ = struct.unpack_from("<HhhBH", p)
                assert opacity == 255
                if typ == 1:
                    ref = struct.unpack_from("<H", p, 16)[0]
                    image = cached[(ref, layer)][0]
                else:
                    assert typ in (0, 2)
                    cw, ch = struct.unpack_from("<HH", p, 16)
                    pixels = zlib.decompress(p[20:]) if typ == 2 else p[20:]
                    image = Image.frombytes("RGBA", (cw, ch), pixels)
                cels[layer] = image, x, y
                cached[f, layer] = image, x, y
        assert pos == end
        result = Image.new("RGBA", (w, h))
        for layer in sorted(cels):
            im, x, y = cels[layer]
            result.alpha_composite(im, (x, y))
        frames.append(result)
    assert pos == len(data) and layers == LAYERS
    assert {k[1] for k in cached} == set(range(6))
    return frames, durations


def preview(assets):
    scale, tile_w, tile_h = 6, 220, 254
    im = Image.new("RGB", (tile_w * 6, tile_h * 3), "#f1e7d7")
    draw = ImageDraw.Draw(im)
    font_path = Path("C:/Windows/Fonts/msyh.ttc")
    font = ImageFont.truetype(str(font_path), 18) if font_path.exists() else ImageFont.load_default()
    for i, (s, frames) in enumerate(assets):
        x, y = (i % 6) * tile_w, (i // 6) * tile_h
        draw.rounded_rectangle((x + 5, y + 5, x + tile_w - 6, y + tile_h - 6), radius=10, fill="#fff8eb")
        frame = frames[16 if s["kind"] == "resident" else 0]
        for gy in range(8):
            for gx in range(8):
                if (gx + gy) % 2 == 0:
                    draw.rectangle((x + 14 + gx * 24, y + 12 + gy * 24, x + 37 + gx * 24, y + 35 + gy * 24), fill="#ece4d6")
        im.paste(frame.resize((192, 192), Image.Resampling.NEAREST), (x + 14, y + 12), frame.resize((192, 192), Image.Resampling.NEAREST))
        draw.text((x + 14, y + 209), s["name"], fill="#453447", font=font)
        draw.text((x + 14, y + 233), s["id"], fill="#746879")
    im.save(OUT / "preview.png")
    directions = Image.new("RGBA", (32 * 8, 32 * 10))
    for row, (s, frames) in enumerate(assets[:10]):
        for col, f in enumerate((16, 0, 4, 8, 12, 18, 19, 20)):
            directions.alpha_composite(frames[f], (col * 32, row * 32))
    directions.resize((1024, 1280), Image.Resampling.NEAREST).save(OUT / "directions-preview.png")
    for s, frames in assets:
        if len(frames) < 2:
            continue
        start = 0 if s["kind"] == "resident" else 2
        seq = [im.resize((192, 192), Image.Resampling.NEAREST) for im in frames[start:start + 4]]
        seq[0].save(OUT / (s["kind"] + "s") / (s["id"] + "-preview.gif"), save_all=True, append_images=seq[1:], duration=140 if s["kind"] == "resident" else 500, loop=0, disposal=2)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--aseprite", default="C:/steam/steamapps/common/Aseprite/Aseprite.exe")
    parser.add_argument("--replace-generated", action="store_true")
    parser.add_argument("--export-only", action="store_true", help="Export edited native sources without redrawing them")
    options = parser.parse_args()
    targets = [OUT / (s["kind"] + "s") / (s["id"] + ".aseprite") for s in SPECS]
    if any(p.exists() for p in targets) and not options.replace_generated and not options.export_only:
        parser.error("Sources already exist. Export edited sources directly in Aseprite; --replace-generated discards edits in NPC32 only.")
    assert OUT.is_relative_to(PROJECT / "Art") and "MyArt" not in OUT.parts
    before = originals()
    write_json(OUT / "myart-before.json", before)
    for folder in ("residents", "customers", "guides", "portraits"):
        (OUT / folder).mkdir(exist_ok=True)
    specs_path = OUT / "tools" / "specs.lua"
    if not options.export_only:
        specs_path.write_text("return " + lua(SPECS) + "\n", encoding="utf-8")
        output = run([options.aseprite, "--batch", "--script-param", "out=" + OUT.as_posix(), "--script-param", "specs=" + specs_path.as_posix(), "--script", OUT / "tools/draw_npcs.lua"])
        (OUT / "authoring.log").write_text(output + "\n", encoding="utf-8")
    assets, manifest = [], []
    for s, source in zip(SPECS, targets):
        png, metadata = source.with_suffix(".png"), source.with_suffix(".json")
        assert source.exists(), source
        run([options.aseprite, "--batch", source, "--sheet-type", "horizontal", "--sheet", png, "--format", "json-array", "--list-tags", "--list-layers", "--data", metadata])
        frames, durations = decode(source)
        count = 22 if s["kind"] == "resident" else 6 if s["kind"] == "customer" else 1
        assert len(frames) == count
        sheet = Image.open(png).convert("RGBA")
        assert sheet.size == (32 * count, 32)
        assert set(sheet.getchannel("A").get_flattened_data()) == {0, 255}
        for f, frame in enumerate(frames):
            assert frame.tobytes() == sheet.crop((f * 32, 0, (f + 1) * 32, 32)).tobytes(), (s["id"], f)
            assert frame.getbbox() and frame.getbbox()[3] == 32, (s["id"], f, "feet")
        if s["kind"] == "resident":
            for d in range(4):
                assert len({f.tobytes() for f in frames[d * 4:d * 4 + 4]}) == 4
        if count > 1:
            start = 16 if count == 22 else 0
            assert frames[start].tobytes() != frames[start + 1].tobytes()
            assert len({f.tobytes() for f in frames[start + 2:start + 6]}) == 4
        tags = json.loads(metadata.read_text(encoding="utf-8"))["meta"]["frameTags"]
        if s["kind"] == "resident":
            portrait = OUT / "portraits" / (s["id"] + ".png")
            run([options.aseprite, "--batch", "--frame-range", "16,16", source, "--sheet", portrait])
            assert Image.open(portrait).convert("RGBA").tobytes() == frames[16].tobytes()
        assets.append((s, frames))
        manifest.append(dict(id=s["id"], name=s["name"], kind=s["kind"], source=source.relative_to(OUT).as_posix(), png=png.relative_to(OUT).as_posix(), canvas=[32, 32], frames=count, layers=LAYERS, tags=tags, durations_ms=durations, palette_colors=len(set(sheet.get_flattened_data())) - 1, anchor=[16, 32], source_sha256=sha(source), png_sha256=sha(png)))
        print(f"PASS {s['id']}: native Aseprite 32x32, {count} frames, 6 editable layers, exact PNG match")
    assert originals() == before, "MyArt changed during authoring"
    write_json(OUT / "manifest.json", dict(authoring="Aseprite native Lua Image:drawPixel and Sprite:saveAs; no raster imports, resizing or binary source-file writer", aseprite=options.aseprite, assets=manifest))
    write_json(OUT / "validation.json", dict(status="PASS", npc_count=len(assets), decoded_frames=sum(len(f) for _, f in assets), canvas=[32, 32], native_aseprite_authored=True, aseprite_reopen_export_verified=True, editable_layers=6, every_composite_matches_native_export=True, alpha=[0, 255], feet_anchor=[16, 32], all_walk_and_eat_frames_distinct=True, myart_unchanged=True, protected_originals=len(before)))
    preview(assets)
    print(f"PASS {len(assets)} NPCs / {sum(len(f) for _, f in assets)} frames; MyArt SHA256 unchanged ({len(before)} files)")


if __name__ == "__main__":
    main()
