"""Refresh only narrative sections of the design appendix; retain other local edits."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def sync_story_docs():
    data = json.loads((ROOT / "Scenes/Campaign/content.json").read_text(encoding="utf-8"))
    path = ROOT / "Scenes/Campaign/README.md"
    source = path.read_text(encoding="utf-8")
    premise = "薇尔莉娅在雾港后厨工作三年后，响应公开招租，试营月芽农场与月灯食堂一年。她从第一锅汤、当地作物和货船合单开始，在经营失误后学习兑现有限的承诺。月环是公共设施调配与报汛装置：旧临时接线长期依赖守环魔女椿手动值守，椿受伤后主动停机，仍在南方养伤并与镇上通信。居民先恢复水门和河口的独立支路，在冬末降雨中检验分工，最后协商续租与休息日。第十章之后继续自由经营，其他四条支路留作未来生活。"
    source = re.sub(r"(## 游戏定位与背景\n\n).*?(\n\n## 参考玩法)", lambda m: m[1] + premise + m[2], source, flags=re.S)
    opening = """## 开场动画分镜

新游戏播放五段共30秒的镜头：雾港后厨三年 → 公开招租告示 → 带着锅碗坐船出发 → 河边小镇 → 农场小屋。字幕直接交代攒钱、房租、住处和吃饭，不在开场先堆月环背景。画面里的月环保持早已停机的状态。告示固定钉在板上，不再出现匿名信飘落或主角到达时月环熄灭的演出。复用现有导出素材，整数缩放，不改原稿。

动画结束或略过后，顺序播放码头、农场、食堂三个场景中的43句对白：码头澪10句、农场门前萤萝15句、食堂奥萝与陶陶18句。人物使用现有原生精灵入场，萤萝保留从农场道路走近的动画。食堂场景开放免租试营，不另扣房地产服务的承租费用。主角默认名字和旧档自定义名字保留。

`campaign.opening_stage` 保存当前段；中断后从该段开头恢复。每段结束保存，全部完成后 `guide_met=true` 并恢复自由活动。动画略过不会略过开场对白。普通移动、背包与存档菜单在演出中锁定，对话仍接受原翻页、回看与选项输入。租金、订单退款和固定船期在本次接入中作为故事事件，不新增限日失败、自动扣租或独立货运模拟。

"""
    source = re.sub(r"## 开场动画分镜\n.*?(?=## 主线与解锁)", lambda _: opening, source, flags=re.S)
    main = ["## 主线与解锁", "", "正文使用 `Narrative/Rebuild_20261020/` 的11个原稿，合计436句（开场43句、主线393句）。`rebuilt_story.py` 编译原稿和翻译；`content.gd` 为导出运行资源，不需要运行时读取文本文件。", "", "章节按顺序完成，目标使用实际经营统计。第八章按项检查并消耗修缮材料，其余目标是累计记录；多余的某一种材料不能代替另一种。剧情对白逐句显示发言者和头像，已完成章节可在手记回顾。", "", "|章|标题|目标|数量|金币奖励|", "|---|---|---|---:|---:|"]
    for index, quest in enumerate(data["quests"], 1):
        main.append(f"|{index}|{quest['name']}|{quest['objective']}|{quest['goal']}|{quest['reward']}|")
    main += ["", "第八章材料：铁锭4、旧械零件6、月晶4。叙事中的季节表示剧情先后，不锁定日历日期，不要求玩家空等一年。", "", "完成交付时先记录 `pending_scene`、章节和奖励，再保存；对白读完清除挂起场景并保存。中断后重播本章对白，不再次发钱或扣料。普通经营仍沿用六小时自动存档；剧情分段额外设置保存点。", "", "旧存档保留金币、工具、物资、作物、好感、支线完成记录和已开放区域；旧主线章节存入 `legacy_chapter`，新主线从第一章开始，已在游玩的旧档跳过新开场。新版存档按新版章节恢复。星芒、奥萝和余烬支线中与匿名信、记忆供能相冲突的文本已经替换。", "", "开发与验证见 [GUIDE.md](GUIDE.md)。", "", ""]
    source = re.sub(r"## 主线与解锁\n.*?(?=## 地图与探索)", lambda _: "\n".join(main), source, flags=re.S)
    for region in data["regions"]:
        source = re.sub(r"\|" + re.escape(region["name"]) + r"\|\d+\|", f"|{region['name']}|{region['chapter']}|", source)
    for npc in data["npcs"]:
        if npc["id"] not in ("aster", "orla", "ember"):
            continue
        body = f"### {npc['name']}\n\n{npc['lines'][0]}\n\n"
        body += "\n\n".join(f"**{name}**：{event}" for name, event in zip(npc["stories"], npc["events"])) + "\n\n"
        source = re.sub(r"### " + re.escape(npc["name"]) + r"\n.*?(?=### |## )", lambda _: body, source, flags=re.S)
    source = source.replace("第一章采集3份食材奖励30金，没有必须先付钱才能赚钱的前置条件。", "开场开放试营；第一章累计上菜8次奖励70金。")
    source = source.replace("保留十二章顺序、区域解锁和奖励；第九章目标调整为山径调查，不再强制完成居民支线。", "新版主线十章，居民支线均为可选内容。")
    source = source.replace("旧档保留章节、好感和已完成故事，不补发奖励，也不批量接取任务。", "旧档保留好感、已完成故事和旧解锁，新主线从第一章开始。")
    source = re.sub(r"## 开场萤萝行走验证\n.*?(?=## 食材与菜谱扩充)", "## 新版剧情验证\n\n`python -B Scenes/Campaign/run_rebuilt_story_verification.py` 运行新版剧情回归；追加 `capture` 生成实际画面。旧开场和十二章剧情测试记录描述历史版本，新版流程以本验证入口为准。测试使用 `output/story_rebuild_integration/` 下隔离设置与存档，并核对原稿哈希。\n\n", source, flags=re.S)
    path.write_text(source, encoding="utf-8")


if __name__ == "__main__":
    sync_story_docs()
