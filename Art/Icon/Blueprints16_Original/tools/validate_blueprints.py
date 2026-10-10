"""Check Aseprite structure, editable layers, transparency and exact PNG round trip."""
from pathlib import Path
import hashlib
import importlib.util
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[2]
spec = importlib.util.spec_from_file_location(
    "icon_validator", PROJECT / "Art/Icon/Resources16_Original/tools/validate_resources.py"
)
parser = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parser)
parser.ROOT = ROOT
NAMES = ["furniture_blueprint", "recipe_blueprint"]


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["count"] == len(manifest["assets"]) == 2
    assert manifest["size"] == [16, 16] and manifest["layers"] == parser.EXPECTED_LAYERS
    assert [asset["slug"] for asset in manifest["assets"]] == NAMES
    assert {path.stem for path in ROOT.glob("*.aseprite")} == set(NAMES)
    assert {path.stem for path in ROOT.glob("*.png")} == set(NAMES) | {"preview_nearest_16x"}
    results, hashes = [], []
    for asset in manifest["assets"]:
        name = asset["slug"]
        assert asset["png"] == name + ".png" and asset["aseprite"] == name + ".aseprite"
        assert asset["godot_texture"] == "res://Art/Icon/Blueprints16_Original/" + name + ".png"
        result = parser.validate(name, expected_layer_flags=3)
        result["layers_visible_and_editable"] = True
        with Image.open(ROOT / asset["png"]) as sprite:
            pixels = [sprite.getpixel((x, y)) for y in range(16) for x in range(16)]
            assert all(pixel == (0, 0, 0, 0) for pixel in pixels if pixel[3] == 0)
            digest = hashlib.sha256(sprite.tobytes()).hexdigest()
            hashes.append(digest)
            result["png_pixel_sha256"] = digest
        result.update(name_zh=asset["name_zh"], name_en=asset["name_en"])
        results.append(result)
    assert len(set(hashes)) == 2
    with Image.open(ROOT / "preview_nearest_16x.png") as preview:
        assert preview.size == (576, 384)
    report = {
        "passed": True, "asset_count": 2,
        "method": "Independent Aseprite binary parsing, four nonempty editable layers, exact RGBA recomposition",
        "aseprite_application_tested": False,
        "limitation": "No Aseprite CLI available on PATH; application-open verification not performed",
        "assets": results,
    }
    (ROOT / "validation_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("PASS: 2 distinct native 16x16 RGBA icons; transparent padding; 4 nonempty Aseprite layers each; source/PNG exact match.")


if __name__ == "__main__":
    main()
