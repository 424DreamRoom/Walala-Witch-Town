"""Draw with installed Aseprite, export, reopen and verify the native source.

Requires Aseprite 1.3+ and Pillow. MyArt is strictly read-only.
Rebuild is explicit; export-only preserves edits made to the .aseprite source.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import struct
import subprocess

from PIL import Image, ImageDraw, ImageFont

ASSET = Path(__file__).resolve().parents[1]
ROOT = ASSET.parents[3]
OUT = ROOT / "output/witch-aseprite32"
ASEPRITE = Path(os.environ.get("ASEPRITE_BIN", "C:/steam/steamapps/common/Aseprite/Aseprite.exe"))
SOURCE = ASSET / "walala-witch.aseprite"
DIRECTIONS = ("down", "up", "right", "left")
ACTIONS = ("idle", "walk", "run", "cast", "fish-cast", "fish-wait", "fish-reel")


def protected_hashes():
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (ROOT / "MyArt").rglob("*") if p.is_file()}


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def run(args):
    info = subprocess.STARTUPINFO()
    info.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    info.wShowWindow = 0
    result = subprocess.run([str(ASEPRITE), "--batch", "--noinapp", *map(str, args)],
                            cwd=ROOT, capture_output=True, text=True, startupinfo=info, timeout=90)
    if len(result.stdout)<500:
        print(result.stdout.strip())
    if result.returncode or "Error" in result.stderr:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout + result.stderr


def previews(images, tags, durations):
    bg = "#302b40"
    ink = "#f5e3c5"
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 15)
    small = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 12)
    width, height = 624, 688
    def panel():
        result = Image.new("RGB", (width, height), bg)
        draw = ImageDraw.Draw(result)
        draw.text((20, 12), "WALALA / ASEPRITE ORIGINAL", fill=ink, font=font)
        draw.text((20, 34), "32 x 32  |  152 frames  |  9 layers  |  24 colors", fill="#a5a0b9", font=small)
        for col, direction in enumerate(DIRECTIONS):
            draw.text((110 + col * 128, 64), direction.upper(), fill=ink, font=small)
        for row, action in enumerate(ACTIONS[:4]):
            draw.text((16, 132 + row * 144), action.upper(), fill="#a1e1d3" if action=="cast" else ink, font=small)
            for col in range(4):
                x, y = 100 + col*128, 88 + row*144
                draw.rectangle((x,y,x+119,y+127),fill="#3b354d")
                draw.line((x+12,y+125,x+108,y+125),fill="#61516c")
        draw.text((20, 670), "WOOD / ORE / WEEDS = CAST", fill="#a1e1d3", font=small)
        return result
    def sample(tag, elapsed):
        length = sum(durations[tag["from"]:tag["to"]+1])
        elapsed %= length
        for index in range(tag["from"], tag["to"]+1):
            if elapsed < durations[index]: return images[index]
            elapsed -= durations[index]
        return images[tag["to"]]
    still = panel()
    for row, action in enumerate(ACTIONS[:4]):
        for col,direction in enumerate(DIRECTIONS):
            tag=tags[f"{action}-{direction}"]
            index=tag["from"]+(4 if action=="cast" else 2 if action=="run" else 0)
            tile=images[index].resize((128,128),Image.Resampling.NEAREST)
            still.paste(tile,(96+col*128,88+row*144),tile)
    still.save(ASSET / "design-preview.png")
    animated=[]
    for step in range(60):
        image=panel()
        for row,action in enumerate(ACTIONS[:4]):
            for col,direction in enumerate(DIRECTIONS):
                tag=tags[f"{action}-{direction}"]
                tile=sample(tag,step*70).resize((128,128),Image.Resampling.NEAREST)
                image.paste(tile,(96+col*128,88+row*144),tile)
        animated.append(image)
    animated[0].save(ASSET / "animations-preview.gif", save_all=True, append_images=animated[1:],
                     duration=70, loop=0, optimize=False)
    contact=Image.new("RGB",(8*144,19*162),bg)
    draw=ImageDraw.Draw(contact)
    for index,image in enumerate(images):
        x,y=index%8*144+8,index//8*162+24
        tile=image.resize((128,128),Image.Resampling.NEAREST)
        contact.paste(tile,(x,y),tile)
        draw.text((x,y-20),str(index),fill=ink,font=small)
    contact.save(ASSET / "contact-sheet.png")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--redraw", action="store_true", help="Explicitly rebuild the native source from Lua")
    args=parser.parse_args()
    assert ASSET.relative_to(ROOT).as_posix()=="Art/Character/Storybook/WalalaWitchAseprite32"
    OUT.mkdir(parents=True,exist_ok=True)
    before=protected_hashes()
    write_json(OUT/"myart-before.json",before)
    try:
        if args.redraw:
            log=run(["--script-param",f"out={ASSET.as_posix()}","--script",ASSET/"tools/draw_witch.lua"])
            (OUT/"draw.log").write_text(log,encoding="utf-8")
        assert SOURCE.exists(), "Use --redraw for the first build"
        assert struct.unpack_from("<HHHH",SOURCE.read_bytes(),4)==(0xA5E0,152,32,32)
        log=run(["--list-tags","--list-layers",SOURCE,"--sheet-type","rows","--sheet-columns","8",
                 "--sheet",ASSET/"walala-witch.png","--data",ASSET/"walala-witch.json","--format","json-array"])
        (OUT/"export.log").write_text(log,encoding="utf-8")
        # A second Aseprite process reopens the actual .aseprite, independently re-exports.
        run([SOURCE,"--sheet-type","rows","--sheet-columns","8","--sheet",OUT/"roundtrip.png","--data",OUT/"roundtrip.json"])
        data=json.loads((ASSET/"walala-witch.json").read_text(encoding="utf-8"))
        sheet=Image.open(ASSET/"walala-witch.png").convert("RGBA")
        reopened=Image.open(OUT/"roundtrip.png").convert("RGBA")
        assert sheet.size==(256,608) and reopened.tobytes()==sheet.tobytes()
        assert len(data["frames"])==152
        layers=[layer["name"] for layer in data["meta"]["layers"]]
        assert len(layers)==9
        tags={tag["name"]:tag for tag in data["meta"]["frameTags"]}
        assert set(tags)=={f"{a}-{d}" for a in ACTIONS for d in DIRECTIONS}
        cursor=0
        for direction in DIRECTIONS:
            for action,count in zip(ACTIONS,(4,8,8,8,4,2,4)):
                tag=tags[f"{action}-{direction}"]
                assert (tag["from"],tag["to"])==(cursor,cursor+count-1), tag
                cursor+=count
        assert cursor==152
        images=[]; durations=[]; palette=set(); bounds=[]
        for index,entry in enumerate(data["frames"]):
            f=entry["frame"]
            assert (f["w"],f["h"])==(32,32) and not entry["trimmed"] and not entry["rotated"]
            assert (f["x"],f["y"])==(index%8*32,index//8*32)
            image=sheet.crop((f["x"],f["y"],f["x"]+32,f["y"]+32))
            assert image.getbbox() is not None
            assert set(image.getchannel("A").get_flattened_data())=={0,255}
            palette.update(c for c in image.get_flattened_data() if c[3])
            images.append(image); durations.append(entry["duration"]); bounds.append(image.getbbox())
        assert len(palette)==24, len(palette)
        for d in DIRECTIONS:
            walk=tags[f"walk-{d}"]; running=tags[f"run-{d}"]
            assert all(images[walk["from"]+p].tobytes()!=images[running["from"]+p].tobytes() for p in range(8))
            for action in ("walk","run","cast"):
                tag=tags[f"{action}-{d}"]
                assert len({images[i].tobytes() for i in range(tag["from"],tag["to"]+1)})>=6
        manifest={"canvas":{"width":32,"height":32},"pivot":{"x":16,"y":32},
                  "source_application":"Aseprite 1.3.18.6","source":"walala-witch.aseprite",
                  "sheet":"walala-witch.png","columns":8,"rows":19,"frame_count":152,
                  "layers":layers,"animations":[dict(tag,durations_ms=durations[tag["from"]:tag["to"]+1],
                  loop=tag["name"].split("-")[0] in ("idle","walk","run") or tag["name"].startswith("fish-wait"))
                  for tag in tags.values()],"harvest_animation":{"wood":"cast","ore":"cast","weed":"cast","farm":"cast"}}
        write_json(ASSET/"character-manifest.json",manifest)
        previews(images,tags,durations)
        write_json(ASSET/"validation-report.json",{"status":"PASS","canvas":[32,32],"frames":152,
            "layers":layers,"tags":len(tags),"opaque_colors":len(palette),"binary_alpha":True,
            "aseprite_created_and_reopened":True,"reopened_pixels_exact":True,"run_has_independent_poses":True,
            "source_sha256":hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            "myart_hashes_unchanged":protected_hashes()==before})
        print("PASS: Aseprite native source reopened; 152 frames / 28 tags / 9 layers / 24 colors; MyArt unchanged")
    finally:
        assert protected_hashes()==before, "Protected MyArt hash mismatch"


if __name__=="__main__":
    main()
