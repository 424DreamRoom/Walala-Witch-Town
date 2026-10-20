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
        ("serve", 8, 70, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "累计上菜", "Meals served", "配膳数", "今天先准备八份蘑菇汤，陶陶和大家都想尝尝。", "Eight portions of mushroom soup to start. Toma and the others would like a taste.", "今日はまずキノコスープを八食分。トマも皆も楽しみにしてるよ。"),
        ("harvest", 12, 60, "月芽农场", "Moonbud Farm", "月芽農場", "累计收获", "Crops harvested", "収穫数", "面粉的运费太贵了，大家想合在一起订货。茉莉种的菜也快能收了。", "Flour costs too much to ship alone, so everyone wants to combine orders. Mori's crops are nearly ready too.", "小麦粉だけだと船代が高くて、皆でまとめて注文することに。モリの野菜もそろそろ収穫できそう。"),
        ("fish", 5, 80, "莲雾湿地", "Lotus Marsh", "蓮霧の湿地", "累计鱼获", "Fish caught", "釣果", "田里和鱼池都缺水，谁也不敢多用。旧水渠里那块铁牌，好像跟月环有关。", "The fields and fish pools are short of water. A metal plate in the old channel seems connected to the moonring.", "畑も池も水不足で、皆使いすぎないようにしてる。古い水路の鉄板は月環に関係していそう。"),
        ("ridge", 6, 100, "霜铃山径", "Frost Ridge", "霜鈴の山道", "山径调查", "Ridge survey", "山道の調査", "河口的灯不亮，船晚上进不来，种苗都闷坏了。霜铃说山上的值守站还留着图纸。", "Boats can't enter at night without the harbor light, and seedlings have spoiled. Yuki says the old station still has plans.", "河口の灯がつかず船が夜に入れなくて、苗が傷んだの。ユキによると、山の詰所に図面が残ってるって。"),
        ("scrap", 8, 100, "旧械遗址", "Clockwork Ruins", "古機の遺跡", "累计零件", "Parts gathered", "部品採集", "图纸和旧记录找到了。陶陶、奥萝都知道当年的事，这回总算能一起说清楚了。", "We found the plans and old logs. Toma and Orla were there; now they can explain what happened.", "図面と古い記録が見つかった。トマもオルラも当時のことを知ってるから、一緒に詳しく話せそう。"),
        ("restaurant", 1, 120, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "餐厅等级", "Restaurant level", "食堂レベル", "商队想办三十人的宴席。这笔生意能赚不少，可食材和桌椅还没凑齐。", "The merchants want dinner for thirty. It could pay well, but we're short on ingredients and tables.", "商隊から三十人分の宴会の話が来た。売上は大きいけど、食材もテーブルもまだ足りない。"),
        ("serve", 40, 120, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "累计上菜", "Meals served", "配膳数", "宴席取消了，订金也退了。好在熟客们还照常来，明晚的饭还得准备呢。", "The banquet's cancelled and the deposit returned. The regulars are still coming, so there's dinner to prepare for tomorrow.", "宴会は中止で、手付金も返した。でも常連はいつも通り来てくれる。明日のご飯も用意しないとね。"),
        ("repair_stock", 14, 160, "月环观星台", "Moonring Observatory", "月環天文台", "支路修缮材料", "Branch repair materials", "支線の修繕資材", "大家商量好了，先修水门和河口，不用谁整晚守着。这两段要用铁锭4、零件6、月晶4。", "We're starting with the gate and harbor, without an all-night watch. Materials needed: iron 4, parts 6, crystals 4.", "まず水門と河口を直すことになった。誰かが一晩中見張らなくてもいい形に。必要な資材は鉄4、部品6、月晶4。"),
        ("serve", 60, 180, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "累计上菜", "Meals served", "配膳数", "雨一直下，船暂时进不来。粮食还够，水门也有人看着，食堂今晚照常做饭。", "The rain's keeping the boat out. We have enough food and people watching the gate. The eatery's cooking as usual tonight.", "雨が続いて船が入れない。でも食料は足りていて、水門も皆が見てる。食堂は今夜もいつも通り。"),
        ("serve", 80, 300, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "累计上菜", "Meals served", "配膳数", "雨停了，船也快来了。奥萝带来了新租约，大家还想问问，你打算哪天歇一天？", "The rain's stopped, and the boat will be here soon. Orla has a new lease. Everyone wants to know when you're taking a day off.", "雨がやんで、船もそろそろ来る。オルラは新しい契約書を持ってきた。皆、あなたがいつ休むのか気にしてるよ。"),
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
        ("kitchen", "想开自己的店", "An Eatery of Her Own", "自分のお店を開きたくて", "在雾港后厨干了三年，薇尔莉娅攒下一点钱。她想试着开家小食堂，自己定菜单。", "After three years in a Fog Harbor kitchen, Virelia had a little money saved. She wanted to try running a small eatery and choosing her own menu.", "霧港の厨房で三年働いて、ヴィレリアは少しお金を貯めた。小さな食堂を開いて、自分で献立を決めてみたかった。"),
        ("notice", "第一季免租", "First Season Rent-Free", "最初の季節は家賃無料", "一张招租告示让她动了心：月芽农场，带住处和食堂，第一季不用交租。", "A rental notice caught her eye: Moonbud Farm, with a cottage and eatery. No rent for the first season.", "目に留まったのは、月芽農場の募集告示。住まいと食堂付きで、最初の季節は家賃がいらない。"),
        ("road", "带上锅碗，出发", "Packing the Pots and Bowls", "鍋と食器を持って出発", "她带上衣服、锅碗和攒下的钱，坐船去了山谷。自己开店，这还是头一回。", "She packed clothes, cookware and her savings, then took a boat to the valley. This would be her first time running a place of her own.", "服と調理道具、貯めたお金を持って、船で谷へ。自分のお店を持つのは、これが初めてだった。"),
        ("town", "哗啦啦魔女镇", "Walala Witch Town", "ワララ魔女町", "小镇就在河边，货船能送来面粉和盐。她想，以后食堂进货应该挺方便。", "The town stood by the river, with flour and salt arriving by boat. That should make stocking the eatery easy, she thought.", "川沿いの町には、船で小麦粉や塩が届く。お店の仕入れもしやすそうだと、彼女は思った。"),
        ("home", "先住下来", "Settling In", "まずはここで暮らそう", "小屋就在田边。她还没想好第一天卖什么，不过，眼下得先吃顿饭。", "The cottage was beside the field. She hadn't settled on an opening menu, but first she needed dinner.", "小さな家は畑のそば。初日の献立はまだ決めていないけれど、まずは自分もご飯を食べなくちゃ。"),
    ]]
    opening = [dict(location="dock", dialogue=scenes[0][:10]), dict(location="farm", dialogue=scenes[0][10:25]), dict(location="restaurant", dialogue=scenes[0][25:])]
    guide = story["guide"]
    guide.update(welcome=opening[1]["dialogue"], chapters=[q["briefing"] for q in quests], current=[q["briefing"] for q in quests],
                 farewell=text("明天晚一点开门吧，今晚咱们先好好吃顿饭。", "Let's open a little later tomorrow. Tonight, let's sit down and eat.", "明日は少し遅く開けよう。今夜はゆっくりご飯を食べようよ。"))
    # Keep only everyday topics: the legacy mystery and magical feast are retired.
    guide["topics"] = [dict(chapter=i, name=q["name"], lines=[q["briefing"]]) for i, q in enumerate(quests)]
    story.update(opening=opening, story_version=2, story_title=text("明天晚点开门", "Opening a Little Later Tomorrow", "明日は少し遅く開店"))
    TRADITIONAL_PATH.write_text(json.dumps(TRADITIONAL, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return story
