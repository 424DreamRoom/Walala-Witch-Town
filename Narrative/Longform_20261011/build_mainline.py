"""Parse the fully authored mainline manuscript; no text expansion or templates."""
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent
METRICS = [
    ("gather", 3), ("serve", 3), ("harvest", 5), ("ore", 6),
    ("fish", 5), ("friend", 200), ("scrap", 8), ("restaurant", 2),
    ("ridge", 6), ("crop_types", 12), ("crystal", 8), ("banquet", 3),
]


def build():
    scenes = []
    scene = None
    for number, raw in enumerate((BASE / "mainline_source.txt").read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("@"):
            fields = line[1:].split("|")
            assert len(fields) == 5, (number, fields)
            sid, title, chapter, location, dependencies = map(str.strip, fields)
            scene = {
                "id": sid, "title": title, "kind": "main" if sid.startswith("main_") else "ensemble",
                "chapter_min": int(chapter), "season": "any", "location": location,
                "participants": [], "requires": [] if dependencies == "-" else dependencies.split(","),
                "sets": [sid], "lines": [],
            }
            if sid.startswith("main_") and sid.endswith("_after") and sid[5:7].isdigit():
                index = int(sid[5:7]) - 1
                metric, minimum = METRICS[index]
                scene["editor_gate"] = {"metric": metric, "minimum": minimum, "note": "仅编辑标注；沿用现有章节目标，不是新增运行逻辑"}
            scenes.append(scene)
            continue
        assert scene is not None and "：" in line, (number, line)
        speaker, body = line.split("：", 1)
        assert speaker and body.strip(), (number, line)
        scene["lines"].append({"speaker": speaker, "text": body})
        if speaker != "stage" and speaker not in scene["participants"]:
            scene["participants"].append(speaker)
    assert len(scenes) == 34, len(scenes)
    result = {"group": "main", "npcs": [], "scenes": scenes}
    (BASE / "mainline.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


if __name__ == "__main__":
    data = build()
    print("MAINLINE", len(data["scenes"]), "authored scenes")
