"""Build from editable layers, then run the skill's independent strict validator."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(args):
    subprocess.run([sys.executable, *map(str, args)], check=True, timeout=120)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skill-dir", type=Path, default=Path.home() / ".codex/skills/generate-consistent-pixel-animations")
    parser.add_argument("--export-only", action="store_true")
    parser.add_argument("--hero-only", action="store_true")
    args = parser.parse_args()
    if not args.export_only:
        run([ROOT / "tools/build_characters.py", *(["--hero-only"] if args.hero_only else [])])
    manifests = [ROOT / "WalalaWitch/character-manifest.json"] + ([] if args.hero_only else sorted((ROOT / "WitchCustomers").glob("*/character-manifest.json")))
    for path in manifests:
        data = json.loads(path.read_text(encoding="utf-8"))
        run([args.skill_dir / "scripts/build_sprite_sheet.py", path, "--output-dir", path.parent])
        run([args.skill_dir / "scripts/validate_animation.py", path.parent / (data["character_id"] + ".png"), "--family", data["family"], "--manifest", path, "--report", path.parent / "validation-report.json", "--strict"])
    run([ROOT / "tools/validate_sources.py"])
    run([ROOT / "tools/build_previews.py"])


if __name__ == "__main__":
    main()
