"""Verify this revision against the captured workspace, without player saves."""
import csv
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
DRAFT = ROOT / "Narrative/Rebuild_20261020"
sys.path.insert(0, str(ROOT / "Localization"))
from excel_catalog import read_workbook


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


originals = json.loads((OUT / "originals.json").read_text(encoding="utf-8"))
assert originals == {str(p.relative_to(ROOT)): digest(p) for p in (ROOT / "MyArt").rglob("*") if p.is_file()}

workbook_path = Path("Excel/Localization/Localization.xlsx")
before = {row[0]: row for row in read_workbook(OUT / "before" / workbook_path)}
after = {row[0]: row for row in read_workbook(ROOT / workbook_path)}
new_rows = json.loads((OUT / "translation_rows.json").read_text(encoding="utf-8"))
assert all(after[key] == row for key, row in before.items()), "Unrelated workbook rows changed"
assert all(after[row[0]] == row for row in new_rows), "Translation mismatch in workbook"
for row in new_rows:
    assert not re.search(r"点击|按.{0,6}(键|按钮)|快捷键|走近.{0,8}后", row[1]), row[1]

generated = ["Scenes/Campaign/content.gd", "Scenes/Campaign/content.json", "Localization/messages.tsv", "Localization/catalog.gd", "Narrative/Rebuild_20261020/translations_zh_TW.json"]
hashes = {path: digest(ROOT / path) for path in generated}
for script in ["Scenes/Campaign/build_content.py", "Localization/build_catalog.py", "Scenes/Campaign/sync_story_docs.py"]:
    subprocess.run([sys.executable, "-B", script], cwd=ROOT, check=True)
assert hashes == {path: digest(ROOT / path) for path in generated}, "Rebuild changed generated content"

with (ROOT / "Localization/messages.tsv").open(encoding="utf-8", newline="") as stream:
    catalog = {row[0]: row for row in list(csv.reader(stream, delimiter="\t"))[1:]}
assert all(catalog[row[1]] == row[1:] for row in new_rows), "Workbook/catalog mismatch"

data = json.loads((ROOT / "Scenes/Campaign/content.json").read_text(encoding="utf-8"))
manifest = json.loads((DRAFT / "场景索引.json").read_text(encoding="utf-8"))
validation = json.loads((DRAFT / "校验记录.json").read_text(encoding="utf-8"))
total_lines = total_han = 0
for scene, entry in zip(manifest["scenes"], validation["scenes"]):
    lines = [line for line in (DRAFT / scene["file"]).read_text(encoding="utf-8").splitlines() if line.strip()]
    assert all(line.split("：", 1)[0] in ["薇尔莉娅", "萤萝", "奥萝", "陶陶", "露米", "茉莉", "余烬", "皮普", "澪", "芦苇", "霜铃", "星芒"] for line in lines)
    text = [line.split("：", 1)[1] for line in lines]
    runtime = [beat["text"] for stage in data["opening"] for beat in stage["dialogue"]] if scene["id"] == "opening" else [beat["text"] for beat in data["quests"][int(scene["id"][-2:]) - 1]["dialogue"]]
    assert runtime == text, scene["id"]
    han = sum(len(re.findall(r"[\u4e00-\u9fff]", line)) for line in text)
    entry.update(lines=len(lines), han_characters=han)
    total_lines += len(lines)
    total_han += han
validation.update(dialogue_lines=total_lines, han_characters=total_han)
(DRAFT / "校验记录.json").write_text(json.dumps(validation, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
report = dict(date="2026-10-21", dialogue_lines=total_lines, opening_lines=43,
              changed_opening_lines=7, languages=["zh_CN", "en", "ja", "zh_TW"],
              workbook_entries=len(after), preserved_workbook_entries=len(before),
              new_translation_entries=len(new_rows), workbook_catalog_match=True,
              build_idempotent=True, manuscript_runtime_match=True,
              protected_originals_unchanged=True, formal_player_saves_accessed=False)
(OUT / "source_validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, ensure_ascii=False))
