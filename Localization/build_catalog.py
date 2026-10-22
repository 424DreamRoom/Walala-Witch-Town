"""Export Excel tables to runtime CSV and validated compatibility snapshots."""
import argparse
import json
import re
import sys
from pathlib import Path
from zipfile import BadZipFile

from excel_catalog import delimited_text, read_catalogs, write_if_changed

BASE = Path(__file__).resolve().parent
SOURCE = BASE.parent / "Excel/Localization"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--check", action="store_true", help="Validate generated outputs without writing")
parser.add_argument("--watch", action="store_true", help="Export after every saved Excel change")
options = parser.parse_args()
if options.watch:
    if options.check:
        parser.error("--check and --watch cannot be combined")
    from watch_catalog import watch
    sys.exit(watch())
try:
    tables = read_catalogs(SOURCE)
except (ValueError, OSError, BadZipFile) as error:
    sys.exit(f"LOCALIZATION CSV FAILED: {error}")
rows = [row for table in tables.values() for row in table]
records = [row[1:] for row in rows]
keys = set()
aliases = {}
for row in rows:
    key, chinese = row[:2]
    assert key not in keys, f"Duplicate LanguageKey: {key}"
    keys.add(key)
    for alias in {key, chinese}:
        assert alias not in aliases or aliases[alias] == key, f"Conflicting LanguageKey / Chinese alias: {alias}"
        aliases[alias] = key
    if re.search(r"[\u4e00-\u9fff%]", key):
        pattern = r"%(?:\d+\$)?[-+0 #]*\d*(?:\.\d+)?[sdf]"
        assert re.findall(pattern, key) == re.findall(pattern, chinese), f"Placeholders differ from LanguageKey: {row}"
seen = set()
operation_hint = re.compile(r'\b(?:WASD|Enter|Esc|Shift)\b|\b[WASDEBJHLM]\s*/|点击|雙擊|双击|點擊|左键|右键|左鍵|右鍵')
source_key_hint = re.compile(r'\b[WASDEBJHLM](?=\s|/|·|：|:|$)')
rich_tag = re.compile(r'\[(/?)(b|i|u|s|code|color|bgcolor|font_size|outline_size|outline_color|jump|sway|lb|rb)(?:[= ][^\]\n]+)?\]')

def rich_tags(text):
    """Keep nested formatting balanced and preserve styles in each translation."""
    stack, tags = [], []
    for match in rich_tag.finditer(text):
        closing, name = match.group(1, 2)
        if closing:
            assert stack and stack.pop() == name, f"Unbalanced BBCode: {text}"
        else:
            tags.append(match.group(0))
            if name not in ("lb", "rb"):
                stack.append(name)
    assert not stack, f"Unclosed BBCode: {text}"
    return sorted(tags)

for row in records:
    assert len(row) == 4 and all(row), f"Incomplete translation: {row}"
    assert row[0] not in seen, f"Duplicate source: {row[0]}"
    seen.add(row[0])
    # A key name is a value in the binding editor; other UI copy must not teach input.
    if row[0] != "空格":
        assert not source_key_hint.search(row[0]) and not any(operation_hint.search(text) for text in row), f"Operation hint in UI catalog: {row}"
    placeholders = re.findall(r"%(?:\d+\$)?[-+0 #]*\d*(?:\.\d+)?[sdf]", row[0])
    tags = rich_tags(row[0])
    for translated in row[1:]:
        assert re.findall(r"%(?:\d+\$)?[-+0 #]*\d*(?:\.\d+)?[sdf]", translated) == placeholders, row
        assert rich_tags(translated) == tags, f"BBCode differs between translations: {row}"
# Existing Chinese keys remain valid after editing their displayed wording.
seen.update(keys)
# Catch newly added Chinese UI strings before they silently fall back in English.
root = BASE.parent
missing = []
# The credits UI is authored in localized_text.gd; CREDITS.txt is source/license
# documentation and is not loaded into the player-facing attribution list.
paths = list((root / "Scenes").rglob("*.gd")) + [BASE / "localized_text.gd", root / "Sounds/Walala/audio_manager.gd"]
for path in paths:
    if path.stem.startswith(("verify", "verification")):
        continue
    for match in re.finditer(r'"((?:[^"\\]|\\.)*)"', path.read_text(encoding="utf-8")):
        text = json.loads('"' + match.group(1) + '"')
        if re.search(r"[\u4e00-\u9fff]", text):
            assert not operation_hint.search(text) and not source_key_hint.search(text), f"Operation hint in {path.relative_to(root)}: {text}"
        if re.search(r"[\u4e00-\u9fff]", text) and text not in seen:
            missing.append((str(path.relative_to(root)), text))
assert not missing, f"Missing translations: {missing}"
outputs = {}
for path, table in tables.items():
    outputs[path] = "\ufeff" + delimited_text(table)
    # The game reads the raw CSV, not Godot's locale-column translation importer.
    outputs[path.with_suffix(".csv.import")] = '[remap]\n\nimporter="keep"\n'
outputs[BASE / "messages.tsv"] = delimited_text(records, ("source", "en", "ja", "zh_TW"), "\t")
outputs[BASE / "catalog.gd"] = (
    'extends RefCounted\n## Compatibility snapshot from Excel/Localization; runtime reads CSV.\nconst ROWS := '
    + json.dumps(records, ensure_ascii=False, indent=2) + '\n')
orphaned = sorted(set(SOURCE.rglob("*.csv")) - set(tables))
assert not orphaned, f"CSV without matching XLSX; remove or restore the table explicitly: {orphaned}"
stale = [path for path, text in outputs.items() if not path.is_file() or path.read_bytes() != text.encode("utf-8")]
if options.check:
    assert not stale, f"Stale generated localization files: {stale}"
else:
    for path in stale:
        write_if_changed(path, outputs[path])
print(f"LOCALIZATION CSV {len(records)} entries, {len(tables)} tables, {len(stale)} updated; placeholders, BBCode and source coverage verified")
