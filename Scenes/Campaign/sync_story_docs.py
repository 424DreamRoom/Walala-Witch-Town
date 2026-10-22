"""Refresh only narrative sections of the design appendix; retain other local edits."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def sync_story_docs():
    data = json.loads((ROOT / "Scenes/Campaign/content.json").read_text(encoding="utf-8"))
    opening_lines = sum(len(scene["dialogue"]) for scene in data["opening"])
    main_lines = sum(len(quest["dialogue"]) for quest in data["quests"])
    path = ROOT / "Scenes/Campaign/README.md"
    source = path.read_text(encoding="utf-8")
    premise = "艾洛温在雾港后厨工作三年后，响应公开招租，试营月芽农场与月灯食堂一年。她从第一锅汤、当地作物和货船合单开始，在经营失误后学习兑现有限的承诺。月环是公共设施调配与报汛装置：旧临时接线长期依赖守环魔女柯蒂莉娅手动值守，柯蒂莉娅受伤后主动停机，仍在南方养伤并与镇上通信。居民先恢复水门和河口的独立支路，在冬末降雨中检验分工，最后协商续租与休息日。第十章之后继续自由经营，其他四条支路留作未来生活。"
    source = re.sub(r"(## 游戏定位与背景\n\n).*?(\n\n## 参考玩法)", lambda m: m[1] + premise + m[2], source, flags=re.S)
    opening = """## 开场动画分镜

新游戏播放八段共86秒的镜头：雾港后厨三年 → 盘点积蓄与开店成本 → 公开招租告示 → 写信问询与明确回信 → 装箱辞职 → 货船驶入支流 → 河边小镇 → 抵港卸行李。先说明艾洛温想独立经营、雾港租金太高、镇里为何免租和双方怎样联系，再呈现实际船行与抵港。画面包含蒸汽、清点金币、通信、装箱、航行与下船，复用原导出素材，整数缩放，不改原稿。月环保持早已停机的状态，不在开场制造匿名信或到镇即停机的误会。分镜结束于码头，不再先到小屋又跳回初次抵港。`开场分镜.json` 保存各镜头文案、翻译和时长；字幕与画面按同一时间轴淡入淡出。

动画结束或略过后，顺序播放码头、农场、食堂三个场景中的60句对白：码头玛伦14句、农场门前露辛达21句、食堂莫文与托宾25句。交代招租的实际需要、主角三年后厨经历、前店主回乡照顾家人、旧账已经结清、租约责任和生活费安排。码头告别后主角先离开，再转到农场与露辛达碰面；农场对白后两人沿路出发，下一镜先交代食堂门外，再从室内入口走到莫文和托宾面前。分镜结束和各次换场使用0.25秒淡出、0.25秒淡入，在全黑时定位角色。人物复用现有原生方向动画，演出暂停游戏计时。食堂场景完成免租租约，不另扣房地产服务的承租费用。主角默认名字和旧档自定义名字保留。`场景索引.json` 的 `opening_segments` 明确各段范围，构建时检查连续覆盖，扩写不会把对白切到错误地点。

开场收尾明确今天安顿行李、认识住处与小镇，明天再准备开店。第一天隐藏菜单和营业入口，露辛达与手记显示安顿和回家休息；傍晚继续自由活动，不自动转入食堂。回家休息时淡出，直接到第二天早晨并保存，不生成营业结算。`campaign.settling_in` 随存档保留到休息结束；缺少该字段的旧档保持原营业进度。第二天才开放第一章的备料、菜单与营业流程。

`campaign.opening_stage` 保存当前段；对白读完后先保存下一段，再演出离场与入场。中断后从下一段开头恢复，全部完成后 `guide_met=true` 并恢复自由活动。动画略过不会略过开场对白。普通移动、背包与存档菜单在演出中锁定，对话仍接受原翻页、回看与选项输入。读档时等待已有界面转场完成，防止开场重入。租金、订单退款和固定船期在本次接入中作为故事事件，不新增限日失败、自动扣租或独立货运模拟。

