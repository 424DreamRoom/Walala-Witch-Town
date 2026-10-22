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
    ["艾洛温", "露辛达", "莫文", "托宾", "海泽尔", "梅布尔", "布兰", "皮平", "玛伦", "罗文", "阿芙琳", "塞勒涅"],
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
        ("serve", 8, 70, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "累计上菜", "Meals served", "配膳数", "今天先准备八份蘑菇汤，托宾和大家都想尝尝。", "Eight portions of mushroom soup to start. Tobin and the others would like a taste.", "今日はまずキノコスープを八食分。トビンも皆も楽しみにしてるよ。"),
        ("harvest", 12, 60, "月芽农场", "Moonbud Farm", "月芽農場", "累计收获", "Crops harvested", "収穫数", "面粉的运费太贵了，大家想合在一起订货。梅布尔种的菜也快能收了。", "Flour costs too much to ship alone, so everyone wants to combine orders. Mabel's crops are nearly ready too.", "小麦粉だけだと船代が高くて、皆でまとめて注文することに。メイベルの野菜もそろそろ収穫できそう。"),
        ("fish", 5, 80, "莲雾湿地", "Lotus Marsh", "蓮霧の湿地", "累计鱼获", "Fish caught", "釣果", "田里和鱼池都缺水，谁也不敢多用。旧水渠里那块铁牌，好像跟月环有关。", "The fields and fish pools are short of water. A metal plate in the old channel seems connected to the moonring.", "畑も池も水不足で、皆使いすぎないようにしてる。古い水路の鉄板は月環に関係していそう。"),
        ("ridge", 6, 100, "霜铃山径", "Frost Ridge", "霜鈴の山道", "山径调查", "Ridge survey", "山道の調査", "河口的灯不亮，船晚上进不来，种苗都闷坏了。阿芙琳说山上的值守站还留着图纸。", "Boats can't enter at night without the harbor light, and seedlings have spoiled. Aveline says the old station still has plans.", "河口の灯がつかず船が夜に入れなくて、苗が傷んだの。アヴリーヌによると、山の詰所に図面が残ってるって。"),
        ("scrap", 8, 100, "旧械遗址", "Clockwork Ruins", "古機の遺跡", "累计零件", "Parts gathered", "部品採集", "图纸和旧记录找到了。托宾、莫文都知道当年的事，这回总算能一起说清楚了。", "We found the plans and old logs. Tobin and Morwen were there; now they can explain what happened.", "図面と古い記録が見つかった。トビンもモーウェンも当時のことを知ってるから、一緒に詳しく話せそう。"),
        ("restaurant", 1, 120, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "餐厅等级", "Restaurant level", "食堂レベル", "商队想办三十人的宴席。这笔生意能赚不少，可食材和桌椅还没凑齐。", "The merchants want dinner for thirty. It could pay well, but we're short on ingredients and tables.", "商隊から三十人分の宴会の話が来た。売上は大きいけど、食材もテーブルもまだ足りない。"),
        ("serve", 40, 120, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "累计上菜", "Meals served", "配膳数", "宴席取消了，订金也退了。好在熟客们还照常来，明晚的饭还得准备呢。", "The banquet's cancelled and the deposit returned. The regulars are still coming, so there's dinner to prepare for tomorrow.", "宴会は中止で、手付金も返した。でも常連はいつも通り来てくれる。明日のご飯も用意しないとね。"),
        ("repair_stock", 14, 160, "月环观星台", "Moonring Observatory", "月環天文台", "支路修缮材料", "Branch repair materials", "支線の修繕資材", "大家商量好了，先修水门和河口，不用谁整晚守着。这两段要用铁锭4、零件6、月晶4。", "We're starting with the gate and harbor, without an all-night watch. Materials needed: iron 4, parts 6, crystals 4.", "まず水門と河口を直すことになった。誰かが一晩中見張らなくてもいい形に。必要な資材は鉄4、部品6、月晶4。"),
        ("serve", 60, 180, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "累计上菜", "Meals served", "配膳数", "雨一直下，船暂时进不来。粮食还够，水门也有人看着，食堂今晚照常做饭。", "The rain's keeping the boat out. We have enough food and people watching the gate. The eatery's cooking as usual tonight.", "雨が続いて船が入れない。でも食料は足りていて、水門も皆が見てる。食堂は今夜もいつも通り。"),
        ("serve", 80, 300, "月灯食堂", "Moon Lantern Kitchen", "月灯食堂", "累计上菜", "Meals served", "配膳数", "雨停了，船也快来了。莫文带来了新租约，大家还想问问，你打算哪天歇一天？", "The rain's stopped, and the boat will be here soon. Morwen has a new lease. Everyone wants to know when you're taking a day off.", "雨がやんで、船もそろそろ来る。モーウェンは新しい契約書を持ってきた。皆、あなたがいつ休むのか気にしてるよ。"),
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
            ("记录还没写完。有几次仪器测得不准，我想一块记下来。", "I haven't finished the log. A few readings were off; I want to include those too.", "記録がまだ終わってないんだ。何度か機器の値がずれていて、それも書いておきたくて。"),
            ("以前我只记测准的那几次，出错的就没写。后来修仪器，反倒找不到出问题的记录。", "I used to record only the good readings. Then, when we repaired the instruments, we had no record of what went wrong.", "前は正しく測れた分しか残してなかった。でも修理の時、何がおかしかったか調べられなくなってね。"),
            ("我另画了一栏，左边写自己量的，右边写仪器报的。这下差多少就很清楚了。", "I've added a column: our measurements on the left, the instrument's on the right. Now the difference is clear.", "欄を増やして、左に自分で測った値、右に機器の値を書いた。これで違いがよくわかるよ。"),
            ("这本总算写完了。我把测量的方法也写在最后，下次换个人来，也知道该怎么记。", "Finally finished this volume. I added how we took the measurements, so the next person will know how to keep the log.", "やっと一冊書き終えた。最後に測り方も書いたから、次の人も記録を続けられると思う。"),
            ("今晚天气不错。记录明天再补吧，我想先喝杯茶。", "Nice weather tonight. I'll finish the notes tomorrow. I'd like some tea first.", "今夜はいい天気だね。記録の続きは明日にして、まずお茶を飲もうかな。"),
            ("观星台的课准备好了。大家说那本记录太难懂，我想先讲讲这个，再一起看星星。", "The observatory class is ready. Everyone found the log confusing, so I'll explain it first, then we'll look at the stars.", "天文台の授業の準備ができたよ。記録が難しいと言われたから、まずそれを説明して、その後で皆で星を見よう。"),
        ],
        "orla": [
            ("那张招租告示不只贴在雾港，镇里也贴了。我们一直想把这家食堂重新开起来。", "We put the rental notice up here too, not just in Fog Harbor. We've wanted this eatery open again for a long time.", "募集の紙は霧港だけじゃなく、町にも貼ったのよ。ずっと、この食堂をまた開きたかったの。"),
            ("水门和河口各花了多少钱，都记好了。剩下几条先修哪条，还得听听大家的意思。", "We've recorded the costs for the gate and harbor separately. We'll ask everyone which branch should come next.", "水門と河口にいくらかかったかは、別々に書いてあるわ。残りのどこを先に直すかは、皆にも聞いてみないとね。"),
        ],
        "ember": [
            ("图上明明写着临时用，后来却一直没改回来。灯架我也得一盏盏查，光看图可不放心。", "The plan says temporary, but nobody changed it back. I'll check every lamp frame too; the plans alone aren't enough.", "図面には仮設って書いてあるのに、そのままだった。灯架も一つずつ調べるよ。図面だけじゃ安心できないからな。"),
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
        ("kitchen", "想开自己的店", "An Eatery of Her Own", "自分のお店を開きたくて", "她在雾港后厨干了三年，攒了点钱，想自己开家小食堂，菜单也自己做主。", "She worked in a Fog Harbor kitchen for three years and saved a little money. Now she wanted to run a small eatery and make her own menu.", "霧港の厨房で三年働いて、少しお金を貯めた。小さな食堂を開いて、献立も自分で決めたかった。"),
        ("notice", "第一季免租", "First Season Rent-Free", "最初の季節は家賃無料", "她看到一张招租告示，正好是月芽农场，还有住处和食堂，第一季也不用交租。", "A rental notice caught her eye. It was for Moonsprout Farm, with a cottage and eatery, and no rent for the first season.", "目に留まったのは、月芽農場の募集告示。住まいと食堂がついて、最初の季節は家賃もいらない。"),
        ("road", "带上锅碗，出发", "Packing the Pots and Bowls", "鍋と食器を持って出発", "她带上衣服、锅碗和攒下的钱，坐船去了山谷。自己开店，她还是第一次。", "She packed her clothes, pots and savings, then took a boat to the valley. It was her first time running a place of her own.", "服と調理道具、貯めたお金を持って、船で谷へ。自分のお店を持つのは初めてだった。"),
        ("town", "哗啦啦魔女镇", "Walala Witch Town", "ワララ魔女町", "小镇就在河边，货船能送面粉和盐过来。她想，以后食堂进货应该不难。", "The town was right by the river, so boats could bring in flour and salt. Stocking the eatery should be easy enough, she thought.", "川沿いの町だから、船で小麦粉や塩を運んでこられる。お店の仕入れも難しくなさそうだ。"),
        ("home", "先住下来", "Settling In", "まずはここで暮らそう", "田边的小屋已经收拾好了。她先放下行李，去镇上逛逛，开店的事明天再说。", "The cottage beside the field was ready. She would drop off her things, look around town, and worry about opening tomorrow.", "畑のそばの家は片付いていた。荷物を置いて町を見て回ろう。お店のことは明日からでいい。"),
    ]]
    opening = [dict(location="dock", dialogue=scenes[0][:10]), dict(location="farm", dialogue=scenes[0][10:25]), dict(location="restaurant", dialogue=scenes[0][25:])]
    guide = story["guide"]
    guide.update(welcome=opening[1]["dialogue"], chapters=[q["briefing"] for q in quests], current=[q["briefing"] for q in quests],
                 farewell=text("明天晚一点开门吧，今晚咱们先好好吃顿饭。", "Let's open a little later tomorrow. Tonight, let's sit down and eat.", "明日は少し遅く開けよう。今夜はゆっくりご飯を食べようよ。"))
    # Keep only everyday topics: the legacy mystery and magical feast are retired.
    guide["topics"] = [dict(chapter=i, name=q["name"], lines=[q["briefing"]]) for i, q in enumerate(quests)]
    story["arrival"] = dict(
        name=text("初来乍到", "Settling Into Town", "町に来たばかり"),
        objective=text("回家休息", "Rest at home", "家で休む"),
        place=text("小女巫的家", "Little Witch's Home", "小さな魔女の家"),
        description=text("今天先安顿行李，熟悉住处和小镇。食堂明天开始营业。", "Unpack and get to know your home and the town today. The eatery opens from tomorrow.", "今日は荷物を片付けて、家や町に慣れる日。食堂の営業は明日から。"),
        guide=text("你今天刚到，先安顿下来，在镇上逛逛吧。食堂明天再忙，今晚好好休息。", "You've only just arrived. Settle in and have a look around town. The eatery can wait until tomorrow. Get some rest tonight.", "今日は着いたばかりなんだから、まず落ち着いて町を見て回ろう。食堂は明日から。今夜はゆっくり休んでね。"))
    text("休息", "Rest", "休む")
    text("食堂明天开始营业。", "The eatery opens from tomorrow.", "食堂の営業は明日から。")
    story.update(opening=opening, story_version=2, story_title=text("明天晚点开门", "Opening a Little Later Tomorrow", "明日は少し遅く開店"))
    TRADITIONAL_PATH.write_text(json.dumps(TRADITIONAL, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return story
