"""Check rendered sprite pixels and integer window scaling in Godot screenshots."""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[2]
ENV = PROJECT / "Art/Environment/Hearthwood/Verification"
CUSTOMERS = PROJECT / "Scenes/Gameplay/Verification"


def sprite_match(screenshot, sheet_path, index, columns, origin):
    sheet = Image.open(sheet_path).convert("RGBA")
    x, y = index % columns * 32, index // columns * 48
    sprite = sheet.crop((x, y, x + 32, y + 48))
    rendered = Image.open(screenshot).convert("RGB").crop((*origin, origin[0] + 32, origin[1] + 48))
    count = 0
    for a, b in zip(sprite.get_flattened_data(), rendered.get_flattened_data()):
        if a[3]:
            assert a[:3] == b, (screenshot.name, index, a, b)
            count += 1
    assert count > 200
    return {"screenshot": screenshot.name, "frame": index, "matched_opaque_pixels": count}


def main():
    checks = [sprite_match(ENV / "home_size_720.png", ROOT / "WalalaWitch/walala-witch.png", 5, 5, (214, 142))]
    variants = ["green_braids", "blue_blonde", "burgundy_curls", "orange_short", "cyan_gray", "pink_longblue"]
    for i, name in enumerate(variants):
        sheet = ROOT / f"WitchCustomers/{name}/{name}.png"
        capture = "customers_idle_012.png" if i < 3 else "customers_idle_345.png"
        origin = ([94, 229, 359][i % 3], 177)
        checks.append(sprite_match(CUSTOMERS / capture, sheet, 0, 6, origin))
    orange = ROOT / "WitchCustomers/orange_short/orange_short.png"
    checks.append(sprite_match(CUSTOMERS / "customer_eating_start.png", orange, 2, 6, (94, 177)))
    checks.append(sprite_match(CUSTOMERS / "customer_eating_mid.png", orange, 3, 6, (94, 177)))
    names = ["town_spawn", "home_exterior", "home_south", "home_north", "restaurant", "restaurant_kitchen", "restaurant_serving", "restaurant_menu", "field", "field_gather", "home_size_720", "home_1920", "town_1920"]
    window_checks = []
    for name in names:
        native = Image.open(ENV / (name + ".png")).convert("RGB")
        window = Image.open(ENV / (name + "_window.png")).convert("RGB")
        factor = min(window.width // native.width, window.height // native.height)
        expected = native.resize((native.width * factor, native.height * factor), Image.Resampling.NEAREST)
        x, y = (window.width - expected.width) // 2, (window.height - expected.height) // 2
        assert window.crop((x, y, x + expected.width, y + expected.height)).tobytes() == expected.tobytes(), name
        window_checks.append({"screenshot": name, "window": list(window.size), "integer_scale": factor})
    report = {"status": "PASS", "sprite_checks": checks, "window_checks": window_checks}
    (ROOT / "render-validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("RENDER VALIDATION PASS", len(checks), "exact sprite pixel matches;", len(window_checks), "nearest-neighbor window matches")


if __name__ == "__main__":
    main()
