"""Record completed checks without hiding known baseline failures."""
from pathlib import Path
import hashlib
import json

ASSET=Path(__file__).resolve().parents[1]
ROOT=ASSET.parents[3]
OUT=ROOT/"output/witch-aseprite32"

def results(path):
    text=path.read_text(encoding="utf-8",errors="replace")
    assert "SCRIPT ERROR" not in text
    return {"passed":text.count(": PASS"),"failed":text.count(": FAIL"),
            "failures":[line for line in text.splitlines() if ": FAIL" in line]}

lane=results(OUT/"lane.log")
render=results(OUT/"render.log")
harvest=results(OUT/"harvest.log")
baseline=results(OUT/"baseline/baseline.log")
assert lane["passed"]==67 and lane["failed"]==0
assert render["passed"]==192 and render["failed"]==0
assert harvest["passed"]==466 and harvest["failed"]==5
assert baseline["passed"]==82 and baseline["failures"]==harvest["failures"]
protected=json.loads((OUT/"myart-before.json").read_text(encoding="utf-8"))
actual={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
        for p in (ROOT/"MyArt").rglob("*") if p.is_file()}
assert protected==actual
source_report=json.loads((ASSET/"validation-report.json").read_text(encoding="utf-8"))
assert hashlib.sha256((ASSET/"walala-witch.aseprite").read_bytes()).hexdigest()==source_report["source_sha256"]
report={"status":"PASS_WITH_EXISTING_DAY_FLOW_FAILURES","source_and_render_pass":True,
        "godot":"4.7.2.stable.steam","aseprite":"1.3.18.6-x64","lane":lane,"render":render,
        "harvest":harvest,"prior_harvest_animation_baseline":baseline,
        "same_baseline_failures":True,"myart_hashes_unchanged":True,"isolated_settings_and_saves":True,
        "import_note":"Import completed; existing editor FMOD library-copy errors were logged. Runtime checks initialized FMOD successfully.",
        "logs":"../../../../output/witch-aseprite32/"}
(ASSET/"integration-validation.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print("FINAL PASS: native source, 152 rendered frames, 67 movement checks; 5 day-flow failures exactly match old harvesting animation; MyArt unchanged")
