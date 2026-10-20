"""Compile the approved ten-chapter manuscript, without a runtime file dependency.

The original UTF-8 dialogue files are the Chinese source of truth. Translation
rows have identical scene/line order; mismatches fail the build.
"""
import ctypes
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DRAFT = ROOT / "Narrative/Rebuild_20261020"
SPEAKERS = dict(zip(
    ["薇尔莉娅", "萤萝", "奥萝", "陶陶", "露米", "茉莉", "余烬", "皮普", "澪", "芦苇", "霜铃", "星芒"],
    ["player", "yingluo", "orla", "toma", "lumi", "mori", "ember", "pip", "nagi", "reed", "yuki", "aster"]))
TRADITIONAL_PATH = DRAFT / "translations_zh_TW.json"
TRADITIONAL = json.loads(TRADITIONAL_PATH.read_text(encoding="utf-8")) if TRADITIONAL_PATH.exists() else {}


def traditional(text):
    if text in TRADITIONAL:
        return TRADITIONAL[text]
    # The checked-in map makes normal builds portable. New source lines can be
    # authored in the map, or initially converted on Windows and reviewed there.
    assert hasattr(ctypes, "windll"), f"Missing Traditional Chinese translation: {text}"
    buffer = ctypes.create_unicode_buffer(len(text) * 3 + 1)
    result = ctypes.windll.kernel32.LCMapStringEx("zh-TW", 0x04000000, text, len(text), buffer, len(buffer), None, None, 0)
    assert result, "Traditional Chinese conversion failed"
    TRADITIONAL[text] = buffer.value
    return TRADITIONAL[text]