"""
    source = re.sub(r"## 开场动画分镜\n.*?(?=## 主线与解锁)", lambda _: opening, source, flags=re.S)
    main = ["## 主线与解锁", "", f"正文使用 `Narrative/Rebuild_20261020/` 的11个原稿，合计{opening_lines + main_lines}句（开场{opening_lines}句、主线{main_lines}句）。`rebuilt_story.py` 编译原稿和翻译；`content.gd` 为导出运行资源，不需要运行时读取文本文件。2026年10月22日扩写明确了航运成本、灌溉与排洪的关系、临时接线为何失控、莫文的签字责任、主角接下超量订单的焦虑、退款后的实际损失、安全停机与修复验收的区别、雨夜分工与续租原因。", "", "章节按顺序完成，目标使用实际经营统计。第八章按项检查并消耗修缮材料，其余目标是累计记录；多余的某一种材料不能代替另一种。剧情对白逐句显示发言者和头像，已完成章节可在手记回顾。", "", "|章|标题|目标|数量|金币奖励|", "|---|---|---|---:|---:|"]
    for index, quest in enumerate(data["quests"], 1):
        main.append(f"|{index}|{quest['name']}|{quest['objective']}|{quest['goal']}|{quest['reward']}|")
    main += ["", "第八章材料：铁锭4、旧械零件6、月晶4。叙事中的季节表示剧情先后，不锁定日历日期，不要求玩家空等一年。", "", "完成交付时先记录 `pending_scene`、章节和奖励，再保存；对白读完清除挂起场景并保存。中断后重播本章对白，不再次发钱或扣料。普通经营仍沿用六小时自动存档；剧情分段额外设置保存点。", "", "旧存档保留金币、工具、物资、作物、好感、支线完成记录和已开放区域；旧主线章节存入 `legacy_chapter`，新主线从第一章开始，已在游玩的旧档跳过新开场。新版存档按新版章节恢复。塞勒涅、莫文和布兰支线中与匿名信、记忆供能相冲突的文本已经替换。", "", "开发与验证见 [GUIDE.md](GUIDE.md)。", "", ""]
    source = re.sub(r"## 主线与解锁\n.*?(?=## 地图与探索)", lambda _: "\n".join(main), source, flags=re.S)
    for region in data["regions"]:
        source = re.sub(r"\|" + re.escape(region["name"]) + r"\|\d+\|", f"|{region['name']}|{region['chapter']}|", source)
    for npc in data["npcs"]:
        if npc["id"] not in ("aster", "orla", "ember"):
            continue
        body = f"### {npc['name']}\n\n{npc['lines'][0]}\n\n"
        body += "\n\n".join(f"**{name}**：{event}" for name, event in zip(npc["stories"], npc["events"])) + "\n\n"
        source = re.sub(r"### " + re.escape(npc["name"]) + r"\n.*?(?=### |## )", lambda _: body, source, flags=re.S)
    source = source.replace("第一章采集3份食材奖励30金，没有必须先付钱才能赚钱的前置条件。", "第一天熟悉小镇，第二天起准备营业；第一章累计上菜8次奖励70金。")
    source = source.replace("开场开放试营；第一章累计上菜8次奖励70金。", "第一天熟悉小镇，第二天起准备营业；第一章累计上菜8次奖励70金。")
    source = source.replace("保留十二章顺序、区域解锁和奖励；第九章目标调整为山径调查，不再强制完成居民支线。", "新版主线十章，居民支线均为可选内容。")
    source = source.replace("旧档保留章节、好感和已完成故事，不补发奖励，也不批量接取任务。", "旧档保留好感、已完成故事和旧解锁，新主线从第一章开始。")
    source = re.sub(r"## 开场露辛达行走验证\n.*?(?=## 食材与菜谱扩充)", "## 新版剧情验证\n\n`python -B Scenes/Campaign/run_rebuilt_story_verification.py` 运行新版剧情回归；追加 `capture` 生成实际画面。旧开场和十二章剧情测试记录描述历史版本，新版流程以本验证入口为准。测试使用 `output/story_rebuild_integration/` 下隔离设置与存档，并核对原稿哈希。\n\n", source, flags=re.S)
    path.write_text(source, encoding="utf-8")


if __name__ == "__main__":
    sync_story_docs()
