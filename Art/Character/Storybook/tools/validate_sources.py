"""Independently parse layered Aseprite masters and compare exported PNG/JSON."""
import hashlib
import json
from pathlib import Path
import struct
import zlib

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def validate(path):
    manifest = json.loads(path.read_text(encoding="utf-8"))
    folder = path.parent
    name = manifest["character_id"]
    data = (folder / (name + ".aseprite")).read_bytes()
    size, magic, count, width, height, depth = struct.unpack_from("<IHHHHH", data)
    assert (size, magic, width, height, depth) == (len(data), 0xA5E0, 32, 48, 32)
    assert count == manifest["frame_source"]["count"]
    sheet = Image.open(folder / (name + ".png")).convert("RGBA")
    exported = json.loads((folder / (name + ".json")).read_text(encoding="utf-8"))
    assert len(exported["frames"]) == count
    columns = manifest["export"]["columns"]
    assert sheet.size == (columns * width, ((count + columns - 1) // columns) * height)
    layers, tags, frames = [], [], []
    expected_durations = [0] * count
    expected_tags = []
    for tag in manifest["animations"]:
        expected_tags.append({key: tag[key] for key in ("name", "from", "to")})
        for index in range(tag["from"], tag["to"] + 1):
            expected_durations[index] = tag["duration_ms"]
    position = 128
    for index in range(count):
        length, frame_magic, chunks, duration = struct.unpack_from("<IHHH", data, position)
        assert frame_magic == 0xF1FA and duration == expected_durations[index]
        end, cursor, cels = position + length, position + 16, {}
        for _ in range(chunks):
            chunk_size, kind = struct.unpack_from("<IH", data, cursor)
            assert chunk_size >= 6 and cursor + chunk_size <= end
            payload = data[cursor + 6:cursor + chunk_size]
            if kind == 0x2004:
                assert index == 0
                flags, layer_type, child_level, _, _, blend = struct.unpack_from("<HHHHHH", payload)
                assert (flags, layer_type, child_level, blend, payload[12]) == (1, 0, 0, 0, 255)
                name_length = struct.unpack_from("<H", payload, 16)[0]
                assert len(payload) == 18 + name_length
                layers.append(payload[18:].decode())
            elif kind == 0x2018:
                assert index == 0
                tag_count = struct.unpack_from("<H", payload)[0]
                tag_cursor = 10
                for _ in range(tag_count):
                    start, finish, direction, repeat = struct.unpack_from("<HHBH", payload, tag_cursor)
                    assert direction == 0 and repeat == 0
                    name_length = struct.unpack_from("<H", payload, tag_cursor + 17)[0]
                    name = payload[tag_cursor + 19:tag_cursor + 19 + name_length].decode()
                    tags.append({"name": name, "from": start, "to": finish})
                    tag_cursor += 19 + name_length
                assert tag_cursor == len(payload)
            elif kind == 0x2005:
                layer, x, y, opacity, cel_type, z = struct.unpack_from("<HhhBHh", payload)
                assert (x, y, opacity, cel_type, z) == (0, 0, 255, 2, 0) and layer not in cels
                assert struct.unpack_from("<HH", payload, 16) == (32, 48)
                raw = zlib.decompress(payload[20:])
                assert len(raw) == 32 * 48 * 4
                image = Image.frombytes("RGBA", (32, 48), raw)
                source = Image.open(folder / f"frames/{index:03d}-{layers[layer]}.png").convert("RGBA")
                assert image.tobytes() == source.tobytes()
                cels[layer] = image
            else:
                raise AssertionError(hex(kind))
            cursor += chunk_size
        assert cursor == end and len(cels) == 6
        composed = Image.new("RGBA", (32, 48))
        for layer in range(6):
            composed.alpha_composite(cels[layer])
        assert set(composed.getchannel("A").get_flattened_data()) == {0, 255}
        assert any(composed.getpixel((x, 47))[3] for x in range(32))
        tile = sheet.crop(((index % columns) * 32, (index // columns) * 48, (index % columns + 1) * 32, (index // columns + 1) * 48))
        assert composed.tobytes() == tile.tobytes()
        assert exported["frames"][index]["duration"] == duration
        frames.append(composed.tobytes())
        position = end
    assert position == len(data) and layers == manifest["layers"] and tags == expected_tags
    assert [{key: tag[key] for key in ("name", "from", "to")} for tag in exported["meta"]["frameTags"]] == tags
    if count == 20:
        for row in range(4):
            assert len(set(frames[row * 5 + 1:row * 5 + 5])) == 4
        assert frames[10] != frames[15]
    elif manifest["family"] == "map-actions":
        for tag in manifest["animations"]:
            assert len(set(frames[tag["from"]:tag["to"] + 1])) == tag["to"] - tag["from"] + 1
    else:
        assert frames[0] != frames[1] and len(set(frames[2:6])) == 4
    return {"id": manifest["character_id"], "frames": count, "canvas": [32, 48], "layers": layers, "tags": tags, "status": "PASS", "source_sha256": hashlib.sha256(data).hexdigest()}


def main():
    paths = [ROOT / "WalalaWitch/character-manifest.json"] + sorted((ROOT / "WitchCustomers").glob("*/character-manifest.json"))
    if (ROOT / "WalalaTools/character-manifest.json").exists():
        paths.append(ROOT / "WalalaTools/character-manifest.json")
    reports = [validate(path) for path in paths]
    report = {"status": "PASS", "method": "Independent Aseprite chunk parsing, exact layer/master/sheet round trip, animation coverage and alpha checks", "characters": reports, "aseprite_application_verified": False}
    (ROOT / "source-validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("SOURCE VALIDATION PASS", len(reports), "characters", sum(item["frames"] for item in reports), "frames")


if __name__ == "__main__":
    main()
