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
    dict(id="mori", name="梅布尔", kind="resident", style="braids", hat="8fb07c", cloth="8fb07c", hair="d9926e", skin="ffd8b4", eye="7a5340", prop="leaf", apron="fff1d6"),
    dict(id="ember", name="布兰", kind="resident", style="short", head="cap", hat="d4a27e", cloth="d4a27e", hair="f2d49a", skin="ffe4c8", eye="6e4e3c", prop="hammer", apron="8a5e5c"),
    dict(id="nagi", name="玛伦", kind="resident", style="bob", hat="8ab4d2", cloth="8ab4d2", hair="7a6486", skin="e8b49e", eye="5e4638", prop="satchel", tip=-1),
    dict(id="lumi", name="海泽尔", kind="resident", style="long", hat="d8a6c4", cloth="d8a6c4", hair="eeeaf4", skin="ffd8b4", eye="7a5340", prop="book", tip=1),
    dict(id="aster", name="塞勒涅", kind="resident", style="locks", hat="9cc0c6", cloth="9cc0c6", hair="d9926e", skin="ffe4c8", eye="6e4e3c", prop="star", tip=1),
    dict(id="toma", name="托宾", kind="resident", style="curls", head="beret", hat="c898ae", cloth="c898ae", hair="f2d49a", skin="e8b49e", eye="5e4638", prop="spoon", apron="fff1d6"),
    dict(id="pip", name="皮平", kind="resident", style="short", head="cap", hat="e0b87c", cloth="e0b87c", hair="7a6486", skin="ffd8b4", eye="7a5340", prop="goggles"),
    dict(id="reed", name="罗文", kind="resident", style="braids", hat="9cbc9e", cloth="9cbc9e", hair="eeeaf4", skin="ffe4c8", eye="6e4e3c", prop="reeds", wide=True, tip=-1),
    dict(id="yuki", name="阿芙琳", kind="resident", style="bob", hat="c8cce6", cloth="c8cce6", hair="d9926e", skin="e8b49e", eye="5e4638", prop="letter", tip=1),
    dict(id="orla", name="莫文", kind="resident", style="locks", hat="d2bc94", cloth="d2bc94", hair="f2d49a", skin="ffd8b4", eye="7a5340", prop="book", wide=True),
    dict(id="green_braids", name="绿帽棕辫", kind="customer", style="braids", hat="88ae78", cloth="9cbc88", hair="c88a64", skin="ffd8b4", eye="7a5340", prop="leaf", apron="fff1d6"),
    dict(id="blue_blonde", name="蓝帽浅金", kind="customer", style="bob", hat="88b0d4", cloth="a4b6d6", hair="f6dc9c", skin="ffe6c6", eye="6e4e3c", prop="satchel", tip=-1),
    dict(id="burgundy_curls", name="酒红帽卷发", kind="customer", style="curls", hat="c4849c", cloth="c894aa", hair="7c5e80", skin="e8b49e", eye="5e4638", prop="book", tip=1),
    dict(id="orange_short", name="橙帽短发", kind="customer", style="short", hat="e8b888", cloth="dcb094", hair="68667c", skin="f8c4aa", eye="6e4e3c", prop="satchel"),
    dict(id="cyan_gray", name="青帽灰发", kind="customer", style="locks", hat="88c0b8", cloth="9cc4c0", hair="e6e0ee", skin="ffdcc0", eye="7a5340", prop="star", tip=-1),
    dict(id="pink_longblue", name="粉帽深蓝长发", kind="customer", style="long", hat="e0a2bc", cloth="c8a2c4", hair="8488ae", skin="f4c8b4", eye="5e4638", prop="letter", tip=1),
    dict(id="yingluo", name="露辛达", kind="guide", style="bob", hat="7a9e88", cloth="a8bc9c", hair="b8b0d0", skin="ffdcc0", eye="6e4e3c", prop="lantern", tip=-1),
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
        start = 0 if s["kind"] in ("resident", "guide") else 2
        seq = [im.resize((192, 192), Image.Resampling.NEAREST) for im in frames[start:start + 4]]
        seq[0].save(OUT / (s["kind"] + "s") / (s["id"] + "-preview.gif"), save_all=True, append_images=seq[1:], duration=140 if s["kind"] in ("resident", "guide") else 500, loop=0, disposal=2)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--aseprite", default="C:/steam/steamapps/common/Aseprite/Aseprite.exe")
    parser.add_argument("--replace-generated", action="store_true")
    parser.add_argument("--export-only", action="store_true", help="Export edited native sources without redrawing them")
    parser.add_argument("--only", choices=[s["id"] for s in SPECS], help="Limit every write to one character and its manifest record")
    parser.add_argument("--extend-guide", action="store_true", help="Add guide movement, preserving the existing single-frame front pose")
    options = parser.parse_args()
    specs = [s for s in SPECS if not options.only or s["id"] == options.only]
    targets = [OUT / (s["kind"] + "s") / (s["id"] + ".aseprite") for s in specs]
    if options.extend_guide and (options.only != "yingluo" or options.export_only or options.replace_generated):
        parser.error("--extend-guide requires --only yingluo and cannot redraw/export other sources")
    if any(p.exists() for p in targets) and not options.replace_generated and not options.export_only and not options.extend_guide:
        parser.error("Sources already exist. Export edited sources directly in Aseprite; --replace-generated discards edits in NPC32 only.")
    assert OUT.is_relative_to(PROJECT / "Art") and "MyArt" not in OUT.parts
    before = originals()
    if not options.only: write_json(OUT / "myart-before.json", before)
    for folder in ("residents", "customers", "guides", "portraits"):
        (OUT / folder).mkdir(exist_ok=True)
    specs_path = OUT / "tools" / ("specs.lua" if not options.only else options.only + "-specs.lua")
    neutral = decode(targets[0])[0][0].tobytes() if options.extend_guide else None
    if options.extend_guide and len(decode(targets[0])[0]) != 1:
        parser.error("Guide already has animation; use --export-only --only yingluo to preserve edits")
    if not options.export_only:
        specs_path.write_text("return " + lua(specs) + "\n", encoding="utf-8")
        params = ["--script-param", "preserve_guide=" + targets[0].as_posix()] if options.extend_guide else []
        output = run([options.aseprite, "--batch", "--script-param", "out=" + OUT.as_posix(), "--script-param", "specs=" + specs_path.as_posix(), *params, "--script", OUT / "tools/draw_npcs.lua"])
        (OUT / ("authoring.log" if not options.only else options.only + "-authoring.log")).write_text(output + "\n", encoding="utf-8")
    assets, manifest = [], []
    for s, source in zip(specs, targets):
        png, metadata = source.with_suffix(".png"), source.with_suffix(".json")
        assert source.exists(), source
        run([options.aseprite, "--batch", source, "--sheet-type", "horizontal", "--sheet", png, "--format", "json-array", "--list-tags", "--list-layers", "--data", metadata])
        frames, durations = decode(source)
        count = 22 if s["kind"] == "resident" else 6 if s["kind"] == "customer" else 21
        assert len(frames) == count
        sheet = Image.open(png).convert("RGBA")
        assert sheet.size == (32 * count, 32)
        assert set(sheet.getchannel("A").get_flattened_data()) == {0, 255}
        for f, frame in enumerate(frames):
            assert frame.tobytes() == sheet.crop((f * 32, 0, (f + 1) * 32, 32)).tobytes(), (s["id"], f)
            assert frame.getbbox() and frame.getbbox()[3] == 32, (s["id"], f, "feet")
        if s["kind"] in ("resident", "guide"):
            for d in range(4):
                assert len({f.tobytes() for f in frames[d * 4:d * 4 + 4]}) == 4
        if s["kind"] != "guide":
            start = 16 if count == 22 else 0
            assert frames[start].tobytes() != frames[start + 1].tobytes()
            assert len({f.tobytes() for f in frames[start + 2:start + 6]}) == 4
        tags = json.loads(metadata.read_text(encoding="utf-8"))["meta"]["frameTags"]
        if s["kind"] == "guide":
            assert neutral is None or frames[16].tobytes() == neutral, "Original guide front pose changed"
            assert frames[16].tobytes() != frames[17].tobytes()
        if s["kind"] in ("resident", "guide"):
            portrait = OUT / "portraits" / (s["id"] + ".png")
            run([options.aseprite, "--batch", "--frame-range", "16,16", source, "--sheet", portrait])
            assert Image.open(portrait).convert("RGBA").tobytes() == frames[16].tobytes()
            if s["kind"] == "guide":
                # Export-only also updates the native single-frame portrait.
                run([options.aseprite, "--batch", "--frame-range", "16,16", source, "--save-as", portrait.with_suffix(".aseprite")])
        assets.append((s, frames))
        manifest.append(dict(id=s["id"], name=s["name"], kind=s["kind"], source=source.relative_to(OUT).as_posix(), png=png.relative_to(OUT).as_posix(), canvas=[32, 32], frames=count, layers=LAYERS, tags=tags, durations_ms=durations, palette_colors=len(set(sheet.get_flattened_data())) - 1, anchor=[16, 32], source_sha256=sha(source), png_sha256=sha(png)))
        print(f"PASS {s['id']}: native Aseprite 32x32, {count} frames, 6 editable layers, exact PNG match")
    assert originals() == before, "MyArt changed during authoring"
    combined = json.loads((OUT / "manifest.json").read_text(encoding="utf-8")) if options.only else dict(authoring="Aseprite native Lua Image:drawPixel and Sprite:saveAs; no raster imports, resizing or binary source-file writer", aseprite=options.aseprite, assets=[])
    if options.only:
        combined["assets"] = [manifest[0] if entry["id"] == options.only else entry for entry in combined["assets"]]
    else: combined["assets"] = manifest
    write_json(OUT / "manifest.json", combined)
    write_json(OUT / ("validation.json" if not options.only else options.only + "-validation.json"), dict(status="PASS", npc_count=len(assets), decoded_frames=sum(len(f) for _, f in assets), canvas=[32, 32], native_aseprite_authored=True, aseprite_reopen_export_verified=True, editable_layers=6, every_composite_matches_native_export=True, alpha=[0, 255], feet_anchor=[16, 32], all_walk_and_eat_frames_distinct=True, original_front_pose_preserved=neutral is not None, myart_unchanged=True, protected_originals=len(before)))
    if not options.only: preview(assets)
    elif options.only == "yingluo":
        guide_frames = assets[0][1]
        for direction, start in zip(("down", "up", "right", "left"), (0,4,8,12)):
            sequence = [frame.resize((192,192), Image.Resampling.NEAREST) for frame in guide_frames[start:start+4]]
            sequence[0].save(OUT / "guides" / ("yingluo-walk-" + direction + ".gif"), save_all=True, append_images=sequence[1:], duration=140, loop=0, disposal=2)
    print(f"PASS {len(assets)} NPCs / {sum(len(f) for _, f in assets)} frames; MyArt SHA256 unchanged ({len(before)} files)")


if __name__ == "__main__":
    main()