def rebuild_story(quests, intro, regions, npcs, story, t):
    manifest = json.loads((DRAFT / "场景索引.json").read_text(encoding="utf-8"))
    translated = {}
    path = DRAFT / "translations_en_ja.txt"
    if path.exists():
        current = None
        for row in path.read_text(encoding="utf-8").splitlines():
            if not row.strip():
                continue
            if row.startswith("@"):
                current = row[1:]
                translated[current] = []
            else:
                pair = row.split("|", 1)
                assert len(pair) == 2 and all(pair), row
                translated[current].append(pair)
    scenes = []
    for scene in manifest["scenes"]:
        source = (DRAFT / scene["file"]).read_text(encoding="utf-8").splitlines()
        source = [row for row in source if row.strip()]
        pairs = translated.get(scene["id"], [])
        assert len(pairs) == len(source), f"Translation count differs: {scene['id']}: {len(pairs)}/{len(source)}"
        beats = []
        for row, (en, ja) in zip(source, pairs):
            name, text = row.split("：", 1)
            beats.append(dict(speaker=SPEAKERS[name], text=t(text, en, ja, traditional(text))))
        scenes.append(beats)

    def text(zh, en, ja):
        return t(zh, en, ja, traditional(zh))

    names_en = ["The First Menu", "Not Quite a Boatload", "How Much Land Is Enough?", "Lights on the Old Road", "Her Last Night Watch", "An Order Too Large", "The First Cancellation", "Two Lights First", "That Rainy Night", "Opening a Little Later Tomorrow"]
    names_ja = ["最初の献立", "一艘に足りない荷物", "畑はどれだけ必要？", "古道の灯", "彼女の最後の夜番", "大きすぎた注文", "初めてのキャンセル", "まず二つの灯から", "あの雨の夜", "明日は少し遅く開店"]
    rows = [
        ("serve", 8, 70, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "累计上菜", "Meals served", "配膳数", "第一锅汤只有八碗，熟客们各有各的口味。", "Eight bowls of soup, and guests with tastes of their own.", "最初のスープは八杯。常連にもそれぞれの好みがある。"),
        ("harvest", 12, 60, "月芽农场", "Moonbud Farm", "月芽農場", "累计收获", "Crops harvested", "収穫数", "货少，运费却不少。本地产的蔬菜也能进菜单。", "Small orders still cost a boat trip. Local crops could fill the menu.", "少ない荷物にも船代はかかる。地元の野菜も献立に加えたい。"),
        ("fish", 5, 80, "莲雾湿地", "Lotus Marsh", "蓮霧の湿地", "累计鱼获", "Fish caught", "釣果", "田地和浅池都缺水，旧支渠里露出一块烧蚀的铁牌。", "Fields and pools need water. A scorched plate lies in the old channel.", "畑も浅池も水不足。旧水路には焼けた鉄板がある。"),
        ("ridge", 6, 100, "霜铃山径", "Frost Ridge", "霜鈴の山道", "山径调查", "Ridge survey", "山道の調査", "引航灯熄灭后，货船只能在河口等到天亮。旧值守站还留着图纸。", "With navigation lights out, boats wait for dawn. Plans remain at the old station.", "航路灯が消え、船は河口で夜明けを待つ。旧詰所には図面が残る。"),
        ("scrap", 8, 100, "旧械遗址", "Clockwork Ruins", "古機の遺跡", "累计零件", "Parts gathered", "部品採集", "旧线路和值守簿留下不同的痕迹，亲历者终于坐到同一张桌前。", "Wiring and logs tell parts of the story. Its witnesses finally share a table.", "配線と日誌に残る痕跡。あの夜を知る人々が同じ机につく。"),
        ("restaurant", 1, 120, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "餐厅等级", "Restaurant level", "食堂レベル", "三十人的试菜宴，意味着收入，也意味着尚未确定的供应。", "A tasting for thirty offers income, but its supplies are still uncertain.", "三十人の試食会。収入は魅力だが、食材の確保はまだ決まらない。"),
        ("serve", 40, 120, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "累计上菜", "Meals served", "配膳数", "退掉大订单以后，日常的饭仍要一份份做好。", "After cancelling the large order, everyday meals still need care.", "大口注文を断っても、毎日の食事は一皿ずつ大切に作る。"),
        ("repair_stock", 14, 160, "月环观星台", "Moonring Observatory", "月環天文台", "支路修缮材料", "Branch repair materials", "支線の修繕資材", "先恢复水门和河口，两条支路各自检修。铁锭4、零件6、月晶4。", "Restore the gate and harbor independently. Iron 4, parts 6, crystals 4.", "水門と河口を独立して修理する。鉄4、部品6、月晶4。"),
        ("serve", 60, 180, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "累计上菜", "Meals served", "配膳数", "连日降雨，货船暂缓入港。储粮、现场水位和热饭各有人照看。", "Rain delays the boat. Stores, water checks and hot meals each have a keeper.", "長雨で入港は延期。備蓄、現場の水位、温かな食事を皆で支える。"),
        ("serve", 80, 300, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "累计上菜", "Meals served", "配膳数", "雨停了，日子还要往后过。续租和休息日都能慢慢商量。", "The rain ends and life continues. There is time to discuss a lease and a day off.", "雨がやみ、暮らしは続く。更新する契約も休む日も、ゆっくり話せばいい。"),
    ]
    quests.clear()
    for i, row in enumerate(rows):
        metric, goal, reward, zh_place, en_place, ja_place, zh_obj, en_obj, ja_obj, zh, en, ja = row
        q = dict(id=f"main_{i:02}", name=text(manifest["scenes"][i + 1]["title"], names_en[i], names_ja[i]), metric=metric, goal=goal, reward=reward,
                 place=text(zh_place, en_place, ja_place), objective=text(zh_obj, en_obj, ja_obj), briefing=text(zh, en, ja), description=text(zh, en, ja), dialogue=scenes[i + 1])
        if i == 7:
            q["cost"] = dict(iron=4, scrap=6, crystal=4)
        quests.append(q)
    for region in regions:
        region["legacy_chapter"] = region["chapter"]
        region["chapter"] = dict(grove=0, quarry=1, marsh=2, ruins=4, ridge=3, observatory=7)[region["id"]]

    # Retain friendship progress and gifts, retire side-story claims that would
    # contradict the new public notice and the living former keeper.
    replacements = {
        "aster": [
            ("观测记录还欠几页。我想把仪器的误差也写进去。", "My observation log is a few pages short. I want to include the instruments' errors.", "観測記録がまだ数頁足りない。機器の誤差も書いておきたい。"),
            ("以前我总把读数写得太整齐。不好看的那几次，反而最该留下。", "I used to make my readings too tidy. The untidy ones needed saving most.", "昔は測定値をきれいに揃えすぎた。うまくいかなかった記録こそ残すべきだった。"),
            ("我把现场测量和仪器读数分开记了。差多少，现在谁都能核对。", "Field measurements and instrument readings now have separate columns. Anyone can check the difference.", "現場の測定と機器の値を分けて書いた。差は誰でも確かめられる。"),
            ("最后一页填完了，不是每个数字都一样。下次测量的人还能继续往下写。", "The last page is filled, with differences intact. The next observer can continue it.", "最後の頁まで書いた。数字の違いも残したから、次の人が続きを書ける。"),
            ("今晚天晴，记录不急着补完。先喝完这杯茶。", "Clear skies tonight. The log can wait until I've finished this tea.", "今夜は晴れ。記録はこのお茶を飲んでからでも間に合う。"),
            ("观星台的公开课准备好了。先讲怎么看懂一张记录，再讲天上的星星。", "The observatory class is ready. First, reading a log; then, reading the stars.", "天文台の公開授業の準備ができた。まず記録の読み方、それから星の話をしよう。"),
        ],
        "orla": [
            ("招租告示是镇里公开贴的。免租的费用也记在账上，你随时能看。", "The rental notice was public. The rent subsidy is in the town accounts, open to you.", "募集告示は町で公開したものよ。家賃免除の費用も帳簿でいつでも見られるわ。"),
            ("水门和河口的修缮已经分开记账，剩下的支路还得逐项商量。", "Gate and harbor repairs now have separate accounts. Each remaining branch still needs discussion.", "水門と河口は別々に会計をつけた。残る支線も一つずつ相談しないとね。"),
        ],
        "ember": [
            ("图纸上的临时改接拖成了常用接法。灯架也得逐个检查，不能只凭图纸说没问题。", "Temporary wiring became permanent. Every lamp frame needs inspection; plans alone don't prove it sound.", "臨時の配線が常用になった。灯架も一つずつ点検する。図面だけで無事とは言えない。"),
        ],
    }
    for npc in npcs:
        if npc["id"] == "aster":
            values = [text(*row) for row in replacements["aster"]]
            npc["lines"] = values[:5]
            npc["events"] = [*values[1:4], values[5]]
            npc["stories"] = [text(*row) for row in [
                ("没有删掉的读数", "Unedited Readings", "消さなかった測定値"), ("两栏记录", "Two Columns", "二列の記録"),
                ("下一位观测者", "The Next Observer", "次の観測者"), ("星空公开课", "An Open Sky Class", "星空の公開授業")]]
        elif npc["id"] == "orla":
            npc["events"][0] = text(*replacements["orla"][0])
            npc["lines"][1] = npc["events"][0]
            npc["lines"][4] = text(*replacements["orla"][1])
        elif npc["id"] == "ember":
            npc["events"][1] = text(*replacements["ember"][0])
            npc["lines"][2] = npc["events"][1]

    intro[:] = [dict(scene=scene, title=text(zh_title, en_title, ja_title), line=text(zh, en, ja)) for scene, zh_title, en_title, ja_title, zh, en, ja in [
        ("kitchen", "雾港的第三年", "Three Years at Fog Harbor", "霧港で三年", "洗碗、切菜、看灶。薇尔莉娅想试试，能不能开一家写着自己名字的食堂。", "Dishes, chopping, tending the stove. Virelia wanted a kitchen with her own name above the door.", "皿洗い、下ごしらえ、火の番。ヴィレリアは自分の名を掲げる食堂を開いてみたかった。"),
        ("notice", "一张公开的招租告示", "A Public Rental Notice", "一枚の入居者募集", "月芽农场，附月灯食堂。试营一年，第一季免租。她把最后一句圈了起来。", "Moonbud Farm, with Moon Lantern Kitchen. A one-year trial; first season rent-free. She circled that last part.", "月芽農場、月灯食堂付き。一年間の試営、最初の季節は家賃無料。彼女は最後の一行を丸で囲んだ。"),
        ("road", "自己的锅", "A Pot of Her Own", "自分の鍋", "行李里有一口锅、三只碗和一支笔。锅盖在每个渡口都响得很大声。", "A pot, three bowls and a pen. The lid rattled at every crossing.", "荷物には鍋と三つの器と一本のペン。渡し場のたびに蓋が大きな音を立てた。"),
        ("town", "山谷里的小镇", "A Town in the Valley", "谷間の町", "山上的月环已经暗了许久。街边的小灯还亮着，码头有人等着收货。", "The mountain moonring had long been dark. Street lamps still glowed, and someone waited for cargo at the dock.", "山の月環は長い間消えたまま。街の小さな灯はともり、波止場では荷物を待つ人がいた。"),
        ("home", "提锅来的那位", "The One with the Pot", "鍋を持ってきた人", "屋顶刚补过，田里长着草。至于食堂的菜单，她还没有决定。", "A patched roof, an overgrown field. The menu could wait until she arrived.", "直したばかりの屋根、草の茂る畑。食堂の献立は、まだ決めていなかった。"),
    ]]
    opening = [dict(location="dock", dialogue=scenes[0][:10]), dict(location="farm", dialogue=scenes[0][10:25]), dict(location="restaurant", dialogue=scenes[0][25:])]
    guide = story["guide"]
    guide.update(welcome=opening[1]["dialogue"], chapters=[q["briefing"] for q in quests], current=[q["briefing"] for q in quests],
                 farewell=text("今天的饭已经有了。明天晚一点开门，也来得及。", "Dinner is ready. Tomorrow can start a little later.", "今日のご飯はもうできた。明日は少し遅く開けても大丈夫。"))
    # Keep only everyday topics: the legacy mystery and magical feast are retired.
    guide["topics"] = [dict(chapter=i, name=q["name"], lines=[q["briefing"]]) for i, q in enumerate(quests)]
    story.update(opening=opening, story_version=2, story_title=text("明天晚点开门", "Opening a Little Later Tomorrow", "明日は少し遅く開店"))
    TRADITIONAL_PATH.write_text(json.dumps(TRADITIONAL, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return story
