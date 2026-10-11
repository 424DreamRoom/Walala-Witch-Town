"""Validate and package authored dialogue. Writes only inside this directory."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re
import unicodedata
import zipfile

from build_mainline import build as build_mainline

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[1]
INPUTS = ["mainline.json", "core_residents.json", "town_residents.json", "valley_residents.json"]
HAN = re.compile(r"[\u4e00-\u9fff]")
CONTROL = re.compile(r"点击|點擊|双击|雙擊|左键|右键|左鍵|右鍵|按下.{0,8}(?:键|鍵)|按.{0,6}(?:键|鍵)|走近.{0,20}后.{0,20}(?:按|交互)|\b(?:WASD|Enter|Esc|Shift)\b", re.I)
CANON = {"mori": "茉莉", "ember": "余烬", "nagi": "澪", "lumi": "露米", "aster": "星芒", "toma": "陶陶", "pip": "皮普", "reed": "芦苇", "yuki": "霜铃", "orla": "奥萝", "yingluo": "萤萝"}
REQUIRED_FIELDS = {"id", "title", "kind", "chapter_min", "season", "location", "participants", "requires", "sets", "lines"}


def han(text):
    return len(HAN.findall(text))


def key(text):
    return re.sub(r"\s+", "", unicodedata.normalize("NFKC", text))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(allow_incomplete=False):
    build_mainline()
    errors, warnings, groups, npcs, scenes = [], [], [], [], []
    for filename in INPUTS:
        path = BASE / filename
        if not path.exists():
            errors.append(f"Missing source: {filename}")
            continue
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        groups.append(data)
        npcs.extend(data["npcs"])
        for scene in data["scenes"]:
            scene = dict(scene)
            scene["source_file"] = filename
            scenes.append(scene)
    npc_ids = [npc["id"] for npc in npcs]
    names = [npc["name"] for npc in npcs]
    scene_ids = [scene["id"] for scene in scenes]
    for label, values in [("NPC id", npc_ids), ("NPC name", names), ("scene id", scene_ids)]:
        for value, count in Counter(values).items():
            if count > 1:
                errors.append(f"Duplicate {label}: {value}")
    by_npc = {npc["id"]: npc for npc in npcs}
    by_scene = {scene["id"]: scene for scene in scenes}
    actors = set(npc_ids) | {"player", "stage"}
    for nid, name in CANON.items():
        if nid not in by_npc or by_npc[nid]["name"] != name:
            errors.append(f"Missing or renamed existing NPC: {nid} {name}")
    for npc in npcs:
        for relation in npc.get("relationships", []):
            if relation["npc_id"] not in by_npc:
                errors.append(f"Unknown relationship: {npc['id']} -> {relation['npc_id']}")
    entries, per_npc, per_group = [], defaultdict(Counter), defaultdict(Counter)
    line_occurrences = defaultdict(list)
    for scene in scenes:
        sid = scene["id"]
        missing = REQUIRED_FIELDS - scene.keys()
        if missing:
            errors.append(f"Missing fields in {sid}: {sorted(missing)}")
            continue
        chapter = scene["chapter_min"]
        if not isinstance(chapter, int) or not 0 <= chapter <= 12:
            errors.append(f"Invalid chapter_min: {sid} {chapter}")
        if scene["season"] not in {"any", "spring", "summer", "autumn", "winter"}:
            errors.append(f"Invalid season: {sid} {scene['season']}")
        for pid in scene["participants"]:
            if pid not in actors - {"stage"}:
                errors.append(f"Unknown participant: {sid} {pid}")
        for dep in scene["requires"]:
            if dep not in by_scene:
                errors.append(f"Unknown prerequisite: {sid} -> {dep}")
            elif by_scene[dep]["chapter_min"] > chapter:
                errors.append(f"Prerequisite in later chapter: {sid} -> {dep}")
        if sid not in scene["sets"]:
            errors.append(f"Scene does not set its own completion: {sid}")
        speakers = set()
        if not scene["lines"]:
            errors.append(f"Empty scene: {sid}")
        for index, line in enumerate(scene["lines"], 1):
            speaker, text = line["speaker"], line["text"]
            if speaker not in actors:
                errors.append(f"Unknown speaker: {sid}:{index} {speaker}")
            if not isinstance(text, str) or not text.strip():
                errors.append(f"Empty body: {sid}:{index}")
                continue
            if speaker != "stage":
                speakers.add(speaker)
            scan_text = text.replace("琴键", "琴音").replace("琴鍵", "琴音") if speaker == "stage" else text
            if CONTROL.search(scan_text):
                errors.append(f"Operation-copy candidate: {sid}:{index} {text}")
            entry = {"scene": sid, "line": index, "speaker": speaker, "text": text, "han": han(text), "group": scene["source_file"]}
            entries.append(entry)
            line_occurrences[key(text)].append(entry)
            group_count = per_group[scene["source_file"]]
            group_count["body_han"] += entry["han"]
            group_count["spoken_han" if speaker != "stage" else "stage_han"] += entry["han"]
            if speaker in by_npc:
                per_npc[speaker]["spoken_han"] += entry["han"]
                per_npc[speaker]["spoken_lines"] += 1
        if not speakers <= set(scene["participants"]):
            errors.append(f"Speaker missing from participants: {sid} {sorted(speakers - set(scene['participants']))}")
        for speaker in speakers & set(npc_ids):
            per_npc[speaker]["scenes"] += 1
            if scene["kind"] == "personal":
                per_npc[speaker]["personal_scenes"] += 1
    visiting, visited = set(), set()

    def visit(sid):
        if sid in visiting:
            errors.append(f"Cyclic prerequisites involving {sid}")
            return
        if sid in visited:
            return
        visiting.add(sid)
        for dep in by_scene[sid]["requires"]:
            if dep in by_scene:
                visit(dep)
        visiting.remove(sid)
        visited.add(sid)

    for sid in by_scene:
        visit(sid)
    for nid in npc_ids:
        owned = [scene for scene in scenes if scene["id"].startswith(scene["source_file"].split("_residents")[0] + "_" + nid + "_")]
        per_npc[nid]["own_arc_scenes"] = len(owned)
        if len(owned) < 4:
            errors.append(f"NPC has fewer than 4 dedicated arc scenes: {nid}")
        if per_npc[nid]["spoken_lines"] < 10:
            errors.append(f"NPC has insufficient actual dialogue: {nid}")
        if per_npc[nid]["personal_scenes"] < 4:
            warnings.append(f"NPC has fewer than 4 personal scene appearances: {nid}")
    unique_entries = [items[0] for items in line_occurrences.values()]
    body_han = sum(entry["han"] for entry in entries)
    unique_han = sum(entry["han"] for entry in unique_entries)
    spoken_han = sum(entry["han"] for entry in entries if entry["speaker"] != "stage")
    unique_spoken = {}
    for entry in entries:
        if entry["speaker"] != "stage":
            unique_spoken.setdefault(key(entry["text"]), entry)
    unique_spoken_han = sum(entry["han"] for entry in unique_spoken.values())
    repeats = [{"text": items[0]["text"], "occurrences": [f"{entry['scene']}:{entry['line']}" for entry in items]} for items in line_occurrences.values() if len(items) > 1 and items[0]["han"] >= 20]
    if repeats:
        warnings.append(f"Repeated lines >=20 Han characters: {len(repeats)}; excluded from unique count")
    long_lines = [entry for entry in entries if entry["speaker"] != "stage" and entry["han"] > 160]
    if long_lines:
        warnings.append(f"Spoken lines over 160 Han characters require read-aloud review: {len(long_lines)}")
    if len(npcs) < 51:
        errors.append(f"Need at least 51 NPCs, have {len(npcs)}")
    if unique_han < 100000:
        errors.append(f"Need 100000 unique body Han characters, have {unique_han}")
    if unique_spoken_han < 100000:
        errors.append(f"Need 100000 unique spoken Han characters, have {unique_spoken_han}")
    protection = {"checked": False}
    baseline_path = BASE / "baseline_protection.json"
    if baseline_path.exists():
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
        current_art = {str(path.relative_to(ROOT)): digest(path) for path in (ROOT / "MyArt").rglob("*") if path.is_file()}
        changed_runtime = [name for name, value in baseline["existing_runtime"].items() if not (ROOT / name).is_file() or digest(ROOT / name) != value]
        art_ok = current_art == baseline["myart"]
        protection = {"checked": True, "myart_files": len(current_art), "myart_unchanged": art_ok, "existing_runtime_unchanged": not changed_runtime, "changed_runtime": changed_runtime}
        if not art_ok:
            errors.append("MyArt baseline differs; inspect before delivery")
        if changed_runtime:
            warnings.append("Existing runtime files changed concurrently after baseline. This packaging workflow writes only inside its own content directory; preserve and inspect those changes without reverting them.")
    names_by_id = {**{npc["id"]: npc["name"] for npc in npcs}, "player": "薇尔莉娅", "stage": "场景"}
    manuscript = ["哗啦啦魔女镇：四季与月灯食堂", "十万字原创剧情对白内容稿 · 2026-10-11", "", "独立中文内容稿，尚未接入游戏；数字、地点与事件前置以编辑元数据为准。", "统计不含人物册、标题、说话人和标点；详见validation_report.json。", ""]
    index_text = ["人物与事件索引", "", "章节编号为零基：0为第一章，12为宴会完成后。requires均指本包场景ID。新增店铺为叙事设计。", ""]
    for npc in npcs:
        index_text.extend([f"【{npc['name']}】 {npc['id']} · {npc.get('role', '')}", f"语气：{npc.get('voice', '')}", f"想要：{npc.get('desire', '')}", f"盲点：{npc.get('blind_spot', '')}", f"实际出场：{per_npc[npc['id']]['scenes']}场 / 独立支线与日常{per_npc[npc['id']]['own_arc_scenes']}场 / 本人对白{per_npc[npc['id']]['spoken_han']}汉字"])
        for relation in npc.get("relationships", []):
            index_text.append(f"关系：{names_by_id.get(relation['npc_id'], relation['npc_id'])} · {relation['note']}")
        for scene in scenes:
            if npc["id"] in scene["participants"]:
                index_text.append(f"  {scene['id']}｜{scene['title']}｜章≥{scene['chapter_min']}｜{scene['season']}｜{scene['location']}｜前置：{', '.join(scene['requires']) or '无'}")
        index_text.append("")
    section_names = {"mainline.json": "十二章主线、宴后与跨组群戏", "core_residents.json": "原有居民与核心街坊", "town_residents.json": "街巷居民", "valley_residents.json": "山谷与往来者"}
    last_section = None
    for scene in scenes:
        section = scene["source_file"]
        if section != last_section:
            manuscript.extend(["", "════════════════════════════", section_names[section], "════════════════════════════", ""])
            last_section = section
        manuscript.extend([f"【{scene['title']}】", f"事件：{scene['id']} · 地点：{scene['location']}", f"前置：{', '.join(scene['requires']) or '无'} · 章节≥{scene['chapter_min']} · 季节：{scene['season']}", ""])
        for line in scene["lines"]:
            if line["speaker"] == "stage":
                manuscript.append(f"（{line['text']}）")
            else:
                manuscript.append(f"{names_by_id.get(line['speaker'], line['speaker'])}：{line['text']}")
        manuscript.append("")
    report = {
        "status": "pass" if not errors else "incomplete" if allow_incomplete else "fail",
        "counting_rule": "Only U+4E00–U+9FFF in scene lines[].text; exclude metadata, titles, speaker fields, punctuation and exact repeated line bodies from unique counts.",
        "npc_count": len(npcs), "scene_count": len(scenes), "line_count": len(entries),
        "spoken_line_count": sum(entry["speaker"] != "stage" for entry in entries),
        "body_han": body_han, "unique_body_han": unique_han,
        "spoken_han": spoken_han, "unique_spoken_han": unique_spoken_han,
        "stage_han": body_han - spoken_han,
        "body_unicode_characters": sum(len(re.sub(r"\s", "", entry["text"])) for entry in entries),
        "per_group": dict(per_group), "per_npc": dict(per_npc),
        "repeated_long_lines": repeats, "long_spoken_lines": [{k: entry[k] for k in ("scene", "line", "speaker", "han")} for entry in long_lines],
        "source_sha256": {filename: digest(BASE / filename) for filename in INPUTS if (BASE / filename).exists()},
        "protection": protection, "errors": errors, "warnings": warnings,
        "integration_status": "Independent authored Chinese content package; no runtime/UI/save/localization integration performed.",
        "review_scope": "Automated schema, IDs, speakers, references, acyclic prerequisites, chapter ordering, control-copy screening, counts and protection hashes. Literary quality and nuanced continuity need editorial judgment; manual sample review recorded separately.",
    }
    bundle = {"schema_version": 1, "title": "哗啦啦魔女镇：四季与月灯食堂", "integration_status": report["integration_status"], "counting_rule": report["counting_rule"], "npcs": npcs, "scenes": scenes}
    for filename, data in [("dialogue_bundle.json", bundle), ("validation_report.json", report)]:
        (BASE / filename).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (BASE / "剧情对白全集.txt").write_text("\n".join(manuscript), encoding="utf-8")
    (BASE / "人物与事件索引.txt").write_text("\n".join(index_text), encoding="utf-8")
    if not errors:
        packed = sorted(path for path in BASE.iterdir() if path.is_file() and path.suffix in {".txt", ".json", ".py"})
        with zipfile.ZipFile(BASE / "剧情内容包.zip", "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for path in packed:
                archive.write(path, arcname=path.name)
    print(json.dumps({k: report[k] for k in ("status", "npc_count", "scene_count", "line_count", "unique_body_han", "unique_spoken_han", "errors", "warnings", "protection")}, ensure_ascii=False, indent=2))
    if errors and not allow_incomplete:
        raise SystemExit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--allow-incomplete", action="store_true", help="Draft-stage report; never treat an incomplete report as final success")
    args = parser.parse_args()
    run(args.allow_incomplete)
