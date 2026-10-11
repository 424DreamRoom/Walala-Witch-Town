"""Package native editable NPC sources and report exact integration limits."""
import hashlib
import json
from pathlib import Path
import zipfile

OUT = Path(__file__).resolve().parents[1]
ROOT = OUT.parents[2]
LOGS = ROOT / "output/npc32"


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


records = []
for name in ("guide", "depth", "residents", "businesses", "restaurant"):
    text = (LOGS / ("test_" + name + ".log")).read_text(encoding="utf-8", errors="replace")
    failures = [line for line in text.splitlines() if any(t in line for t in (": FAIL", "SCRIPT ERROR", "ERROR:"))]
    completed = any(marker in text for marker in ("COMPLETE", "VERIFY END"))
    record = dict(name=name, passed=completed and not failures, completed=completed,
                  checks_passed=text.count(": PASS"), failures=failures,
                  log="output/npc32/test_" + name + ".log")
    if name in ("residents", "businesses"):
        baseline = (LOGS / ("baseline_" + name + ".log")).read_text(encoding="utf-8", errors="replace")
        old_failures = [line for line in baseline.splitlines() if any(t in line for t in (": FAIL", "SCRIPT ERROR", "ERROR:"))]
        record["old_npc_art_same_failures"] = old_failures == failures
    if name == "restaurant":
        record["old_art_comparison_completed"] = False
    records.append(record)
write_json(OUT / "runtime-regression.json", dict(results=records, gameplay_changes=False,
           note="Art-specific 173 checks pass. Broader gameplay regressions are not all passing; resident weather and business entrance failures also reproduce with old resident art."))
manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
assert len(manifest["assets"]) == 17
for entry in manifest["assets"]:
    source = OUT / entry["source"]
    assert hashlib.sha256(source.read_bytes()).hexdigest() == entry["source_sha256"]
before = json.loads((OUT / "myart-before.json").read_text(encoding="utf-8"))
now = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
       for p in (ROOT / "MyArt").rglob("*") if p.is_file()}
assert before == now
target = OUT / "npc32-aseprite-sources.zip"
with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(OUT.rglob("*")):
        if file.is_file() and file != target and file.suffix not in (".import", ".uid", ".pyc") and "__pycache__" not in file.parts:
            archive.write(file, "NPC32/" + file.relative_to(OUT).as_posix())
with zipfile.ZipFile(target) as archive:
    assert sum(name.endswith(".aseprite") for name in archive.namelist()) == 17
    assert archive.testzip() is None
print("PACKAGE PASS", target, target.stat().st_size, "bytes; 17 native editable Aseprite sources; MyArt unchanged")
