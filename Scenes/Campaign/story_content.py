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
        ("陶陶还留着以前的备料篮和三人份菜单。食堂很久没开火了，厨房还缺新鲜食材。", "Toma kept the old prep basket and a menu for three. The eatery hasn’t cooked in ages, and the kitchen needs fresh ingredients.", "トマは昔の仕込み籠と三人分の献立を残していた。食堂は長く休んでいて、新鮮な食材が足りない。", "陶陶還留著以前的備料籃和三人份菜單。食堂很久沒開火了，廚房還缺新鮮食材。"),
        ("陶陶把三只旧碗擦干净了。食材也有了，大家都在等食堂重新开门后的第一顿晚饭。", "Toma has cleaned the three old bowls. The ingredients are ready, and everyone’s waiting for the eatery’s first dinner in years.", "トマが古い器を三つ洗った。食材もそろい、皆が久しぶりの夕食を楽しみにしている。", "陶陶把三隻舊碗擦乾淨了。食材也有了，大家都在等食堂重新開門後的第一頓晚飯。"),
        ("茉莉留下了一些当季种子。农场的地还能种，往后食堂就能用上自己种的新鲜菜了。", "Mori left some seeds for this season. The farm’s soil is still good, so the eatery could have fresh homegrown vegetables.", "モリが今の季節の種を残してくれた。農場の土はまだ使える。食堂で自分たちの野菜を出せそうだ。", "茉莉留下了一些當季種子。農場的地還能種，往後食堂就能用上自己種的新鮮菜了。"),
        ("旧水门的齿轮缺了一块。余烬有图纸，但修齿轮的矿石还不够，石谷里还有矿。", "A gear in the old sluice is broken. Ember has the plans, but needs more ore to repair it. There’s still ore in the quarry.", "古い水門の歯車が欠けている。エンバーには図面があるが、修理の鉱石が足りない。石谷にはまだ鉱石がある。", "舊水門的齒輪缺了一塊。餘燼有圖紙，但修齒輪的礦石還不夠，石谷裡還有礦。"),
        ("水道又通了，芦苇说鱼也回来了。码头和湿地的鱼群，能看出水道恢复得怎么样。", "The water is flowing again, and Reed says the fish are back. Catches from the dock and marsh will show how the waterways are doing.", "水路が通り、リードによると魚も戻ってきた。桟橋や湿地の釣果で、水路の様子がわかりそうだ。", "水道又通了，蘆葦說魚也回來了。碼頭和濕地的魚群，能看出水道恢復得怎麼樣。"),
        ("食堂的熟客多起来了。大家渐渐熟了，有人开始愿意聊起月环熄灭那晚的事。", "The eatery has regulars again. As people get to know each other, some are ready to talk about the night the moonring went dark.", "食堂に常連が増えてきた。親しくなるうちに、月環が消えた夜のことを話す人も出てきた。", "食堂的熟客多起來了。大家漸漸熟了，有人開始願意聊起月環熄滅那晚的事。"),
        ("皮普拿出了遗址的钥匙。里面的旧零件刻着编号，可能和月环那次事故有关。", "Pip has brought out the ruins key. The numbers on the old parts inside may be connected to the moonring accident.", "ピップが遺跡の鍵を出してくれた。中にある古い部品の番号は、月環の事故と関係があるかもしれない。", "皮普拿出了遺址的鑰匙。裡面的舊零件刻著編號，可能和月環那次事故有關。"),
        ("旧记录里提到了食堂的长桌。现在来吃饭的人越来越多，座位有些不够了。", "The old records mention the eatery’s long table. More people are coming for dinner, and seats are getting scarce.", "古い記録に食堂の長机が出てきた。今も食事に来る人が増えて、席が足りなくなってきた。", "舊記錄裡提到了食堂的長桌。現在來吃飯的人越來越多，座位有些不夠了。"),
        ("霜铃找到了半枚旧邮戳。山径上可能还留着当年的信件，能查出月环熄灭的准确日期。", "Yuki found half an old postmark. Letters along the ridge may give the exact date the moonring went dark.", "ユキが古い消印の半分を見つけた。山道に残る手紙から、月環が消えた正確な日付がわかるかもしれない。", "霜鈴找到了半枚舊郵戳。山徑上可能還留著當年的信件，能查出月環熄滅的準確日期。"),
        ("星图上有十二处空格，分别对应不同的作物。农场的收获记录，正好能补全这张图。", "The chart has twelve blanks, each for a different crop. The farm’s harvest records can fill them in.", "星図には作物に対応する十二の空欄がある。農場の収穫記録があれば、この図を完成できそうだ。", "星圖上有十二處空格，分別對應不同的作物。農場的收穫記錄，正好能補全這張圖。"),
        ("四季星图已经补齐，观星台也开了。月晶里还存着事故当晚的记录，只是缺了几段。", "The seasonal chart is complete and the observatory is open. The crystals hold a record of the accident, but parts are still missing.", "四季の星図が完成し、天文台も開いた。月晶には事故の夜の記録が残っているが、まだ一部が欠けている。", "四季星圖已經補齊，觀星臺也開了。月晶裡還存著事故當晚的記錄，只是缺了幾段。"),
        ("长桌已经摆好。宴席的三道菜是星河宴、四季团圆盘和万家灯火甜点，大家都盼着这顿团圆饭。", "The long table is set. The feast has Star River Banquet, Four Seasons Platter and Lantern Home Dessert. Everyone’s looking forward to eating together.", "長机の準備はできた。宴の料理は星河の宴、四季団らん皿、万家灯火デザート。皆で食べるのを楽しみにしている。", "長桌已經擺好。宴席的三道菜是星河宴、四季團圓盤和萬家燈火甜點，大家都盼著這頓團圓飯。"),
    ]
    results = [
        ("三份新鲜食材备齐了，陶陶也擦好了碗。食堂总算能重新开火了。", "Three fresh ingredients are ready, and Toma has cleaned the bowls. The eatery can finally cook again.", "新鮮な食材が三つそろい、トマも器を洗った。やっと食堂で料理を作れる。", "三份新鮮食材備齊了，陶陶也擦好了碗。食堂總算能重新開火了。"),
        ("三份晚饭端上了桌，外面的月灯短暂亮了一下。茉莉留下当季种子，盼着能吃上农场的新鲜菜。", "Three dinners were served, and the moon lantern outside briefly lit up. Mori left seasonal seeds, looking forward to the farm’s vegetables.", "三つの夕食を出すと、外の月灯が一瞬光った。モリは季節の種を残し、農場の野菜を楽しみにしている。", "三份晚飯端上了桌，外面的月燈短暫亮了一下。茉莉留下當季種子，盼著能吃上農場的新鮮菜。"),
        ("农场收了五份作物。余烬认出田边旧路牌上的水门标记，说修好那里的齿轮就能通水。", "The farm produced five crops. Ember recognized the sluice mark on the old sign. Repairing its gear would restore the water.", "農場で五つ収穫した。エンバーが古い標識の水門の印に気づいた。歯車が直れば水が通るそうだ。", "農場收了五份作物。餘燼認出田邊舊路牌上的水門標記，說修好那裡的齒輪就能通水。"),
        ("矿石够了，余烬也补齐了修水门的图纸。湿地重新有了水声，鱼和候鸟有望回来。", "There’s enough ore, and Ember has completed the sluice plans. Water can be heard in the marsh again. The fish and birds may return.", "鉱石がそろい、エンバーも水門の図面を完成させた。湿地に水音が戻り、魚や渡り鳥も戻ってきそうだ。", "礦石夠了，餘燼也補齊了修水門的圖紙。濕地重新有了水聲，魚和候鳥有望回來。"),
        ("五次鱼获说明鱼群回来了。芦苇还在旧网里发现一块薄片，上面的编号和皮普的日志很像。", "Five catches show the fish are back. Reed also found a plate in an old net, with a number like those in Pip’s logbook.", "五度の釣果で魚が戻ったことがわかった。リードは古い網から、ピップの記録に似た番号の薄片も見つけた。", "五次魚獲說明魚群回來了。蘆葦還在舊網裡發現一塊薄片，上面的編號和皮普的日誌很像。"),
        ("皮普终于说出自己不敢回遗址的事，把钥匙交给了大家。这次，他不用再独自面对了。", "Pip finally admitted he was afraid to return to the ruins and shared the key. This time, he won’t have to face it alone.", "ピップは遺跡に戻るのが怖かったと打ち明け、鍵を皆に預けた。今度は一人で向き合わなくていい。", "皮普終於說出自己不敢回遺址的事，把鑰匙交給了大家。這次，他不用再獨自面對了。"),
        ("八份零件的编号对上了旧记录。核心曾连着所有月灯，因为一直不停机，最终烧坏了回路。", "Eight part numbers matched the old records. The core linked all the moon lanterns, but running without stopping burned out the circuit.", "八つの部品番号が記録と合った。核は月灯をすべてつないでいたが、動き続けて回路を焼いてしまった。", "八份零件的編號對上了舊記錄。核心曾連著所有月燈，因為一直不停機，最終燒壞了迴路。"),
        ("食堂添了座位，奥萝也承认匿名信是她写的。霜铃从山上的旧邮袋里找到半枚邮戳，日期还不完整。", "The eatery has more seats. Orla admitted writing the unsigned letter. Yuki found half a postmark up the mountain, but the date is incomplete.", "食堂の席が増え、オルラは匿名の手紙を書いたと打ち明けた。ユキは山で消印の半分を見つけたが、日付は欠けている。", "食堂添了座位，奧蘿也承認匿名信是她寫的。霜鈴從山上的舊郵袋裡找到半枚郵戳，日期還不完整。"),
        ("六次山径调查查清了旧信的日期，正是月环熄灭那晚。星芒也认出星图的空格对应不同作物的收获记录。", "Six ridge finds confirmed the date: the night the moonring went dark. Aster identified the chart’s blanks as crop harvest records.", "六度の山道調査で、手紙の日付が月環の消えた夜とわかった。アスターは星図の空欄が収穫記録だと気づいた。", "六次山徑調查查清了舊信的日期，正是月環熄滅那晚。星芒也認出星圖的空格對應不同作物的收穫記錄。"),
        ("十二种作物的收获记录补全了四季星图，观星台的门打开了。那里的设备能读出月晶保存的记录。", "Records of twelve crop harvests completed the chart and opened the observatory. Its equipment can read the records stored in moon crystals.", "十二種の作物の収穫記録で四季の星図が完成し、天文台が開いた。中の装置なら月晶の記録を読める。", "十二種作物的收穫記錄補全了四季星圖，觀星臺的門打開了。那裡的設備能讀出月晶保存的記錄。"),
        ("八枚月晶补齐了旧记录。原来月环靠共同生活的记忆发光，大家一起过日子，就能给它补上新的力量。", "Eight crystals completed the record. The moonring runs on shared memories. Living together can give it fresh energy.", "八つの月晶で記録がそろった。月環は共に暮らした記憶で光る。皆の日々が、新しい力になる。", "八枚月晶補齊了舊記錄。原來月環靠共同生活的記憶發光，大家一起過日子，就能給它補上新的力量。"),
        ("三道宴席菜上了桌，大家又聚到一起，月环终于重新亮了。小女巫也有了自己的家和一起吃饭的人。", "The three feast dishes were served, everyone gathered, and the moonring shone again. The little witch now has a home and people to share dinner with.", "宴の三品が並び、皆が集まると、月環がまた光った。小さな魔女にも、家と一緒に食事する人たちができた。", "三道宴席菜上了桌，大家又聚到一起，月環終於重新亮了。小女巫也有了自己的家和一起吃飯的人。"),
    ]
    scenes = [
        [
            ('toma', "这篮子可算装上东西了。我留了这么久，还以为食堂真不开了。", "Good to see this basket full again. I kept it all this time, but thought the eatery might never reopen.", "やっと籠に食材が入ったな。ずっと残していたけど、もう食堂は開かないかと思ったよ。", "這籃子可算裝上東西了。我留了這麼久，還以為食堂真不開了。"),
            ('player', "食材够了，今晚能做饭了。那三只碗里，也有你的一份。", "We’ve got enough to cook dinner tonight. And one of those three bowls is yours.", "これで今夜のご飯は作れるね。三つの器のうち、一つはあなたの分だよ。", "食材夠了，今晚能做飯了。那三隻碗裡，也有你的一份。"),
            ('toma', "还有我的？……好，那我把旧菜单拿出来，看看以前都做些什么。", "One for me too? All right. I’ll get the old menu out and see what we used to make.", "私の分も？ ……そうか。じゃあ昔の献立を出そう。何を作っていたか、見てみるよ。", "還有我的？……好，那我把舊菜單拿出來，看看以前都做些什麼。"),
            ('yingluo', "太好了，食堂总算又能开火了。陶陶刚才还担心今晚吃不上呢。", "Great, we can finally get the stove going again. Toma was worried there’d be no dinner tonight.", "よかった、やっと食堂の火をつけられるね。トマ、今夜はご飯がないかもって心配してたんだ。", "太好了，食堂總算又能開火了。陶陶剛才還擔心今晚吃不上呢。"),
        ],
        [
            ('mori', "这汤真好喝。以前大家吃完都说改天再来，后来食堂一关，就再也没聚过了。", "This soup’s lovely. We used to say we’d come back soon. Then the eatery closed, and we never got together again.", "おいしいスープ。昔は皆、また来るねって言ってたのに、食堂が閉まってから集まらなくなっちゃった。", "這湯真好喝。以前大家吃完都說改天再來，後來食堂一關，就再也沒聚過了。"),
            ('player', "我还打算继续开呢。农场的地也不能一直空着，我想种点菜，往后做饭用。", "I’m planning to keep it open. I’d like to grow some vegetables on the farm for the kitchen, too.", "私はこれからも開けるつもりだよ。農場で野菜も育てたいな。料理に使えるし。", "我還打算繼續開呢。農場的地也不能一直空著，我想種點菜，往後做飯用。"),
            ('mori', "那太好了！我留下的都是当季种子。我可等着尝尝你种的菜了。", "That sounds great! The seeds I left are right for this season. I can’t wait to taste what you grow.", "いいね！ 置いておいたのは今の季節の種だよ。あなたの野菜、楽しみにしてる。", "那太好了！我留下的都是當季種子。我可等著嚐嚐你種的菜了。"),
            ('yingluo', "你们看见了吗？外面那盏月灯刚才亮了一下！好久没这样了。", "Did you see that? The moon lantern outside just flickered! It hasn’t done that in ages.", "見えた？ 外の月灯が今、一瞬光ったよ！ こんなの、久しぶり。", "你們看見了嗎？外面那盞月燈剛才亮了一下！好久沒這樣了。"),
        ],
        [
            ('mori', "真长出来了！这地荒了这么久，我还担心种不活呢。", "They really grew! The field was empty for so long, I worried nothing would take.", "ちゃんと育ったね！ ずっと荒れてたから、育たないんじゃないかって心配してたの。", "真長出來了！這地荒了這麼久，我還擔心種不活呢。"),
            ('ember', "田边那块旧路牌我认得，上面画的是水门。那儿的齿轮还坏着，修好就能通水。", "I recognize that old field sign. It marks the sluice. Its gear’s still broken; fixing it would get the water flowing.", "畑の古い標識、見覚えがある。水門の印だ。あそこの歯車を直せば、水が通る。", "田邊那塊舊路牌我認得，上面畫的是水門。那兒的齒輪還壞著，修好就能通水。"),
            ('player', "原来那是水门的标记。现在有了新鲜菜，要是鱼也能回来，菜单就更丰富了。", "So that’s what the mark means. We’ve got fresh vegetables now. If the fish came back too, we’d have more for the menu.", "あれ、水門の印だったんだ。新鮮な野菜はあるし、魚も戻れば料理の種類を増やせるね。", "原來那是水門的標記。現在有了新鮮菜，要是魚也能回來，菜單就更豐富了。"),
            ('yingluo', "余烬手里还有水门的图纸。他惦记这事挺久了，一直缺修理用的矿石。", "Ember still has the sluice plans. He’s wanted to fix it for ages, but hasn’t had enough ore.", "エンバー、水門の図面をまだ持ってるよ。ずっと直したかったけど、鉱石が足りなかったんだって。", "餘燼手裡還有水門的圖紙。他惦記這事挺久了，一直缺修理用的礦石。"),
        ],
        [
            ('ember', "矿石够了，图纸也补齐了。这回我有把握修好那只齿轮。", "That’s enough ore, and the plans are complete. I’m sure I can fix that gear now.", "鉱石は足りた。図面もそろった。これなら、あの歯車を直せる。", "礦石夠了，圖紙也補齊了。這回我有把握修好那隻齒輪。"),
            ('reed', "莲塘那边已经有水声了。水流稳下来，鱼和候鸟应该都会回来。", "I can hear water at the lotus pond already. Once the flow settles, the fish and birds should come back.", "蓮池からもう水音がするよ。流れが落ち着けば、魚も渡り鳥も戻ってきそうだ。", "蓮塘那邊已經有水聲了。水流穩下來，魚和候鳥應該都會回來。"),
            ('player', "那太好了。往后除了菜汤，食堂也能做鱼汤了。", "That’s good news. We’ll be able to serve fish soup as well as vegetable soup.", "よかった。これからは野菜スープだけじゃなく、魚のスープも作れるね。", "那太好了。往後除了菜湯，食堂也能做魚湯了。"),
            ('yingluo', "月灯底座又亮了一小段，和上次一样。水道修好了，灯也有反应，难道有关系？", "Another little part of the lantern base lit up, like last time. The water’s back and the lantern reacted. Could they be connected?", "灯の台座がまた少し光った。前と同じだ。水路が直ったことと、何か関係あるのかな？", "月燈底座又亮了一小段，和上次一樣。水道修好了，燈也有反應，難道有關係？"),
        ],
        [
            ('nagi', "鱼真的回来了！这阵子码头总算热闹点了，我都好久没见人围着鱼篓聊天了。", "The fish really are back! The dock’s livelier lately. It’s been ages since people gathered around a catch to chat.", "本当に魚が戻った！ 最近、桟橋もにぎやかになったよ。魚籠を囲んで皆が話すの、久しぶりだな。", "魚真的回來了！這陣子碼頭總算熱鬧點了，我都好久沒見人圍著魚簍聊天了。"),
            ('reed', "我还在旧网里找到这块薄片。上面的编号，跟皮普那本日志里的很像。", "I also found this plate in an old net. The number looks like the ones in Pip’s logbook.", "古い網にこんな薄い板も引っかかっていたよ。この番号、ピップの記録帳で見たものに似てる。", "我還在舊網裡找到這塊薄片。上面的編號，跟皮普那本日誌裡的很像。"),
            ('player', "那它可能是遗址里的零件？皮普应该认得吧。", "Could it be a part from the ruins? Pip might recognize it.", "じゃあ、遺跡の部品かもしれないね。ピップならわかるかな。", "那它可能是遺址裡的零件？皮普應該認得吧。"),
            ('yingluo', "有可能。不过他一提遗址就紧张，大概还有什么事没告诉我们。", "Maybe. But he gets nervous whenever the ruins come up. There’s probably something he hasn’t told us.", "そうかも。でも遺跡の話になると、ピップは緊張するの。まだ話していないことがあるんだと思う。", "有可能。不過他一提遺址就緊張，大概還有什麼事沒告訴我們。"),
        ],
        [
            ('pip', "遗址的钥匙其实一直在我这儿。门能开，是我自己不敢再进去。", "I’ve had the ruins key all along. The door opens. I’m the one who’s been afraid to go back.", "遺跡の鍵、実はずっと僕が持ってた。扉は開くんだ。僕が戻るのを怖がってただけで。", "遺址的鑰匙其實一直在我這兒。門能開，是我自己不敢再進去。"),
            ('player', "没关系，这次有我们陪你。你不用一个人面对那些事。", "It’s all right. We’re here with you this time. You don’t have to face it alone.", "大丈夫。今度は私たちもいるから。一人で向き合わなくていいよ。", "沒關係，這次有我們陪你。你不用一個人面對那些事。"),
            ('pip', "嗯……那钥匙就放桌上了。今晚我还是坐老位置，饭可别少了我的。", "Okay… I’ll leave the key on the table. I’m still taking my usual seat tonight. Save me some dinner.", "うん……じゃあ鍵は机に置いとく。今夜もいつもの席に座るから、僕のご飯も忘れないでね。", "嗯……那鑰匙就放桌上了。今晚我還是坐老位置，飯可別少了我的。"),
            ('yingluo', "当然有你的。你能把这事说出来，我也松了口气。", "Of course we will. I’m glad you could tell us. I feel better too.", "もちろんあるよ。話してくれて、私もほっとした。", "當然有你的。你能把這事說出來，我也鬆了口氣。"),
        ],
        [
            ('pip', "编号全对上了。原来这台核心把所有灯接在一起，一直不停地转，最后把回路烧坏了。", "The numbers match. This core linked all the lanterns together. It ran without stopping until the circuit burned out.", "番号が全部合った。この核が全部の灯をつないでたんだ。動き続けたせいで、最後に回路が焼けた。", "編號全對上了。原來這臺核心把所有燈接在一起，一直不停地轉，最後把迴路燒壞了。"),
            ('ember', "所以光补齿轮没用，回路也得改。图纸上居然没画停机的装置。", "So replacing a gear won’t be enough. The circuit needs work too. These plans don’t even have a shutoff.", "歯車だけ直してもだめだ。回路も変えないと。図面には停止装置すら描いてない。", "所以光補齒輪沒用，迴路也得改。圖紙上居然沒畫停機的裝置。"),
            ('player', "食堂也不能一直营业，人总得歇歇。机器该停的时候，也得能停下来。", "We can’t keep the eatery open all the time either. People need rest. Machines need to be able to stop too.", "食堂だってずっとは開けられないよね。人も休むし、機械にも止まれる仕組みがいるんだ。", "食堂也不能一直營業，人總得歇歇。機器該停的時候，也得能停下來。"),
            ('yingluo', "记录里还提到了食堂的长桌。不过这部分没写全，还不知道它和月环有什么关系。", "The records mention the eatery’s long table too. That part’s incomplete, so we still don’t know how it connects to the moonring.", "記録には食堂の長机も出てくる。でもそこは欠けていて、月環との関係はまだわからないね。", "記錄裡還提到了食堂的長桌。不過這部分沒寫全，還不知道它和月環有什麼關係。"),
        ],
        [
            ('orla', "我得告诉你一件事。那封没署名的信，是我写的。我怕你知道镇上这么困难，就不肯来了。", "I need to tell you something. I wrote that unsigned letter. I was afraid you wouldn’t come if you knew how badly the town was doing.", "話さなきゃいけないことがあるの。あの匿名の手紙は私が書いた。町の苦しい暮らしを知ったら、来てくれないと思って。", "我得告訴你一件事。那封沒署名的信，是我寫的。我怕你知道鎮上這麼困難，就不肯來了。"),
            ('player', "原来是你啊。你信里不是问能不能一起吃饭吗？现在当然能，你的位子也留着呢。", "So it was you. You asked if we could have dinner together, right? Of course we can. There’s a place for you too.", "あなただったんだ。一緒にご飯を食べられるかって書いてたよね。もちろん。あなたの席もあるよ。", "原來是你啊。你信裡不是問能不能一起吃飯嗎？現在當然能，你的位子也留著呢。"),
            ('yuki', "说起信，我在山上的旧邮袋里找到半枚邮戳。看着跟当年那场事故有关，日期却看不全。", "Speaking of letters, I found half a postmark in an old mailbag up the mountain. It seems tied to the accident, but I can’t read the whole date.", "手紙といえば、山の古い郵袋に消印の半分があったの。あの事故と関係がありそうだけど、日付が全部読めなくて。", "說起信，我在山上的舊郵袋裡找到半枚郵戳。看著跟當年那場事故有關，日期卻看不全。"),
            ('yingluo', "奥萝，这下不用藏着了。食堂能重新开起来，也有你的一份功劳。", "Orla, you don’t have to hide it anymore. You helped bring this eatery back too.", "オルラ、もう隠さなくていいよ。食堂がまた開いたのは、あなたのおかげでもあるんだから。", "奧蘿，這下不用藏著了。食堂能重新開起來，也有你的一份功勞。"),
        ],
        [
            ('yuki', "日期查清楚了，就是月环熄灭那晚。守灯人的记录里还写着，月环里存着最后一段记忆。", "We’ve got the date: the night the moonring went dark. The lantern keeper’s notes also say one last memory is stored in it.", "日付がわかった。月環が消えた夜だよ。灯守の記録には、最後の記憶が月環に残っているとも書いてある。", "日期查清楚了，就是月環熄滅那晚。守燈人的記錄裡還寫著，月環裡存著最後一段記憶。"),
            ('aster', "和我的记录对上了。星图上那些空格，对应的是作物的收获记录，不是星星的位置。", "That matches my notes. Those blanks on the chart are for crop harvests, not star positions.", "私の記録とも合った。星図の空欄は、星の位置じゃない。作物の収穫記録に対応しているんだ。", "和我的記錄對上了。星圖上那些空格，對應的是作物的收穫記錄，不是星星的位置。"),
            ('player', "原来是这样。不同季节长的菜不一样，难怪这图一时半会儿填不满。", "So that’s it. Different crops grow in different seasons. No wonder we couldn’t fill it all at once.", "そういうことか。季節ごとに育つ野菜が違うものね。一度に埋まらないわけだ。", "原來是這樣。不同季節長的菜不一樣，難怪這圖一時半會兒填不滿。"),
            ('yingluo', "不着急。农场已经种起来了，收过哪些作物，手记里也都有记录。", "There’s no rush. The farm’s growing again, and the journal already lists what we’ve harvested.", "急がなくていいよ。農場はもう動いてるし、収穫した作物も手帳に記録してあるから。", "不著急。農場已經種起來了，收過哪些作物，手記裡也都有記錄。"),
        ],
        [
            ('mori', "十二种都齐了！看着这些收获记录，才发现咱们已经种了这么多东西。", "All twelve! Looking at these harvest records, I hadn’t realized how much we’d grown.", "十二種類、そろったね！ 記録を見ると、こんなにいろんなものを育てたんだなって思うよ。", "十二種都齊了！看著這些收穫記錄，才發現咱們已經種了這麼多東西。"),
            ('aster', "星图终于对上了。它记录的是作物长大的日子，所以得有实际的收获才行。", "The chart finally lines up. It records when the crops grew, so it needed real harvests.", "星図がやっと合った。作物が育った日々を記録する図だから、実際の収穫が必要だったんだ。", "星圖終於對上了。它記錄的是作物長大的日子，所以得有實際的收穫才行。"),
            ('player', "这下明白了。难怪光对着图猜，怎么都猜不出来。", "Now it makes sense. No wonder staring at the chart got us nowhere.", "やっとわかったよ。図だけ見て考えても、解けないはずだね。", "這下明白了。難怪光對著圖猜，怎麼都猜不出來。"),
            ('yingluo', "观星台的门也开了！里面能读出月晶的记录，应该能弄清那晚到底出了什么事。", "The observatory’s open too! We can read the crystals there. Maybe now we’ll find out what happened that night.", "天文台の門も開いたよ！ 中では月晶の記録を読めるから、あの夜のこともわかるはず。", "觀星臺的門也開了！裡面能讀出月晶的記錄，應該能弄清那晚到底出了什麼事。"),
        ],
        [
            ('aster', "记录补齐了。月环靠大家一起生活的记忆发光。以前留下的记忆撑到现在，已经不够用了。", "The record’s complete. The moonring runs on memories of people living together. The old memories have kept it going, but they aren’t enough anymore.", "記録がそろった。月環は皆で暮らした記憶で光るんだ。昔の記憶で今まで支えたけど、もうそれだけでは足りない。", "記錄補齊了。月環靠大家一起生活的記憶發光。以前留下的記憶撐到現在，已經不夠用了。"),
            ('yingluo', "所以记录里才会有那张长桌！大家一起吃饭，就能留下新的记忆，月环也能重新亮起来。", "That’s why the long table was in the records! Eating together makes new memories. Those can light the moonring again.", "だから長机が記録に出てきたんだ！ 皆でご飯を食べれば新しい記憶ができて、月環もまた光るんだね。", "所以記錄裡才會有那張長桌！大家一起吃飯，就能留下新的記憶，月環也能重新亮起來。"),
            ('player', "那今晚就热闹一点，大家一起吃。忙了这么久，也该好好聚一顿了。", "Then let’s have everyone over tonight. We’ve all been busy. It’s time for a proper meal together.", "じゃあ今夜は皆でにぎやかに食べよう。ずっと忙しかったし、ゆっくり集まってご飯にしたいね。", "那今晚就熱鬧一點，大家一起吃。忙了這麼久，也該好好聚一頓了。"),
            ('toma', "旧食谱里那三道宴席菜，正好派上用场。我也好久没做这么一大桌饭了。", "Those three feast recipes in the old book will be just right. I haven’t cooked for a crowd like this in ages.", "古い料理帳の宴料理三品が、ちょうどいいな。こんな大勢のご飯を作るのは久しぶりだよ。", "舊食譜裡那三道宴席菜，正好派上用場。我也好久沒做這麼一大桌飯了。"),
        ],
        [
            ('orla', "人都到齐了。我把你的位子也算上了，忙完这一阵，咱们就一起吃。", "Everyone’s here. I’ve counted a seat for you too. Once this is ready, we’ll all eat together.", "皆そろったよ。あなたの席も入れてある。支度が済んだら、一緒に食べようね。", "人都到齊了。我把你的位子也算上了，忙完這一陣，咱們就一起吃。"),
            ('player', "那封信的回话，我想好了：今年一起吃，明年也一起吃。", "I’ve thought of my reply to that letter: dinner together this year, and next year too.", "あの手紙の返事、決めたよ。今年も一緒に食べよう。来年もね。", "那封信的回話，我想好了：今年一起吃，明年也一起吃。"),
            ('yingluo', "亮了！月环真的亮了！咱们一起忙的这些日子，真的有用了。", "It’s shining! The moonring’s really shining! All that time we spent working together made a difference.", "光った！ 本当に月環が光ったよ！ 皆で頑張ってきた日々が、ちゃんと役に立ったんだね。", "亮了！月環真的亮了！咱們一起忙的這些日子，真的有用了。"),
            ('toma', "好啦，汤还热着呢。今天这顿饭，我可要多喝两碗。", "Well, the soup’s still hot. I’m having seconds tonight.", "さあ、スープはまだ温かいよ。今日はおかわりするつもりだ。", "好啦，湯還熱著呢。今天這頓飯，我可要多喝兩碗。"),
        ],
    ]
    for index, quest in enumerate(quests):
        quest.update(place=t(*places[index]), briefing=t(*briefings[index]), description=t(*results[index]), dialogue=[line(*record) for record in scenes[index]])

    # Opening film titles and narration are authored with their shots in build_content.py.

    steps = [
        ('prepare', ('晚餐的准备', 'Dinner Preparations', '夕食の支度', '晚餐的準備'), ('加工食材', 'Ingredients prepared', '食材の仕込み', '加工食材'), 3, places[1], ("厨房的基础原料是加工好的蘑菇、莓果和香草，最早的三道菜都用得上。", "Prepared mushrooms, berries and herbs are the kitchen’s basic ingredients. The first three dishes use them.", "仕込み済みのキノコ、ベリー、ハーブが厨房の基本材料。最初の三品で使われる。", "廚房的基礎原料是加工好的蘑菇、莓果和香草，最早的三道菜都用得上。")),
        ('menu', ('今晚的菜单', 'Tonight’s Menu', '今夜の献立', '今晚的菜單'), ('上架料理', 'Dishes listed', '提供する料理', '上架料理'), 1, places[1], ("菜单黑板还是空的，今晚供应什么菜还没定。", "The menu board is still empty. Tonight’s dishes haven’t been decided yet.", "献立の黒板はまだ空。今夜の料理はまだ決まっていない。", "菜單黑板還是空的，今晚供應什麼菜還沒定。")),
        ('first_meal', ('第一只热碗', 'The First Warm Bowl', '最初の温かな器', '第一隻熱碗'), ('成功上菜', 'Meals served', '配膳成功', '成功上菜'), 1, places[1], ("第一位客人已经点了菜，正等着开饭。", "The first guest has ordered and is waiting for dinner.", "最初のお客さんは注文を済ませて、ご飯を待っている。", "第一位客人已經點了菜，正等著開飯。")),
        ('plant', ('明天的种子', 'Seeds for Tomorrow', '明日の種', '明天的種子'), ('种植地块', 'Plots planted', '種を植えた区画', '種植地塊'), 5, places[2], ("农场有五块田等着种新作物。香草四季都能长，其他作物有各自适合的季节。", "Five farm plots are waiting for new crops. Herbs grow in every season; other crops have their own seasons.", "農場には新しい作物を待つ畑が五区画ある。ハーブは四季に育つが、ほかの作物には合う季節がある。", "農場有五塊田等著種新作物。香草四季都能長，其他作物有各自適合的季節。")),
        ('water', ("田里的水", "Water for the Field", "畑の水", "田裡的水"), ('湿润或已生长地块', 'Watered or growing plots', '水やり済み・生育中の区画', '濕潤或已生長地塊'), 5, places[2], ("土是湿的，作物第二天才会长。还没成熟的作物会留在田里。", "Crops grow the next day if the soil is wet. Unripe crops stay in the field.", "土が湿っていると作物は翌日に育つ。未熟な作物はそのまま畑に残る。", "土是濕的，作物第二天才會長。還沒成熟的作物會留在田裡。")),
    ]
    onboarding = {id: dict(id=id, name=t(*name), objective=t(*objective), goal=goal, place=t(*place), description=t(*description)) for id, name, objective, goal, place, description in steps}
    welcome = [
        ("我叫萤萝，是镇上的巡灯员，平时负责照看月灯。", "I’m Yingluo, the town’s lantern keeper. I look after the moon lanterns.", "私はインルオ。町の灯守で、月灯の手入れをしているの。", "我叫螢蘿，是鎮上的巡燈員，平時負責照看月燈。"),
        ("你就是收到信的小女巫吧？这间屋子一直空着，这下总算有人住了。", "You’re the witch who got that letter, right? This cottage has been empty for ages. It’s good to have someone here.", "手紙を受け取った魔女さんだよね？ ここ、ずっと空き家だったの。住む人が来てくれてよかった。", "你就是收到信的小女巫吧？這間屋子一直空著，這下總算有人住了。"),
        ("月环不亮以后，镇上就越来越冷清了，食堂也关了门。那封信是谁寄的，我也不知道。", "After the moonring went dark, the town got quieter and the eatery closed. I don’t know who sent your letter either.", "月環が消えてから町はだんだん寂しくなって、食堂も閉まったの。手紙の差出人は、私も知らないんだ。", "月環不亮以後，鎮上就越來越冷清了，食堂也關了門。那封信是誰寄的，我也不知道。"),
        ("咦，你这本旧食谱上也画着星星？灯座上有差不多的图案，我还没弄明白是什么意思。", "Oh, your recipe book has stars drawn in it too? The lantern bases have similar marks. I haven’t worked out what they mean.", "あれ、その料理帳にも星の絵があるんだ。灯の台座にも似た印があるの。意味はまだわからなくて。", "咦，你這本舊食譜上也畫著星星？燈座上有差不多的圖案，我還沒弄明白是什麼意思。"),
        ("陶陶听说食堂要重新开门，还留着那三只旧碗。他挺盼着能再和大家一起喝碗汤的。", "Toma heard the eatery might reopen. He’s kept those three old bowls. He’d love to share some soup with everyone again.", "トマは食堂がまた開くかもって聞いて、古い器を三つ残してあるの。皆とまたスープを飲みたいんだって。", "陶陶聽說食堂要重新開門，還留著那三隻舊碗。他挺盼著能再和大家一起喝碗湯的。"),
        ("这本手记给你。镇上的人和最近发生的事，都记在里面了。欢迎来哗啦啦！", "This journal’s for you. It has notes about the residents and what’s been happening lately. Welcome to Walala!", "この手帳、どうぞ。町の人のことや、最近あったことが書いてあるよ。ワララへようこそ！", "這本手記給你。鎮上的人和最近發生的事，都記在裡面了。歡迎來嘩啦啦！"),
    ]
    topics = [
        (0, ('林间食材', 'Forest Ingredients', '森の食材', '林間食材'), [
            ("林里有蘑菇，也有莓果。以前食堂常用这些，陶陶一说起来就停不下来。", "There are mushrooms and berries in the woods. The eatery used them a lot. Toma could talk about those dishes all day.", "森にはキノコもベリーもあるよ。昔の食堂でよく使ってたんだって。トマ、その話だと止まらないの。", "林裡有蘑菇，也有莓果。以前食堂常用這些，陶陶一說起來就停不下來。")]),
        (1, ('食堂灯火', 'Kitchen Lights', '食堂の灯', '食堂燈火'), [
            ("以前食堂一到饭点就坐满了，大家连谁爱喝什么汤都记得。我还挺想念那时候的。", "The eatery used to fill up at dinnertime. Everyone knew each other’s favorite soup. I miss those days.", "昔はご飯の時間になると食堂がいっぱいで、誰が何のスープを好きかも皆知ってたの。懐かしいな。", "以前食堂一到飯點就坐滿了，大家連誰愛喝什麼湯都記得。我還挺想念那時候的。")]),
        (2, ('农场四季', 'Farm Seasons', '畑の四季', '農場四季'), [
            ("茉莉最放心不下那片田。哪怕只有几棵苗，她也会记着今天长高了没有。", "Mori’s always thinking about that field. Even with just a few seedlings, she notices whether they’ve grown.", "モリはあの畑が気になるんだって。苗が数本だけでも、今日は伸びたかなって覚えてるの。", "茉莉最放心不下那片田。哪怕只有幾棵苗，她也會記著今天長高了沒有。")]),
        (3, ('小镇建设', 'Building the Town', '町づくり', '小鎮建設'), [
            ("余烬修过的东西都有图纸留底。以后再出毛病，就不用从头琢磨了。他做事挺仔细的。", "Ember keeps plans for everything he repairs. If something breaks again, he won’t have to start from scratch. He’s thorough like that.", "エンバーは修理したものの図面を残してるよ。また壊れても、一から調べずに済むんだって。まめだよね。", "餘燼修過的東西都有圖紙留底。以後再出毛病，就不用從頭琢磨了。他做事挺仔細的。")]),
        (4, ('水边来信', 'Letters by the Water', '水辺の便り', '水邊來信'), [
            ("芦苇和澪都记着什么时候能见到什么鱼。两人的本子一对，连那天谁在岸边聊天都想起来了。", "Reed and Nagi both keep notes on which fish appear when. Comparing their notebooks even reminds them who was chatting on the bank.", "リードもナギも、いつどんな魚がいたか書いてるの。帳面を見比べると、その日岸で話してた人まで思い出すんだって。", "蘆葦和澪都記著什麼時候能見到什麼魚。兩人的本子一對，連那天誰在岸邊聊天都想起來了。")]),
        (5, ('居民心事', 'Residents’ Stories', '住民の想い', '居民心事'), [
            ("大家都有不太愿意提的事。现在熟一些了，有人总算愿意说说以前发生了什么。", "Everyone has things they find hard to talk about. Now that we’re closer, some people are ready to tell us what happened.", "皆、話しづらいこともあるよね。少し親しくなって、昔のことを話してくれる人も出てきたの。", "大家都有不太願意提的事。現在熟一些了，有人總算願意說說以前發生了什麼。"),
            ("没说完也没关系，下次还会见面的。有些事隔一阵再聊，反而容易开口。", "It’s all right to leave some things for next time. We’ll see each other again. A little time can make talking easier.", "全部話せなくても、また会えるから大丈夫。少し時間を置いたほうが、話しやすくなることもあるしね。", "沒說完也沒關係，下次還會見面的。有些事隔一陣再聊，反而容易開口。")]),
    ]
    current = [
        ("陶陶还留着以前的菜单和备料篮。他嘴上不说，其实挺盼着食堂重新开门的。", "Toma kept the old menu and prep basket. He won’t say it, but he’s really hoping the eatery will reopen.", "トマは昔の献立と仕込み籠を残してるの。口には出さないけど、食堂の再開を楽しみにしてるんだよ。", "陶陶還留著以前的菜單和備料籃。他嘴上不說，其實挺盼著食堂重新開門的。"),
        ("陶陶把碗都擦好了，食材也齐了。大家都在等今晚这顿饭呢。", "Toma’s cleaned the bowls, and we have the ingredients. Everyone’s looking forward to dinner tonight.", "トマが器を洗って、食材もそろったよ。皆、今夜のご飯を楽しみにしてる。", "陶陶把碗都擦好了，食材也齊了。大家都在等今晚這頓飯呢。"),
        ("茉莉这几天总在看农场。那地荒了太久，她担心种子种不活。", "Mori keeps checking on the farm. The field was empty for so long, she’s worried the seeds won’t grow.", "モリ、このところ農場を気にしてるの。長く荒れてたから、種が育つか心配なんだって。", "茉莉這幾天總在看農場。那地荒了太久，她擔心種子種不活。"),
        ("余烬正在研究水门的图纸。齿轮坏了，修好以后湿地才能通水。", "Ember’s studying the sluice plans. The gear’s broken. Once it’s fixed, water can reach the marsh again.", "エンバーが水門の図面を調べてるよ。歯車が直れば、湿地に水が通るんだって。", "餘燼正在研究水門的圖紙。齒輪壞了，修好以後濕地才能通水。"),
        ("芦苇说水道通了，鱼也开始回来了。码头这几天比以前热闹多了。", "Reed says the water’s flowing and the fish are coming back. The dock’s much livelier these days.", "リードによると、水路が通って魚も戻り始めたんだって。最近、桟橋がにぎやかだよ。", "蘆葦說水道通了，魚也開始回來了。碼頭這幾天比以前熱鬧多了。"),
        ("熟客多了，大家也比以前熟了。不过皮普一提遗址就不自在，好像有事放不下。", "We’ve got more regulars, and people are getting closer. But Pip still gets uneasy about the ruins. Something’s bothering him.", "常連も増えて、皆も親しくなってきたね。でもピップは遺跡の話になると落ち着かなくて。何か気にしてるみたい。", "熟客多了，大家也比以前熟了。不過皮普一提遺址就不自在，好像有事放不下。"),
        ("皮普总算拿出了钥匙。他说，遗址里的旧零件可能还查得出当年出了什么事。", "Pip finally brought out the key. He thinks the old parts in the ruins could help explain the accident.", "ピップがやっと鍵を出してくれた。遺跡の部品を調べれば、事故のことがわかるかもしれないって。", "皮普總算拿出了鑰匙。他說，遺址裡的舊零件可能還查得出當年出了什麼事。"),
        ("来吃饭的人越来越多，座位都快不够了。山上的人也听说咱们食堂了。", "More people keep coming for dinner. We’re almost out of seats. Even people up the mountain have heard about us.", "食事に来る人が増えて、席が足りなくなりそう。山の人たちも、この食堂のことを聞いたんだって。", "來吃飯的人越來越多，座位都快不夠了。山上的人也聽說咱們食堂了。"),
        ("霜铃找到的邮戳只剩一半，日期不全。她一直惦记着，想知道那封旧信是哪天寄的。", "Yuki’s postmark is only half there, so the date’s incomplete. She really wants to know when that old letter was sent.", "ユキの見つけた消印は半分だけで、日付が欠けてるの。あの古い手紙がいつ出されたか、気になってるみたい。", "霜鈴找到的郵戳只剩一半，日期不全。她一直惦記著，想知道那封舊信是哪天寄的。"),
        ("星芒弄明白了，星图的空格对应不同作物。她正在核对农场的收获记录。", "Aster worked it out: the chart’s blanks match different crops. She’s checking the farm’s harvest records.", "アスターが星図の空欄を解いたよ。作物に対応してるんだって。今は農場の収穫記録を確かめてる。", "星芒弄明白了，星圖的空格對應不同作物。她正在核對農場的收穫記錄。"),
        ("观星台能读出月晶里的旧记录。不过内容还没齐，那晚发生的事还差几段。", "The observatory can read the old records in the crystals. But some are still missing, so we don’t have the full story of that night.", "天文台で月晶の記録を読めるようになったよ。でもまだ欠けた部分があって、あの夜のことは全部わかってないんだ。", "觀星臺能讀出月晶裡的舊記錄。不過內容還沒齊，那晚發生的事還差幾段。"),
        ("长桌摆好了，大家都说要来。陶陶翻出了宴席的食谱，今天可有得忙了。", "The table’s set, and everyone says they’re coming. Toma’s found the feast recipes. It’s going to be a busy day.", "長机の準備はできて、皆も来るって。トマが宴の料理帳を出してきたよ。今日は忙しくなりそう。", "長桌擺好了，大家都說要來。陶陶翻出了宴席的食譜，今天可有得忙了。"),
    ]
    guide = dict(welcome=[t(*record) for record in welcome], chapters=[q['briefing'] for q in quests], current=[t(*record) for record in current],
                 farewell=t("月环亮了，大家也都在。真好啊。以后有空，咱们还一起吃饭。", "The moonring’s shining, and everyone’s here. It’s good to see. Let’s keep having dinner together.", "月環も光って、皆もいる。よかったね。これからも一緒にご飯を食べよう。", "月環亮了，大家也都在。真好啊。以後有空，咱們還一起吃飯。"),
                 topics=[dict(chapter=chapter, name=t(*name), lines=[t(*record) for record in records]) for chapter, name, records in topics])
    t('地点：%s', 'Place: %s', '場所：%s', '地點：%s')
    t("这件事办成了，真好。", "We did it. That’s good to see.", "うまくいったね。よかった。", "這件事辦成了，真好。")
    t('%s · %d/%d', '%s · %d/%d', '%s・%d/%d', '%s · %d/%d')
    t('回顾', 'Recall', '回想', '回顧')
    return dict(onboarding=onboarding, guide=guide)
