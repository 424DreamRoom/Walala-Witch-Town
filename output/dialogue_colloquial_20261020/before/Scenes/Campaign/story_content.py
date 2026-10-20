"""Localized narrative and introductory goals, applied after legacy copy rewrites.

Stable quest IDs, costs, rewards and save fields belong to build_content.py.
Dialogue records contain a speaker ID and a localized source, never input advice.
"""


def expand_story(quests, intro, t):
    def line(speaker, zh, en, ja, tw):
        return dict(speaker=speaker, text=t(zh, en, ja, tw))

    places = [
        ('微光采集地 · 萤灯森林', 'Glimmer Woods · Firefly Grove', '微光の採集地・蛍灯の森', '微光採集地 · 螢燈森林'),
        ('小镇餐厅', 'Town Eatery', '町の食堂', '小鎮餐廳'),
        ('月芽农场', 'Moonsprout Farm', '月芽農場', '月芽農場'),
        ('余烬石谷', 'Ember Quarry', '残火の石谷', '餘燼石谷'),
        ('潮汐码头 · 莲雾湿地', 'Tidal Dock · Lotus Marsh', '潮の桟橋・蓮霧の湿地', '潮汐碼頭 · 蓮霧濕地'),
        ('哗啦啦魔女镇', 'Walala Witch Town', 'ワララ魔女の町', '嘩啦啦魔女鎮'),
        ('旧械遗址', 'Clockwork Ruins', '古機の遺跡', '舊械遺址'),
        ('小镇餐厅 · 成长', 'Town Eatery · Growth', '町の食堂・成長', '小鎮餐廳 · 成長'),
        ('霜铃山径', 'Frost Ridge', '霜鈴の山道', '霜鈴山徑'),
        ('月芽农场 · 四季', 'Moonsprout Farm · Four Seasons', '月芽農場・四季', '月芽農場 · 四季'),
        ('月环观星台 · 余烬石谷', 'Moonring Observatory · Ember Quarry', '月環天文台・残火の石谷', '月環觀星臺 · 餘燼石谷'),
        ('月灯食堂', 'Moon Lantern Kitchen', '月灯食堂', '月燈食堂'),
    ]
    briefings = [
        ('旧食堂还留着陶陶的备料篮，篮底压着一张三人份的旧菜单。', 'Toma’s prep basket remains in the eatery, with an old menu for three beneath it.', '食堂にはトマの仕込み籠が残り、底に三人分の古い献立が挟まっている。', '舊食堂還留著陶陶的備料籃，籃底壓著一張三人份的舊菜單。'),
        ('三只旧碗已经擦净。今晚的晚餐，是食堂重新开门后的第一份约定。', 'Three old bowls are clean. Tonight’s dinner is the reopened eatery’s first promise.', '古い器が三つ、きれいになった。今夜の夕食は、再開した食堂の最初の約束。', '三隻舊碗已經擦淨。今晚的晚餐，是食堂重新開門後的第一份約定。'),
        ('茉莉留下了当季种子。食堂有了第一桌晚餐，也需要明天的新鲜收获。', 'Mori left seasonal seeds. The first dinner needs a harvest for tomorrow, too.', 'モリが季節の種を残した。最初の夕食の次には、明日の収穫も必要だ。', '茉莉留下了當季種子。食堂有了第一桌晚餐，也需要明天的新鮮收穫。'),
        ('余烬在旧水门图纸上圈出一只缺齿的齿轮，石谷的矿脉还没有枯竭。', 'Ember circled a broken gear on the sluice plans. The quarry still holds ore.', 'エンバーは水門の図面で欠けた歯車に丸をつけた。石谷にはまだ鉱石がある。', '餘燼在舊水門圖紙上圈出一隻缺齒的齒輪，石谷的礦脈還沒有枯竭。'),
        ('芦苇重新听见水声。不同水域的鱼群，是水道恢复后最先回来的客人。', 'Reed hears water again. Fish are the first guests returning to the waterways.', 'リードは再び水音を聞いた。水路に最初に帰ってきた客は魚たちだった。', '蘆葦重新聽見水聲。不同水域的魚群，是水道恢復後最先回來的客人。'),
        ('食堂里渐渐有了熟悉的座位。有些旧事，只有信任的人才听得到。', 'Familiar seats return to the eatery. Some old stories are shared only with a trusted friend.', '食堂にいつもの席が戻りつつある。古い話には、信頼できる人にだけ話せるものもある。', '食堂裡漸漸有了熟悉的座位。有些舊事，只有信任的人才聽得到。'),
        ('遗址的门已经开放。散落的旧械零件上，还刻着月环熄灭当夜的编号。', 'The ruins are open. Scattered machine parts still bear the numbers from that night.', '遺跡の門は開いた。散らばる部品には、月環が消えた夜の番号が刻まれている。', '遺址的門已經開放。散落的舊械零件上，還刻著月環熄滅當夜的編號。'),
        ('旧械记录提到一张公共长桌。更多的座位，能容下从山上回来的人。', 'The machine records mention a shared table. More seats will welcome those returning from the hills.', '古機の記録には皆の長机が出てくる。席が増えれば、山から帰る人も迎えられる。', '舊械記錄提到一張公共長桌。更多的座位，能容下從山上回來的人。'),
        ('霜铃带回半枚旧邮戳。山径上的遗物里，或许留着信的另一半日期。', 'Yuki brought half an old postmark. Objects along the ridge may hold the missing date.', 'ユキは古い消印の半分を持ち帰った。山道の遺物に、残りの日付があるかもしれない。', '霜鈴帶回半枚舊郵戳。山徑上的遺物裡，或許留著信的另一半日期。'),
        ('星图的十二处空格对应不同收获。春夏秋冬，都有自己的那一页。', 'Twelve blanks on the chart match different harvests. Every season has its own page.', '星図の十二の空欄は、それぞれの収穫に対応している。どの季節にも自分の頁がある。', '星圖的十二處空格對應不同收穫。春夏秋冬，都有自己的那一頁。'),
        ('完整的四季星图已经就绪。月晶中的旧记录，还缺最后几段回声。', 'The seasonal chart is complete. The crystals still hold a few missing echoes.', '四季の星図は完成した。月晶の古い記録には、まだ欠けた響きがある。', '完整的四季星圖已經就緒。月晶中的舊記錄，還缺最後幾段回聲。'),
        ('长桌的三道宴席料理是星河锦鲤宴、四季拼盘和月灯甜点。每一种都留着小镇的记忆。', 'The feast has Star Koi Banquet, Four Seasons Platter and Lantern Dessert. Each holds a town memory.', '長机の宴料理は星河ニシキゴイ宴、四季の盛り合わせ、月灯デザート。どれも町の記憶を宿す。', '長桌的三道宴席料理是星河錦鯉宴、四季拼盤和月燈甜點。每一種都留著小鎮的記憶。'),
    ]
    results = [
        ('三份新鲜食材进了手记。陶陶擦净旧碗，第一次晚餐有了着落。', 'Three fresh ingredients are recorded. Toma cleans the bowls; the first dinner feels possible.', '三つの新鮮な食材が手帳に記された。トマは器を磨き、最初の夕食が見えてきた。', '三份新鮮食材進了手記。陶陶擦淨舊碗，第一次晚餐有了著落。'),
        ('三份晚餐端上桌，食堂外的月灯亮了一瞬。茉莉说起种子，约好了下一次收获。', 'Three dinners reach the table. A moon lantern flickers, and Mori promises to share the next harvest.', '三つの夕食が並び、外の月灯が一瞬灯った。モリは種の話をして、次の収穫を約束した。', '三份晚餐端上桌，食堂外的月燈亮了一瞬。茉莉說起種子，約好了下一次收穫。'),
        ('五份收获记进手记。余烬认出了田边旧路牌上的水门标记。', 'Five harvests enter the journal. Ember recognizes the sluice mark on the old field sign.', '五つの収穫が手帳に加わった。エンバーは畑の古い標識に、水門の印を見つけた。', '五份收穫記進手記。餘燼認出了田邊舊路牌上的水門標記。'),
        ('石谷的矿脉重新有了记录。余烬补全水门图纸，湿地又传来水声。', 'The quarry veins are recorded again. Ember completes the sluice plans, and water returns to the marsh.', '石谷の鉱脈が再び記録された。エンバーが水門の図面を完成させ、湿地に水音が戻った。', '石谷的礦脈重新有了記錄。餘燼補全水門圖紙，濕地又傳來水聲。'),
        ('五次鱼获留下水道的消息。芦苇在网边发现一枚刻有旧械编号的薄片。', 'Five catches tell of the waterways. Reed finds a plate marked with a machine number beside the nets.', '五度の釣果が水路の様子を伝えた。リードは網のそばに、古機の番号がある薄片を見つけた。', '五次魚獲留下水道的消息。蘆葦在網邊發現一枚刻有舊械編號的薄片。'),
        ('有人开始为明天留座。皮普把遗址钥匙放到公共桌上，旧事不再只由一个人保管。', 'Someone saves a seat for tomorrow. Pip leaves the ruins key on the shared table.', '明日の席を残す人が現れた。ピップは遺跡の鍵を皆の机に置き、過去を一人で守るのをやめた。', '有人開始為明天留座。皮普把遺址鑰匙放到公共桌上，舊事不再只由一個人保管。'),
        ('八份零件的编号拼成一段记录：那台核心曾把所有灯连在同一条回路上。', 'Eight part numbers form a record: the core once linked every lantern to one circuit.', '八つの部品番号から記録がつながった。核はかつて、すべての灯を一つの回路に結んでいた。', '八份零件的編號拼成一段記錄：那臺核心曾把所有燈連在同一條迴路上。'),
        ('月灯食堂有了更多座位。奥萝给匿名信补上落款，霜铃带来了山径的消息。', 'More seats fill Moon Lantern Kitchen. Orla signs her letter, and Yuki brings news from the ridge.', '月灯食堂の席が増えた。オルラは匿名の手紙に署名し、ユキは山道の便りを届けた。', '月燈食堂有了更多座位。奧蘿給匿名信補上落款，霜鈴帶來了山徑的消息。'),
        ('六次山径调查补齐旧信日期。守灯人的记录提到：月环留下了最后一段记忆。', 'Six ridge finds complete the date. A lantern keeper’s record says the ring held one final memory.', '六度の山道調査で手紙の日付がそろった。灯守の記録には、月環が最後の記憶を留めたとある。', '六次山徑調查補齊舊信日期。守燈人的記錄提到：月環留下了最後一段記憶。'),
        ('十二种作物把星图连成四季。观星台认出了这些真实生长过的日子。', 'Twelve crops connect the seasonal chart. The observatory recognizes days that were truly lived.', '十二種の作物が星図を四季につないだ。天文台は、実際に育まれた日々を読み取った。', '十二種作物把星圖連成四季。觀星臺認出了這些真實生長過的日子。'),
        ('八枚月晶接续了旧记录。月环靠共同生活的记忆发光，新的一餐能承接旧日的守护。', 'Eight crystals restore the record. Shared memories light the ring; a new meal can carry its old promise.', '八つの月晶が古い記録をつないだ。月環を灯すのは共に生きた記憶。新しい食卓が昔の守りを受け継ぐ。', '八枚月晶接續了舊記錄。月環靠共同生活的記憶發光，新的一餐能承接舊日的守護。'),
        ('三种宴席料理端上长桌，月环重新照亮山谷。那封信等到了回音，也等到了你的座位。', 'Three feast dishes reach the table. The ring lights the valley; the letter has its answer and you have a seat.', '三種の宴料理が長机に並び、月環が谷を照らした。手紙には返事が、あなたには席ができた。', '三種宴席料理端上長桌，月環重新照亮山谷。那封信等到了回音，也等到了你的座位。'),
    ]
    scenes = [
        [
            ('toma', '这只篮子空了很久。我还以为，再没人记得它该装什么。', 'This basket sat empty for years. I thought nobody remembered what belonged in it.', 'この籠はずっと空だった。何を入れるか、皆忘れたと思っていたよ。', '這隻籃子空了很久。我還以為，再沒人記得它該裝什麼。'),
            ('player', '装今晚的晚餐。三只碗，你也有一只。', 'Tonight’s dinner. There are three bowls, and one is yours.', '今夜の夕食を入れるの。器は三つ、あなたの分もある。', '裝今晚的晚餐。三隻碗，你也有一隻。'),
            ('toma', '我的也算上？……那我把旧菜单上的汤名重新描一遍。', 'Mine, too? Then I’ll ink the soup names on that old menu again.', '私の分も？……それなら、古い献立のスープの名を書き直そう。', '我的也算上？……那我把舊菜單上的湯名重新描一遍。'),
            ('yingluo', '原料有了，食堂也终于有了等晚餐的人。', 'There is food now, and someone waiting to share it.', '食材がそろい、夕食を待つ人もできたね。', '原料有了，食堂也終於有了等晚餐的人。'),
        ],
        [
            ('mori', '汤还是热的。以前大家总说，明天再来。后来就没有明天了。', 'The soup is warm. We used to say we’d come tomorrow. Then tomorrow stopped coming.', 'スープ、温かい。昔は皆「また明日」って。いつからか、その明日が来なくなった。', '湯還是熱的。以前大家總說，明天再來。後來就沒有明天了。'),
            ('player', '这次还有明天。农场的地，我也想让它重新长出东西。', 'There will be a tomorrow this time. I want the farm to grow again, too.', '今度は明日があるよ。農場にも、また作物を育てたい。', '這次還有明天。農場的地，我也想讓它重新長出東西。'),
            ('mori', '我留下的种子都是这个季节的。第一顿饭的味道，我会记着。', 'The seeds I left suit this season. I’ll remember this first dinner.', '残した種は今の季節のもの。最初の夕食の味、覚えておくね。', '我留下的種子都是這個季節的。第一頓飯的味道，我會記著。'),
            ('yingluo', '刚才那盏月灯亮了一下。很短，不过我看见了。', 'That moon lantern flickered just now. Only briefly, but I saw it.', 'さっき、月灯が一瞬灯った。短かったけれど、確かに見えたよ。', '剛才那盞月燈亮了一下。很短，不過我看見了。'),
        ],
        [
            ('mori', '这片地又有动静了。原来它一直没忘记春天。', 'The field is stirring again. It never forgot spring.', '畑がまた動き出した。この土は、春を忘れていなかったんだ。', '這片地又有動靜了。原來它一直沒忘記春天。'),
            ('ember', '田边路牌上的印子，是旧水门。我的图纸还缺一只齿轮。', 'That mark on the field sign is the old sluice. My plans still lack a gear.', '畑の標識の印は古い水門だ。図面には、まだ歯車が一つ足りない。', '田邊路牌上的印子，是舊水門。我的圖紙還缺一隻齒輪。'),
            ('player', '食堂的锅里已经有新收获了。水门那边，也该有新的声音。', 'The pots have a fresh harvest now. The sluice deserves a new sound, too.', '鍋には新しい収穫が入った。水門にも、新しい音が戻るといいね。', '食堂的鍋裡已經有新收穫了。水門那邊，也該有新的聲音。'),
            ('yingluo', '饭桌上的事，慢慢连到了饭桌以外。', 'The life around our table is reaching beyond it.', '食卓の暮らしが、少しずつ外の世界につながっているね。', '飯桌上的事，慢慢連到了飯桌以外。'),
        ],
        [
            ('ember', '矿脉的纹路对上了。齿轮的缺口，我知道该怎么补。', 'The quarry lines match. I know how to mend that gear now.', '鉱脈の筋がつながった。歯車の欠けをどう直すか、見えてきた。', '礦脈的紋路對上了。齒輪的缺口，我知道該怎麼補。'),
            ('reed', '莲塘那边有水声了。候鸟清单上的空行，也许还能填回来。', 'I hear water at the lotus pond. Perhaps those empty bird-list lines will fill again.', '蓮池に水音が戻った。鳥の名簿の空欄も、また埋まるかもしれない。', '蓮塘那邊有水聲了。候鳥清單上的空行，也許還能填回來。'),
            ('player', '下一锅汤，也许会有从水里来的味道。', 'Perhaps our next soup will carry a taste of the water.', '次のスープには、水辺の味も入るかもしれないね。', '下一鍋湯，也許會有從水裡來的味道。'),
            ('yingluo', '月灯底下那圈细纹，又亮起了一小段。', 'Another small arc beneath the lantern is glowing.', '月灯の下の細い輪が、また少しだけ光ったよ。', '月燈底下那圈細紋，又亮起了一小段。'),
        ],
        [
            ('nagi', '鱼回来了，码头就不像只通往远方的地方了。', 'With the fish back, the dock feels like more than a place to leave.', '魚が戻ると、桟橋もただ遠くへ行く場所じゃなくなるね。', '魚回來了，碼頭就不像只通往遠方的地方了。'),
            ('reed', '这枚薄片夹在旧网里。编号和皮普常看的日志很像。', 'This plate was caught in an old net. Its number looks like Pip’s logs.', 'この薄片、古い網に挟まっていた。番号はピップの記録に似ている。', '這枚薄片夾在舊網裡。編號和皮普常看的日誌很像。'),
            ('player', '一张网，倒把水边和遗址连在一起了。', 'One old net has joined the water to the ruins.', '一枚の網が、水辺と遺跡をつないだんだね。', '一張網，倒把水邊和遺址連在一起了。'),
            ('yingluo', '不过，有些话得等大家愿意说的时候。', 'Some stories still need someone willing to tell them.', 'でも、話せる日が来るまで待つ物語もあるよ。', '不過，有些話得等大家願意說的時候。'),
        ],
        [
            ('pip', '这把钥匙我藏了很久。不是门打不开，是我不敢再进去。', 'I hid this key for years. The door worked; I was afraid to go back.', 'この鍵、長く隠していた。扉は開く。戻るのが怖かったんだ。', '這把鑰匙我藏了很久。不是門打不開，是我不敢再進去。'),
            ('player', '钥匙在桌上，就不用再由你一个人守着了。', 'On this table, the key is yours to share.', '机の上に置けば、一人で守らなくていいよ。', '鑰匙在桌上，就不用再由你一個人守著了。'),
            ('pip', '嗯。今晚我还坐原来的位置。', 'Right. I’ll take my usual seat tonight.', 'うん。今夜も、いつもの席に座る。', '嗯。今晚我還坐原來的位置。'),
            ('yingluo', '熟悉的座位，比一把钥匙更难得。', 'A familiar seat can mean more than a key.', 'いつもの席は、鍵よりも大事なものかもしれないね。', '熟悉的座位，比一把鑰匙更難得。'),
        ],
        [
            ('pip', '这些编号终于对上了。核心一直催着灯发亮，却没给它们留下休息的时候。', 'The numbers finally match. The core kept urging the lanterns on, leaving them no time to rest.', '番号がようやく合った。核は灯を急かすばかりで、休む時間を残していなかった。', '這些編號終於對上了。核心一直催著燈發亮，卻沒給它們留下休息的時候。'),
            ('ember', '所以那晚整条回路都烧坏了。图纸上漏掉的，不只是一只齿轮。', 'That is why the whole circuit burned. The plans lacked more than a gear.', 'だから、あの夜は回路ごと焼けた。図面に欠けていたのは歯車だけじゃない。', '所以那晚整條迴路都燒壞了。圖紙上漏掉的，不只是一隻齒輪。'),
            ('player', '食堂会关门，也会重新开门。灯应该也有这样的余地。', 'Our eatery closes and opens again. The lanterns deserve that room, too.', '食堂は閉まり、また開く。灯にも、そんな余裕があっていいよね。', '食堂會關門，也會重新開門。燈應該也有這樣的餘地。'),
            ('yingluo', '旧记录还画着一张长桌。它为什么在那里，得继续查下去。', 'There is a shared table in the old record. We still need to learn why.', '古い記録には長机も描かれている。なぜそこにあるのか、まだわからないね。', '舊記錄還畫著一張長桌。它為什麼在那裡，得繼續查下去。'),
        ],
        [
            ('orla', '那封信，我终于敢补上自己的名字了。我怕你看见空桌子就走。', 'I can finally sign that letter. I feared the empty tables would send you away.', 'あの手紙に、ようやく名前を書ける。空の食卓を見て、帰ってしまうのが怖かった。', '那封信，我終於敢補上自己的名字了。我怕你看見空桌子就走。'),
            ('player', '你信里问，今年的晚餐还能有空位吗。现在有了，也有你的位置。', 'You asked if this year’s dinner still had a seat. It does, and one is yours.', '手紙には「今年の夕食に空席はありますか」って。今はあるよ。あなたの席も。', '你信裡問，今年的晚餐還能有空位嗎。現在有了，也有你的位置。'),
            ('yuki', '山上的旧邮戳，和这封信的印记很像。我还带回半个日期。', 'A ridge postmark resembles this letter’s seal. I brought half its date back.', '山の古い消印が、この印に似ていたの。日付の半分も持ち帰った。', '山上的舊郵戳，和這封信的印記很像。我還帶回半個日期。'),
            ('yingluo', '有人回到了桌边，还有一封更早的信等着我们。', 'Someone has returned to the table. An older letter is still waiting.', '食卓に戻ってきた人がいる。そして、もっと古い手紙が待っているね。', '有人回到了桌邊，還有一封更早的信等著我們。'),
        ],
        [
            ('yuki', '日期终于对上了，是月环熄灭的那晚。旧信上写着：别让守灯的人独自留下。', 'The date finally matches the night the ring went dark. The letter says: do not leave the keeper alone.', '日付がようやく合った。月環が消えた夜。「灯守を一人で残さないで」とある。', '日期終於對上了，是月環熄滅的那晚。舊信上寫著：別讓守燈的人獨自留下。'),
            ('aster', '记录只剩一段回声。剩下的空处，画着各个季节的收获。', 'Only one echo remains in the record. The other spaces hold harvests from every season.', '記録には響きが一つだけ。残りの空欄には、季節ごとの収穫が描かれている。', '記錄只剩一段回聲。剩下的空處，畫著各個季節的收穫。'),
            ('player', '这些空格不是一夜就能写满的。我们还要在这里过很多个明天。', 'Those blanks will take more than a night. We have many tomorrows to live here.', '空欄は一晩では埋まらない。ここで、たくさんの明日を過ごすんだね。', '這些空格不是一夜就能寫滿的。我們還要在這裡過很多個明天。'),
            ('yingluo', '手记会留着空白，等每个季节自己的颜色。', 'The journal can wait for each season’s colors.', '手帳は、それぞれの季節の色を待っていられるよ。', '手記會留著空白，等每個季節自己的顏色。'),
        ],
        [
            ('mori', '有些种子等了很久。如今每个季节的颜色都回来了。', 'Some seeds waited a long time. Now every season has returned its color.', '長く待った種もある。今は、季節ごとの色が戻ってきたね。', '有些種子等了很久。如今每個季節的顏色都回來了。'),
            ('aster', '星图对上了。它记的不是一张完美图画，是这些作物真正长大的日子。', 'The chart aligns. It records days when crops truly grew, not a perfect picture.', '星図が合った。完璧な絵じゃない。作物が本当に育った日々の記録なんだ。', '星圖對上了。它記的不是一張完美圖畫，是這些作物真正長大的日子。'),
            ('player', '有雨天，也有忘了浇水的日子。它们都算数。', 'Rainy days, and days we forgot the water. They all count.', '雨の日も、水を忘れた日も。全部、大切な日なんだね。', '有雨天，也有忘了澆水的日子。它們都算數。'),
            ('yingluo', '观星台的门开了。月晶里剩下的回声，终于有了能安放的地方。', 'The observatory is open. The remaining echoes finally have a place to settle.', '天文台の門が開いた。残る響きにも、ようやく居場所ができたね。', '觀星臺的門開了。月晶裡剩下的回聲，終於有了能安放的地方。'),
        ],
        [
            ('aster', '旧记录完整了。那段记忆曾护住山谷，如今却不能再独自支撑所有灯。', 'The record is whole. That memory sheltered the valley, but cannot carry every lantern alone.', '記録が戻った。あの記憶は谷を守った。でも、すべての灯を一人では支えられない。', '舊記錄完整了。那段記憶曾護住山谷，如今卻不能再獨自支撐所有燈。'),
            ('yingluo', '原来长桌是留给活在这里的人。新的记忆，会接住旧日的守护。', 'The table was meant for those living here. New memories can carry that old promise.', '長机は、ここに暮らす人のためだったんだ。新しい記憶が、昔の守りを受け継げる。', '原來長桌是留給活在這裡的人。新的記憶，會接住舊日的守護。'),
            ('player', '那就让今晚的饭，有所有人的位置。', 'Then tonight’s dinner will have room for everyone.', 'それなら今夜の食卓には、皆の席を用意しよう。', '那就讓今晚的飯，有所有人的位置。'),
            ('toma', '宴席的菜名还在旧食谱上。这回，旁边也该写上新名字了。', 'The feast recipes are still in the old book. This time, new names belong beside them.', '宴の料理名は、まだ古い料理帳にある。今度は新しい名前も添えよう。', '宴席的菜名還在舊食譜上。這回，旁邊也該寫上新名字了。'),
        ],
        [
            ('orla', '这次名单上没有空着的位置。你的位置，我也写进去了。', 'There are no empty places on the list this time. Yours is here, too.', '今度の名簿に空欄はない。あなたの席も、ちゃんとある。', '這次名單上沒有空著的位置。你的位置，我也寫進去了。'),
            ('player', '我想给那封信回一句：明年也有空位。', 'My reply to that letter is: there will be a seat next year, too.', '手紙への返事は、こうしたい。「来年も席はあります」。', '我想給那封信回一句：明年也有空位。'),
            ('yingluo', '月环亮了。不是一盏灯撑起整座山谷，是每家都留了一点光。', 'The ring shines. Every home has lent a little light to the valley.', '月環が灯った。一つの灯ではなく、皆の家が少しずつ光を寄せたんだね。', '月環亮了。不是一盞燈撐起整座山谷，是每家都留了一點光。'),
            ('toma', '汤还热着。往后的日子，也在这张桌上慢慢过。', 'The soup is still warm. There are more days to share at this table.', 'スープはまだ温かい。これからの日々も、この机でゆっくり過ごそう。', '湯還熱著。往後的日子，也在這張桌上慢慢過。'),
        ],
    ]
    for index, quest in enumerate(quests):
        quest.update(place=t(*places[index]), briefing=t(*briefings[index]), description=t(*results[index]), dialogue=[line(*record) for record in scenes[index]])

    # Opening film titles and narration are authored with their shots in build_content.py.

    steps = [
        ('prepare', ('晚餐的准备', 'Dinner Preparations', '夕食の支度', '晚餐的準備'), ('加工食材', 'Ingredients prepared', '食材の仕込み', '加工食材'), 3, places[1], ('旧备料台还在。蘑菇、莓果和香草加工后成为基础三道菜的厨房原料。', 'The old prep table remains. Prepared mushrooms, berries and herbs supply the first three dishes.', '古い仕込み台は残っている。キノコ、ベリー、ハーブは、仕込み後に基本三品の材料となる。', '舊備料臺還在。蘑菇、莓果和香草加工後成為基礎三道菜的廚房原料。')),
        ('menu', ('今晚的菜单', 'Tonight’s Menu', '今夜の献立', '今晚的菜單'), ('上架料理', 'Dishes listed', '提供する料理', '上架料理'), 1, places[1], ('擦净的黑板还空着。菜单上的料理，是今晚食堂与客人的约定。', 'The clean menu board is empty. Its dishes will be tonight’s promise to our guests.', 'きれいな黒板はまだ空。献立の料理は、今夜の客との約束になる。', '擦淨的黑板還空著。菜單上的料理，是今晚食堂與客人的約定。')),
        ('first_meal', ('第一只热碗', 'The First Warm Bowl', '最初の温かな器', '第一隻熱碗'), ('成功上菜', 'Meals served', '配膳成功', '成功上菜'), 1, places[1], ('第一位客人的旧碗还空着。一份与订单相符的晚餐，也是一句欢迎回来。', 'The first guest’s bowl is empty. The dinner they ordered is also a welcome home.', '最初の客の器はまだ空。注文どおりの夕食は、「おかえり」の言葉にもなる。', '第一位客人的舊碗還空著。一份與訂單相符的晚餐，也是一句歡迎回來。')),
        ('plant', ('明天的种子', 'Seeds for Tomorrow', '明日の種', '明天的種子'), ('种植地块', 'Plots planted', '種を植えた区画', '種植地塊'), 5, places[2], ('五块田地留给下一次收获。香草适应四季，其他作物各有适合的季节。', 'Five plots can hold the next harvest. Herbs grow in every season; other crops have their own.', '五つの畑で次の収穫を待てる。ハーブは四季に育ち、ほかの作物には合う季節がある。', '五塊田地留給下一次收穫。香草適應四季，其他作物各有適合的季節。')),
        ('water', ('雨水的约定', 'A Promise of Water', '水の約束', '雨水的約定'), ('湿润或已生长地块', 'Watered or growing plots', '水やり済み・生育中の区画', '濕潤或已生長地塊'), 5, places[2], ('湿润的土地让种子在跨日后生长。尚未成熟的作物，可以留在田里等待。', 'Watered soil lets crops grow overnight. Unripe crops can remain in the field and wait.', '湿った土で、作物は翌日に育つ。未熟な作物は、畑で待っていられる。', '濕潤的土地讓種子在跨日後生長。尚未成熟的作物，可以留在田裡等待。')),
    ]
    onboarding = {id: dict(id=id, name=t(*name), objective=t(*objective), goal=goal, place=t(*place), description=t(*description)) for id, name, objective, goal, place, description in steps}
    welcome = [
        ('我叫萤萝，平时看着镇上的月灯，也替大家收着没写完的故事。', 'I’m Yingluo. I tend the moon lanterns and keep the town’s unfinished stories.', '私はインルオ。町の月灯と、まだ終わらない物語を預かっているの。', '我叫螢蘿，平時看著鎮上的月燈，也替大家收著沒寫完的故事。'),
        ('你就是收到信的小女巫吧？这间小屋空了很久，今天总算等到主人了。', 'You must be the witch who received the letter. This house has waited a long time for you.', '手紙を受け取った小さな魔女だね。この家も、長い間あなたを待っていたよ。', '你就是收到信的小女巫吧？這間小屋空了很久，今天總算等到主人了。'),
        ('月环熄灭后，大家渐渐不再等彼此吃饭。是谁寄的信，我也还不知道。', 'After the ring faded, people stopped waiting to share supper. I don’t know who sent the letter either.', '月環が消えてから、皆で夕食を待つこともなくなった。差出人は、私にもわからないの。', '月環熄滅後，大家漸漸不再等彼此吃飯。是誰寄的信，我也還不知道。'),
        ('旧食谱上的星点，和灯座上的刻痕很像。长桌旁边，却没有留下名字。', 'The recipe book’s stars resemble marks on the lanterns. There are no names beside its table.', '料理帳の星は、灯の台座の印に似ている。でも長机のそばに、名前はなかった。', '舊食譜上的星點，和燈座上的刻痕很像。長桌旁邊，卻沒有留下名字。'),
        ('陶陶还留着三只旧碗。也许今晚，终于有人和他一起喝汤了。', 'Toma kept three old bowls. Perhaps tonight he will finally share some soup.', 'トマは古い器を三つ残している。今夜は、誰かとスープを飲めるかもしれないね。', '陶陶還留著三隻舊碗。也許今晚，終於有人和他一起喝湯了。'),
        ('这本手记记着每家的灯。空白还很多，不过你的那一页已经开始了。', 'This journal keeps a lantern for every home. Many pages are blank, but yours has begun.', 'この手帳には、家々の灯が記されている。空白は多いけれど、あなたの頁は始まったよ。', '這本手記記著每家的燈。空白還很多，不過你的那一頁已經開始了。'),
    ]
    topics = [
        (0, ('林间食材', 'Forest Ingredients', '森の食材', '林間食材'), [
            ('林里的蘑菇和莓果还会再长。陶陶记得它们的味道，旧食谱也记得。', 'Mushrooms and berries will grow again. Toma remembers their taste, and so does the old recipe book.', '森にはまたキノコとベリーが育つ。トマも古い料理帳も、その味を覚えている。', '林裡的蘑菇和莓果還會再長。陶陶記得它們的味道，舊食譜也記得。')]),
        (1, ('食堂灯火', 'Kitchen Lights', '食堂の灯', '食堂燈火'), [
            ('旧黑板上有汤名，也有居民留下的小记号。每份订单，都来自一位还愿意赴约的人。', 'The old menu board holds soup names and little marks from residents. Each order means someone still hopes to join us.', '古い黒板にはスープの名と、住民の小さな印がある。注文は、また食卓を囲みたいという願いなんだね。', '舊黑板上有湯名，也有居民留下的小記號。每份訂單，都來自一位還願意赴約的人。')]),
        (2, ('农场四季', 'Farm Seasons', '畑の四季', '農場四季'), [
            ('茉莉说，田里最珍贵的不是一夜长大的奇迹，是第二天仍有人惦记着它。', 'Mori says a field’s greatest treasure is someone who remembers it the next morning.', 'モリは言うの。畑の宝物は、一晩の奇跡よりも、翌朝また気にかける人だって。', '茉莉說，田裡最珍貴的不是一夜長大的奇蹟，是第二天仍有人惦記著它。')]),
        (3, ('小镇建设', 'Building the Town', '町づくり', '小鎮建設'), [
            ('余烬留着每次修补的图纸。他总说，裂缝补上了，人才能放心把故事留在这里。', 'Ember keeps every repair plan. He says mended walls give our stories somewhere to stay.', 'エンバーは修理の図面を残している。ひびが直れば、安心して物語も置いていけるんだって。', '餘燼留著每次修補的圖紙。他總說，裂縫補上了，人才能放心把故事留在這裡。')]),
        (4, ('水边来信', 'Letters by the Water', '水辺の便り', '水邊來信'), [
            ('水里的鱼有自己的时节。芦苇和凪的账本上，天气旁边还记着谁在岸边等过。', 'Fish have their seasons. Reed and Nagi record the weather, and who once waited on the bank.', '魚にも季節がある。リードとナギの帳面には、天気と、岸辺で待っていた人が記されている。', '水裡的魚有自己的時節。蘆葦和凪的帳本上，天氣旁邊還記著誰在岸邊等過。')]),
        (5, ('居民心事', 'Residents’ Stories', '住民の想い', '居民心事'), [
            ('每个人都收着一些没说完的话。熟悉以后，旧物才会慢慢有自己的名字。', 'Everyone keeps a few unfinished words. With friendship, old keepsakes slowly find their names.', '皆、言いかけた言葉を持っている。親しくなると、古い品にも少しずつ名前が戻るんだね。', '每個人都收著一些沒說完的話。熟悉以後，舊物才會慢慢有自己的名字。'),
            ('有的故事要等下一次相逢。手记留得下空白，小镇也等得起。', 'Some stories wait for another meeting. The journal has room for blank pages, and the town has time.', '次に会う日を待つ物語もある。手帳には空白があっていい。町も、待っていられるよ。', '有的故事要等下一次相逢。手記留得下空白，小鎮也等得起。')]),
    ]
    current = [
        ('陶陶把旧菜单压在篮底，像是在等谁回来。', 'Toma keeps the old menu beneath the basket, as if waiting for someone to return.', 'トマは古い献立を籠の底にしまい、誰かの帰りを待っているみたい。', '陶陶把舊菜單壓在籃底，像是在等誰回來。'),
        ('刚才的汤香还在，空了很久的座位也终于有人记得。', 'The soup’s scent still lingers, and someone finally remembers the seats left empty for so long.', 'さっきのスープの香りが残っている。長く空いていた席も、ようやく思い出されたね。', '剛才的湯香還在，空了很久的座位也終於有人記得。'),
        ('茉莉看着田边的新芽，像在和很久以前的春天打招呼。', 'Mori watches the shoots by the field, as if greeting a spring from long ago.', 'モリは畑の芽を見つめ、遠い昔の春に挨拶しているみたい。', '茉莉看著田邊的新芽，像在和很久以前的春天打招呼。'),
        ('余烬把水门图纸摊在炉边，纸角已经被火烤卷了。', 'Ember spreads the sluice plans by the forge, their corners curled by the heat.', 'エンバーは水門の図面を炉辺に広げ、熱でめくれた端を押さえている。', '餘燼把水門圖紙攤在爐邊，紙角已經被火烤捲了。'),
        ('芦苇说水声回来了，码头边的人也开始聊起远方。', 'Reed says the water has returned, and people at the dock have started talking about distant shores.', 'リードは水音が戻ったと言う。桟橋では遠い場所の話も始まった。', '蘆葦說水聲回來了，碼頭邊的人也開始聊起遠方。'),
        ('食堂有人记得彼此常坐的位置，旧事也愿意慢慢说了。', 'People at the eatery remember one another’s usual seats, and old stories are being told again.', '食堂ではいつもの席を覚える人が増え、古い話も少しずつ語られている。', '食堂有人記得彼此常坐的位置，舊事也願意慢慢說了。'),
        ('皮普把遗址的钥匙放到桌上，手却还在口袋边停了好一会儿。', 'Pip leaves the ruins key on the table, though his hand lingers by his pocket for a while.', 'ピップは遺跡の鍵を机に置いた。それでも手はしばらくポケットのそばに残った。', '皮普把遺址的鑰匙放到桌上，手卻還在口袋邊停了好一會兒。'),
        ('长桌添了位置，奥萝终于敢在信上写自己的名字。', 'The long table has room again, and Orla finally dares to sign her letter.', '長机に席が戻り、オルラはようやく手紙に自分の名を書ける。', '長桌添了位置，奧蘿終於敢在信上寫自己的名字。'),
        ('霜铃把旧邮戳放在灯下，纸上的日期像雪一样慢慢显出来。', 'Yuki sets the old postmark beneath the lamp, and the date emerges like snow.', 'ユキは古い消印を灯の下に置く。紙の日付が雪のようにゆっくり現れる。', '霜鈴把舊郵戳放在燈下，紙上的日期像雪一樣慢慢顯出來。'),
        ('星图上的空白映着四季，观星台里有人等着下一次晴夜。', 'The chart’s blank spaces reflect the seasons, and someone at the observatory waits for the next clear night.', '星図の空欄に四季が映り、天文台では次の晴れた夜を待っている。', '星圖上的空白映著四季，觀星臺裡有人等著下一次晴夜。'),
        ('月晶里的回声很轻，得让它们在热闹的人声里找到位置。', 'The echoes in the moon crystals are faint; they need a place among the town’s voices.', '月晶の響きはかすか。町の声の中で居場所を見つける必要がある。', '月晶裡的回聲很輕，得讓它們在熱鬧的人聲裡找到位置。'),
        ('长桌已经摆好，旧食谱旁边留着空白，等今晚的人写下名字。', 'The long table is set. Blank space beside the old recipes waits for tonight’s names.', '長机は整った。古い料理帳のそばの空白が、今夜の名前を待っている。', '長桌已經擺好，舊食譜旁邊留著空白，等今晚的人寫下名字。'),
    ]
    guide = dict(welcome=[t(*record) for record in welcome], chapters=[q['briefing'] for q in quests], current=[t(*record) for record in current],
                 farewell=t('手记写满了。灯还会一直亮，接下来的日子，就和小镇一起过吧。', 'The journal is full. The lanterns will keep shining through all the days you share with this town.', '手帳はいっぱいになった。これから町と過ごす日々にも、灯はずっと輝いているよ。', '手記寫滿了。燈還會一直亮，接下來的日子，就和小鎮一起過吧。'),
                 topics=[dict(chapter=chapter, name=t(*name), lines=[t(*record) for record in records]) for chapter, name, records in topics])
    t('地点：%s', 'Place: %s', '場所：%s', '地點：%s')
    t('这一页的心愿已经实现。', 'This page’s wish has come true.', 'この頁の願いがかなったね。', '這一頁的心願已經實現。')
    t('%s · %d/%d', '%s · %d/%d', '%s・%d/%d', '%s · %d/%d')
    t('回顾', 'Recall', '回想', '回顧')
    return dict(onboarding=onboarding, guide=guide)
