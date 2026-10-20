"""Apply reviewed dialogue to the existing authoring sources and catalog."""
import ast
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
before = json.loads((OUT / 'before/Scenes/Campaign/content.json').read_text(encoding='utf-8'))
replacements = {}


def records(text):
    rows = [line.strip().split('|') for line in text.strip().splitlines() if line.strip()]
    assert all(len(row) == 4 and all(row) for row in rows), rows
    return rows


def assign(old, text):
    rows = records(text)
    assert len(old) == len(rows), (len(old), len(rows))
    for key, row in zip(old, rows):
        assert key not in replacements or replacements[key] == row
        replacements[key] = row


assign([x['line'] for x in before['intro']], '''
小女巫从小在雾港旅店的后厨帮忙。每天做一大锅饭，却总是她一个人在厨房吃。|The little witch grew up helping in a Fog Harbor inn kitchen. She cooked for everyone, then ate alone in the kitchen.|小さな魔女は霧港の宿の厨房で育った。皆のご飯を作っても、自分はいつも厨房で一人で食べていた。|小女巫從小在霧港旅店的後廚幫忙。每天做一大鍋飯，卻總是她一個人在廚房吃。
一个下雨的晚上，一封信落在洗碗台上。收信人是她，却没写谁寄的。信里问：今年能来一起吃顿饭吗？|One rainy evening, a letter landed by the sink. It was addressed to her, with no sender’s name. It asked: could you join us for dinner this year?|雨の晩、流し台に手紙が落ちてきた。宛名は彼女、差出人は書いていない。「今年、一緒にご飯を食べませんか」とあった。|一個下雨的晚上，一封信落在洗碗臺上。收信人是她，卻沒寫誰寄的。信裡問：今年能來一起吃頓飯嗎？
信里还附着一本旧食谱。她收拾好衣服和锅子，头一回独自出远门，去找信里说的小镇。|An old recipe book came with the letter. She packed her clothes and pots, then set off alone for the town it mentioned.|古い料理帳も添えてあった。服と鍋を鞄に詰め、手紙にあった町へ、初めて一人で遠出した。|信裡還附著一本舊食譜。她收拾好衣服和鍋子，頭一回獨自出遠門，去找信裡說的小鎮。
哗啦啦魔女镇的月环已经很久没亮了。季节照常变，田却荒着，食堂也关了门，大家很少再一起吃饭。|Walala Witch Town’s moonring had been dark for years. The seasons still changed, but the fields lay empty and the eatery was closed. People rarely ate together anymore.|ワララ魔女の町の月環は、長い間消えたまま。季節は変わっても畑は荒れ、食堂も閉まっていた。皆で食事することも減っていた。|嘩啦啦魔女鎮的月環已經很久沒亮了。季節照常變，田卻荒著，食堂也關了門，大家很少再一起吃飯。
月芽农场的小屋没锁门。她放下箱子，松了口气：总算到了，以后也许就住这儿了。|The cottage on Moonsprout Farm was unlocked. She set down her trunk with a sigh of relief. She had made it. Maybe this could be her home.|月芽農場の小屋には鍵がかかっていなかった。鞄を下ろして、ほっと息をつく。やっと着いた。ここで暮らせるかもしれない。|月芽農場的小屋沒鎖門。她放下箱子，鬆了口氣：總算到了，以後也許就住這兒了。
''')

assign(before['guide']['welcome'], '''
我叫萤萝，是镇上的巡灯员，平时负责照看月灯。|I’m Yingluo, the town’s lantern keeper. I look after the moon lanterns.|私はインルオ。町の灯守で、月灯の手入れをしているの。|我叫螢蘿，是鎮上的巡燈員，平時負責照看月燈。
你就是收到信的小女巫吧？这间屋子一直空着，这下总算有人住了。|You’re the witch who got that letter, right? This cottage has been empty for ages. It’s good to have someone here.|手紙を受け取った魔女さんだよね？ ここ、ずっと空き家だったの。住む人が来てくれてよかった。|你就是收到信的小女巫吧？這間屋子一直空著，這下總算有人住了。
月环不亮以后，镇上就越来越冷清了，食堂也关了门。那封信是谁寄的，我也不知道。|After the moonring went dark, the town got quieter and the eatery closed. I don’t know who sent your letter either.|月環が消えてから町はだんだん寂しくなって、食堂も閉まったの。手紙の差出人は、私も知らないんだ。|月環不亮以後，鎮上就越來越冷清了，食堂也關了門。那封信是誰寄的，我也不知道。
咦，你这本旧食谱上也画着星星？灯座上有差不多的图案，我还没弄明白是什么意思。|Oh, your recipe book has stars drawn in it too? The lantern bases have similar marks. I haven’t worked out what they mean.|あれ、その料理帳にも星の絵があるんだ。灯の台座にも似た印があるの。意味はまだわからなくて。|咦，你這本舊食譜上也畫著星星？燈座上有差不多的圖案，我還沒弄明白是什麼意思。
陶陶听说食堂要重新开门，还留着那三只旧碗。他挺盼着能再和大家一起喝碗汤的。|Toma heard the eatery might reopen. He’s kept those three old bowls. He’d love to share some soup with everyone again.|トマは食堂がまた開くかもって聞いて、古い器を三つ残してあるの。皆とまたスープを飲みたいんだって。|陶陶聽說食堂要重新開門，還留著那三隻舊碗。他挺盼著能再和大家一起喝碗湯的。
这本手记给你。镇上的人和最近发生的事，都记在里面了。欢迎来哗啦啦！|This journal’s for you. It has notes about the residents and what’s been happening lately. Welcome to Walala!|この手帳、どうぞ。町の人のことや、最近あったことが書いてあるよ。ワララへようこそ！|這本手記給你。鎮上的人和最近發生的事，都記在裡面了。歡迎來嘩啦啦！
''')

assign([q['briefing'] for q in before['quests']], '''
陶陶还留着以前的备料篮和三人份菜单。食堂很久没开火了，厨房还缺新鲜食材。|Toma kept the old prep basket and a menu for three. The eatery hasn’t cooked in ages, and the kitchen needs fresh ingredients.|トマは昔の仕込み籠と三人分の献立を残していた。食堂は長く休んでいて、新鮮な食材が足りない。|陶陶還留著以前的備料籃和三人份菜單。食堂很久沒開火了，廚房還缺新鮮食材。
陶陶把三只旧碗擦干净了。食材也有了，大家都在等食堂重新开门后的第一顿晚饭。|Toma has cleaned the three old bowls. The ingredients are ready, and everyone’s waiting for the eatery’s first dinner in years.|トマが古い器を三つ洗った。食材もそろい、皆が久しぶりの夕食を楽しみにしている。|陶陶把三隻舊碗擦乾淨了。食材也有了，大家都在等食堂重新開門後的第一頓晚飯。
茉莉留下了一些当季种子。农场的地还能种，往后食堂就能用上自己种的新鲜菜了。|Mori left some seeds for this season. The farm’s soil is still good, so the eatery could have fresh homegrown vegetables.|モリが今の季節の種を残してくれた。農場の土はまだ使える。食堂で自分たちの野菜を出せそうだ。|茉莉留下了一些當季種子。農場的地還能種，往後食堂就能用上自己種的新鮮菜了。
旧水门的齿轮缺了一块。余烬有图纸，但修齿轮的矿石还不够，石谷里还有矿。|A gear in the old sluice is broken. Ember has the plans, but needs more ore to repair it. There’s still ore in the quarry.|古い水門の歯車が欠けている。エンバーには図面があるが、修理の鉱石が足りない。石谷にはまだ鉱石がある。|舊水門的齒輪缺了一塊。餘燼有圖紙，但修齒輪的礦石還不夠，石谷裡還有礦。
水道又通了，芦苇说鱼也回来了。码头和湿地的鱼群，能看出水道恢复得怎么样。|The water is flowing again, and Reed says the fish are back. Catches from the dock and marsh will show how the waterways are doing.|水路が通り、リードによると魚も戻ってきた。桟橋や湿地の釣果で、水路の様子がわかりそうだ。|水道又通了，蘆葦說魚也回來了。碼頭和濕地的魚群，能看出水道恢復得怎麼樣。
食堂的熟客多起来了。大家渐渐熟了，有人开始愿意聊起月环熄灭那晚的事。|The eatery has regulars again. As people get to know each other, some are ready to talk about the night the moonring went dark.|食堂に常連が増えてきた。親しくなるうちに、月環が消えた夜のことを話す人も出てきた。|食堂的熟客多起來了。大家漸漸熟了，有人開始願意聊起月環熄滅那晚的事。
皮普拿出了遗址的钥匙。里面的旧零件刻着编号，可能和月环那次事故有关。|Pip has brought out the ruins key. The numbers on the old parts inside may be connected to the moonring accident.|ピップが遺跡の鍵を出してくれた。中にある古い部品の番号は、月環の事故と関係があるかもしれない。|皮普拿出了遺址的鑰匙。裡面的舊零件刻著編號，可能和月環那次事故有關。
旧记录里提到了食堂的长桌。现在来吃饭的人越来越多，座位有些不够了。|The old records mention the eatery’s long table. More people are coming for dinner, and seats are getting scarce.|古い記録に食堂の長机が出てきた。今も食事に来る人が増えて、席が足りなくなってきた。|舊記錄裡提到了食堂的長桌。現在來吃飯的人越來越多，座位有些不夠了。
霜铃找到了半枚旧邮戳。山径上可能还留着当年的信件，能查出月环熄灭的准确日期。|Yuki found half an old postmark. Letters along the ridge may give the exact date the moonring went dark.|ユキが古い消印の半分を見つけた。山道に残る手紙から、月環が消えた正確な日付がわかるかもしれない。|霜鈴找到了半枚舊郵戳。山徑上可能還留著當年的信件，能查出月環熄滅的準確日期。
星图上有十二处空格，分别对应不同的作物。农场的收获记录，正好能补全这张图。|The chart has twelve blanks, each for a different crop. The farm’s harvest records can fill them in.|星図には作物に対応する十二の空欄がある。農場の収穫記録があれば、この図を完成できそうだ。|星圖上有十二處空格，分別對應不同的作物。農場的收穫記錄，正好能補全這張圖。
四季星图已经补齐，观星台也开了。月晶里还存着事故当晚的记录，只是缺了几段。|The seasonal chart is complete and the observatory is open. The crystals hold a record of the accident, but parts are still missing.|四季の星図が完成し、天文台も開いた。月晶には事故の夜の記録が残っているが、まだ一部が欠けている。|四季星圖已經補齊，觀星臺也開了。月晶裡還存著事故當晚的記錄，只是缺了幾段。
长桌已经摆好。宴席的三道菜是星河宴、四季团圆盘和万家灯火甜点，大家都盼着这顿团圆饭。|The long table is set. The feast has Star River Banquet, Four Seasons Platter and Lantern Home Dessert. Everyone’s looking forward to eating together.|長机の準備はできた。宴の料理は星河の宴、四季団らん皿、万家灯火デザート。皆で食べるのを楽しみにしている。|長桌已經擺好。宴席的三道菜是星河宴、四季團圓盤和萬家燈火甜點，大家都盼著這頓團圓飯。
''')

assign([beat['text'] for q in before['quests'] for beat in q['dialogue']], '''
这篮子可算装上东西了。我留了这么久，还以为食堂真不开了。|Good to see this basket full again. I kept it all this time, but thought the eatery might never reopen.|やっと籠に食材が入ったな。ずっと残していたけど、もう食堂は開かないかと思ったよ。|這籃子可算裝上東西了。我留了這麼久，還以為食堂真不開了。
食材够了，今晚能做饭了。那三只碗里，也有你的一份。|We’ve got enough to cook dinner tonight. And one of those three bowls is yours.|これで今夜のご飯は作れるね。三つの器のうち、一つはあなたの分だよ。|食材夠了，今晚能做飯了。那三隻碗裡，也有你的一份。
还有我的？……好，那我把旧菜单拿出来，看看以前都做些什么。|One for me too? All right. I’ll get the old menu out and see what we used to make.|私の分も？ ……そうか。じゃあ昔の献立を出そう。何を作っていたか、見てみるよ。|還有我的？……好，那我把舊菜單拿出來，看看以前都做些什麼。
太好了，食堂总算又能开火了。陶陶刚才还担心今晚吃不上呢。|Great, we can finally get the stove going again. Toma was worried there’d be no dinner tonight.|よかった、やっと食堂の火をつけられるね。トマ、今夜はご飯がないかもって心配してたんだ。|太好了，食堂總算又能開火了。陶陶剛才還擔心今晚吃不上呢。
这汤真好喝。以前大家吃完都说改天再来，后来食堂一关，就再也没聚过了。|This soup’s lovely. We used to say we’d come back soon. Then the eatery closed, and we never got together again.|おいしいスープ。昔は皆、また来るねって言ってたのに、食堂が閉まってから集まらなくなっちゃった。|這湯真好喝。以前大家吃完都說改天再來，後來食堂一關，就再也沒聚過了。
我还打算继续开呢。农场的地也不能一直空着，我想种点菜，往后做饭用。|I’m planning to keep it open. I’d like to grow some vegetables on the farm for the kitchen, too.|私はこれからも開けるつもりだよ。農場で野菜も育てたいな。料理に使えるし。|我還打算繼續開呢。農場的地也不能一直空著，我想種點菜，往後做飯用。
那太好了！我留下的都是当季种子。我可等着尝尝你种的菜了。|That sounds great! The seeds I left are right for this season. I can’t wait to taste what you grow.|いいね！ 置いておいたのは今の季節の種だよ。あなたの野菜、楽しみにしてる。|那太好了！我留下的都是當季種子。我可等著嚐嚐你種的菜了。
你们看见了吗？外面那盏月灯刚才亮了一下！好久没这样了。|Did you see that? The moon lantern outside just flickered! It hasn’t done that in ages.|見えた？ 外の月灯が今、一瞬光ったよ！ こんなの、久しぶり。|你們看見了嗎？外面那盞月燈剛才亮了一下！好久沒這樣了。
真长出来了！这地荒了这么久，我还担心种不活呢。|They really grew! The field was empty for so long, I worried nothing would take.|ちゃんと育ったね！ ずっと荒れてたから、育たないんじゃないかって心配してたの。|真長出來了！這地荒了這麼久，我還擔心種不活呢。
田边那块旧路牌我认得，上面画的是水门。那儿的齿轮还坏着，修好就能通水。|I recognize that old field sign. It marks the sluice. Its gear’s still broken; fixing it would get the water flowing.|畑の古い標識、見覚えがある。水門の印だ。あそこの歯車を直せば、水が通る。|田邊那塊舊路牌我認得，上面畫的是水門。那兒的齒輪還壞著，修好就能通水。
原来那是水门的标记。现在有了新鲜菜，要是鱼也能回来，菜单就更丰富了。|So that’s what the mark means. We’ve got fresh vegetables now. If the fish came back too, we’d have more for the menu.|あれ、水門の印だったんだ。新鮮な野菜はあるし、魚も戻れば料理の種類を増やせるね。|原來那是水門的標記。現在有了新鮮菜，要是魚也能回來，菜單就更豐富了。
余烬手里还有水门的图纸。他惦记这事挺久了，一直缺修理用的矿石。|Ember still has the sluice plans. He’s wanted to fix it for ages, but hasn’t had enough ore.|エンバー、水門の図面をまだ持ってるよ。ずっと直したかったけど、鉱石が足りなかったんだって。|餘燼手裡還有水門的圖紙。他惦記這事挺久了，一直缺修理用的礦石。
矿石够了，图纸也补齐了。这回我有把握修好那只齿轮。|That’s enough ore, and the plans are complete. I’m sure I can fix that gear now.|鉱石は足りた。図面もそろった。これなら、あの歯車を直せる。|礦石夠了，圖紙也補齊了。這回我有把握修好那隻齒輪。
莲塘那边已经有水声了。水流稳下来，鱼和候鸟应该都会回来。|I can hear water at the lotus pond already. Once the flow settles, the fish and birds should come back.|蓮池からもう水音がするよ。流れが落ち着けば、魚も渡り鳥も戻ってきそうだ。|蓮塘那邊已經有水聲了。水流穩下來，魚和候鳥應該都會回來。
那太好了。往后除了菜汤，食堂也能做鱼汤了。|That’s good news. We’ll be able to serve fish soup as well as vegetable soup.|よかった。これからは野菜スープだけじゃなく、魚のスープも作れるね。|那太好了。往後除了菜湯，食堂也能做魚湯了。
月灯底座又亮了一小段，和上次一样。水道修好了，灯也有反应，难道有关系？|Another little part of the lantern base lit up, like last time. The water’s back and the lantern reacted. Could they be connected?|灯の台座がまた少し光った。前と同じだ。水路が直ったことと、何か関係あるのかな？|月燈底座又亮了一小段，和上次一樣。水道修好了，燈也有反應，難道有關係？
鱼真的回来了！这阵子码头总算热闹点了，我都好久没见人围着鱼篓聊天了。|The fish really are back! The dock’s livelier lately. It’s been ages since people gathered around a catch to chat.|本当に魚が戻った！ 最近、桟橋もにぎやかになったよ。魚籠を囲んで皆が話すの、久しぶりだな。|魚真的回來了！這陣子碼頭總算熱鬧點了，我都好久沒見人圍著魚簍聊天了。
我还在旧网里找到这块薄片。上面的编号，跟皮普那本日志里的很像。|I also found this plate in an old net. The number looks like the ones in Pip’s logbook.|古い網にこんな薄い板も引っかかっていたよ。この番号、ピップの記録帳で見たものに似てる。|我還在舊網裡找到這塊薄片。上面的編號，跟皮普那本日誌裡的很像。
那它可能是遗址里的零件？皮普应该认得吧。|Could it be a part from the ruins? Pip might recognize it.|じゃあ、遺跡の部品かもしれないね。ピップならわかるかな。|那它可能是遺址裡的零件？皮普應該認得吧。
有可能。不过他一提遗址就紧张，大概还有什么事没告诉我们。|Maybe. But he gets nervous whenever the ruins come up. There’s probably something he hasn’t told us.|そうかも。でも遺跡の話になると、ピップは緊張するの。まだ話していないことがあるんだと思う。|有可能。不過他一提遺址就緊張，大概還有什麼事沒告訴我們。
遗址的钥匙其实一直在我这儿。门能开，是我自己不敢再进去。|I’ve had the ruins key all along. The door opens. I’m the one who’s been afraid to go back.|遺跡の鍵、実はずっと僕が持ってた。扉は開くんだ。僕が戻るのを怖がってただけで。|遺址的鑰匙其實一直在我這兒。門能開，是我自己不敢再進去。
没关系，这次有我们陪你。你不用一个人面对那些事。|It’s all right. We’re here with you this time. You don’t have to face it alone.|大丈夫。今度は私たちもいるから。一人で向き合わなくていいよ。|沒關係，這次有我們陪你。你不用一個人面對那些事。
嗯……那钥匙就放桌上了。今晚我还是坐老位置，饭可别少了我的。|Okay… I’ll leave the key on the table. I’m still taking my usual seat tonight. Save me some dinner.|うん……じゃあ鍵は机に置いとく。今夜もいつもの席に座るから、僕のご飯も忘れないでね。|嗯……那鑰匙就放桌上了。今晚我還是坐老位置，飯可別少了我的。
当然有你的。你能把这事说出来，我也松了口气。|Of course we will. I’m glad you could tell us. I feel better too.|もちろんあるよ。話してくれて、私もほっとした。|當然有你的。你能把這事說出來，我也鬆了口氣。
编号全对上了。原来这台核心把所有灯接在一起，一直不停地转，最后把回路烧坏了。|The numbers match. This core linked all the lanterns together. It ran without stopping until the circuit burned out.|番号が全部合った。この核が全部の灯をつないでたんだ。動き続けたせいで、最後に回路が焼けた。|編號全對上了。原來這臺核心把所有燈接在一起，一直不停地轉，最後把迴路燒壞了。
所以光补齿轮没用，回路也得改。图纸上居然没画停机的装置。|So replacing a gear won’t be enough. The circuit needs work too. These plans don’t even have a shutoff.|歯車だけ直してもだめだ。回路も変えないと。図面には停止装置すら描いてない。|所以光補齒輪沒用，迴路也得改。圖紙上居然沒畫停機的裝置。
食堂也不能一直营业，人总得歇歇。机器该停的时候，也得能停下来。|We can’t keep the eatery open all the time either. People need rest. Machines need to be able to stop too.|食堂だってずっとは開けられないよね。人も休むし、機械にも止まれる仕組みがいるんだ。|食堂也不能一直營業，人總得歇歇。機器該停的時候，也得能停下來。
记录里还提到了食堂的长桌。不过这部分没写全，还不知道它和月环有什么关系。|The records mention the eatery’s long table too. That part’s incomplete, so we still don’t know how it connects to the moonring.|記録には食堂の長机も出てくる。でもそこは欠けていて、月環との関係はまだわからないね。|記錄裡還提到了食堂的長桌。不過這部分沒寫全，還不知道它和月環有什麼關係。
我得告诉你一件事。那封没署名的信，是我写的。我怕你知道镇上这么困难，就不肯来了。|I need to tell you something. I wrote that unsigned letter. I was afraid you wouldn’t come if you knew how badly the town was doing.|話さなきゃいけないことがあるの。あの匿名の手紙は私が書いた。町の苦しい暮らしを知ったら、来てくれないと思って。|我得告訴你一件事。那封沒署名的信，是我寫的。我怕你知道鎮上這麼困難，就不肯來了。
原来是你啊。你信里不是问能不能一起吃饭吗？现在当然能，你的位子也留着呢。|So it was you. You asked if we could have dinner together, right? Of course we can. There’s a place for you too.|あなただったんだ。一緒にご飯を食べられるかって書いてたよね。もちろん。あなたの席もあるよ。|原來是你啊。你信裡不是問能不能一起吃飯嗎？現在當然能，你的位子也留著呢。
说起信，我在山上的旧邮袋里找到半枚邮戳。看着跟当年那场事故有关，日期却看不全。|Speaking of letters, I found half a postmark in an old mailbag up the mountain. It seems tied to the accident, but I can’t read the whole date.|手紙といえば、山の古い郵袋に消印の半分があったの。あの事故と関係がありそうだけど、日付が全部読めなくて。|說起信，我在山上的舊郵袋裡找到半枚郵戳。看著跟當年那場事故有關，日期卻看不全。
奥萝，这下不用藏着了。食堂能重新开起来，也有你的一份功劳。|Orla, you don’t have to hide it anymore. You helped bring this eatery back too.|オルラ、もう隠さなくていいよ。食堂がまた開いたのは、あなたのおかげでもあるんだから。|奧蘿，這下不用藏著了。食堂能重新開起來，也有你的一份功勞。
日期查清楚了，就是月环熄灭那晚。守灯人的记录里还写着，月环里存着最后一段记忆。|We’ve got the date: the night the moonring went dark. The lantern keeper’s notes also say one last memory is stored in it.|日付がわかった。月環が消えた夜だよ。灯守の記録には、最後の記憶が月環に残っているとも書いてある。|日期查清楚了，就是月環熄滅那晚。守燈人的記錄裡還寫著，月環裡存著最後一段記憶。
和我的记录对上了。星图上那些空格，对应的是作物的收获记录，不是星星的位置。|That matches my notes. Those blanks on the chart are for crop harvests, not star positions.|私の記録とも合った。星図の空欄は、星の位置じゃない。作物の収穫記録に対応しているんだ。|和我的記錄對上了。星圖上那些空格，對應的是作物的收穫記錄，不是星星的位置。
原来是这样。不同季节长的菜不一样，难怪这图一时半会儿填不满。|So that’s it. Different crops grow in different seasons. No wonder we couldn’t fill it all at once.|そういうことか。季節ごとに育つ野菜が違うものね。一度に埋まらないわけだ。|原來是這樣。不同季節長的菜不一樣，難怪這圖一時半會兒填不滿。
不着急。农场已经种起来了，收过哪些作物，手记里也都有记录。|There’s no rush. The farm’s growing again, and the journal already lists what we’ve harvested.|急がなくていいよ。農場はもう動いてるし、収穫した作物も手帳に記録してあるから。|不著急。農場已經種起來了，收過哪些作物，手記裡也都有記錄。
十二种都齐了！看着这些收获记录，才发现咱们已经种了这么多东西。|All twelve! Looking at these harvest records, I hadn’t realized how much we’d grown.|十二種類、そろったね！ 記録を見ると、こんなにいろんなものを育てたんだなって思うよ。|十二種都齊了！看著這些收穫記錄，才發現咱們已經種了這麼多東西。
星图终于对上了。它记录的是作物长大的日子，所以得有实际的收获才行。|The chart finally lines up. It records when the crops grew, so it needed real harvests.|星図がやっと合った。作物が育った日々を記録する図だから、実際の収穫が必要だったんだ。|星圖終於對上了。它記錄的是作物長大的日子，所以得有實際的收穫才行。
这下明白了。难怪光对着图猜，怎么都猜不出来。|Now it makes sense. No wonder staring at the chart got us nowhere.|やっとわかったよ。図だけ見て考えても、解けないはずだね。|這下明白了。難怪光對著圖猜，怎麼都猜不出來。
观星台的门也开了！里面能读出月晶的记录，应该能弄清那晚到底出了什么事。|The observatory’s open too! We can read the crystals there. Maybe now we’ll find out what happened that night.|天文台の門も開いたよ！ 中では月晶の記録を読めるから、あの夜のこともわかるはず。|觀星臺的門也開了！裡面能讀出月晶的記錄，應該能弄清那晚到底出了什麼事。
记录补齐了。月环靠大家一起生活的记忆发光。以前留下的记忆撑到现在，已经不够用了。|The record’s complete. The moonring runs on memories of people living together. The old memories have kept it going, but they aren’t enough anymore.|記録がそろった。月環は皆で暮らした記憶で光るんだ。昔の記憶で今まで支えたけど、もうそれだけでは足りない。|記錄補齊了。月環靠大家一起生活的記憶發光。以前留下的記憶撐到現在，已經不夠用了。
所以记录里才会有那张长桌！大家一起吃饭，就能留下新的记忆，月环也能重新亮起来。|That’s why the long table was in the records! Eating together makes new memories. Those can light the moonring again.|だから長机が記録に出てきたんだ！ 皆でご飯を食べれば新しい記憶ができて、月環もまた光るんだね。|所以記錄裡才會有那張長桌！大家一起吃飯，就能留下新的記憶，月環也能重新亮起來。
那今晚就热闹一点，大家一起吃。忙了这么久，也该好好聚一顿了。|Then let’s have everyone over tonight. We’ve all been busy. It’s time for a proper meal together.|じゃあ今夜は皆でにぎやかに食べよう。ずっと忙しかったし、ゆっくり集まってご飯にしたいね。|那今晚就熱鬧一點，大家一起吃。忙了這麼久，也該好好聚一頓了。
旧食谱里那三道宴席菜，正好派上用场。我也好久没做这么一大桌饭了。|Those three feast recipes in the old book will be just right. I haven’t cooked for a crowd like this in ages.|古い料理帳の宴料理三品が、ちょうどいいな。こんな大勢のご飯を作るのは久しぶりだよ。|舊食譜裡那三道宴席菜，正好派上用場。我也好久沒做這麼一大桌飯了。
人都到齐了。我把你的位子也算上了，忙完这一阵，咱们就一起吃。|Everyone’s here. I’ve counted a seat for you too. Once this is ready, we’ll all eat together.|皆そろったよ。あなたの席も入れてある。支度が済んだら、一緒に食べようね。|人都到齊了。我把你的位子也算上了，忙完這一陣，咱們就一起吃。
那封信的回话，我想好了：今年一起吃，明年也一起吃。|I’ve thought of my reply to that letter: dinner together this year, and next year too.|あの手紙の返事、決めたよ。今年も一緒に食べよう。来年もね。|那封信的回話，我想好了：今年一起吃，明年也一起吃。
亮了！月环真的亮了！咱们一起忙的这些日子，真的有用了。|It’s shining! The moonring’s really shining! All that time we spent working together made a difference.|光った！ 本当に月環が光ったよ！ 皆で頑張ってきた日々が、ちゃんと役に立ったんだね。|亮了！月環真的亮了！咱們一起忙的這些日子，真的有用了。
好啦，汤还热着呢。今天这顿饭，我可要多喝两碗。|Well, the soup’s still hot. I’m having seconds tonight.|さあ、スープはまだ温かいよ。今日はおかわりするつもりだ。|好啦，湯還熱著呢。今天這頓飯，我可要多喝兩碗。
''')

assign([q['description'] for q in before['quests']], '''
三份新鲜食材备齐了，陶陶也擦好了碗。食堂总算能重新开火了。|Three fresh ingredients are ready, and Toma has cleaned the bowls. The eatery can finally cook again.|新鮮な食材が三つそろい、トマも器を洗った。やっと食堂で料理を作れる。|三份新鮮食材備齊了，陶陶也擦好了碗。食堂總算能重新開火了。
三份晚饭端上了桌，外面的月灯短暂亮了一下。茉莉留下当季种子，盼着能吃上农场的新鲜菜。|Three dinners were served, and the moon lantern outside briefly lit up. Mori left seasonal seeds, looking forward to the farm’s vegetables.|三つの夕食を出すと、外の月灯が一瞬光った。モリは季節の種を残し、農場の野菜を楽しみにしている。|三份晚飯端上了桌，外面的月燈短暫亮了一下。茉莉留下當季種子，盼著能吃上農場的新鮮菜。
农场收了五份作物。余烬认出田边旧路牌上的水门标记，说修好那里的齿轮就能通水。|The farm produced five crops. Ember recognized the sluice mark on the old sign. Repairing its gear would restore the water.|農場で五つ収穫した。エンバーが古い標識の水門の印に気づいた。歯車が直れば水が通るそうだ。|農場收了五份作物。餘燼認出田邊舊路牌上的水門標記，說修好那裡的齒輪就能通水。
矿石够了，余烬也补齐了修水门的图纸。湿地重新有了水声，鱼和候鸟有望回来。|There’s enough ore, and Ember has completed the sluice plans. Water can be heard in the marsh again. The fish and birds may return.|鉱石がそろい、エンバーも水門の図面を完成させた。湿地に水音が戻り、魚や渡り鳥も戻ってきそうだ。|礦石夠了，餘燼也補齊了修水門的圖紙。濕地重新有了水聲，魚和候鳥有望回來。
五次鱼获说明鱼群回来了。芦苇还在旧网里发现一块薄片，上面的编号和皮普的日志很像。|Five catches show the fish are back. Reed also found a plate in an old net, with a number like those in Pip’s logbook.|五度の釣果で魚が戻ったことがわかった。リードは古い網から、ピップの記録に似た番号の薄片も見つけた。|五次魚獲說明魚群回來了。蘆葦還在舊網裡發現一塊薄片，上面的編號和皮普的日誌很像。
皮普终于说出自己不敢回遗址的事，把钥匙交给了大家。这次，他不用再独自面对了。|Pip finally admitted he was afraid to return to the ruins and shared the key. This time, he won’t have to face it alone.|ピップは遺跡に戻るのが怖かったと打ち明け、鍵を皆に預けた。今度は一人で向き合わなくていい。|皮普終於說出自己不敢回遺址的事，把鑰匙交給了大家。這次，他不用再獨自面對了。
八份零件的编号对上了旧记录。核心曾连着所有月灯，因为一直不停机，最终烧坏了回路。|Eight part numbers matched the old records. The core linked all the moon lanterns, but running without stopping burned out the circuit.|八つの部品番号が記録と合った。核は月灯をすべてつないでいたが、動き続けて回路を焼いてしまった。|八份零件的編號對上了舊記錄。核心曾連著所有月燈，因為一直不停機，最終燒壞了迴路。
食堂添了座位，奥萝也承认匿名信是她写的。霜铃从山上的旧邮袋里找到半枚邮戳，日期还不完整。|The eatery has more seats. Orla admitted writing the unsigned letter. Yuki found half a postmark up the mountain, but the date is incomplete.|食堂の席が増え、オルラは匿名の手紙を書いたと打ち明けた。ユキは山で消印の半分を見つけたが、日付は欠けている。|食堂添了座位，奧蘿也承認匿名信是她寫的。霜鈴從山上的舊郵袋裡找到半枚郵戳，日期還不完整。
六次山径调查查清了旧信的日期，正是月环熄灭那晚。星芒也认出星图的空格对应不同作物的收获记录。|Six ridge finds confirmed the date: the night the moonring went dark. Aster identified the chart’s blanks as crop harvest records.|六度の山道調査で、手紙の日付が月環の消えた夜とわかった。アスターは星図の空欄が収穫記録だと気づいた。|六次山徑調查查清了舊信的日期，正是月環熄滅那晚。星芒也認出星圖的空格對應不同作物的收穫記錄。
十二种作物的收获记录补全了四季星图，观星台的门打开了。那里的设备能读出月晶保存的记录。|Records of twelve crop harvests completed the chart and opened the observatory. Its equipment can read the records stored in moon crystals.|十二種の作物の収穫記録で四季の星図が完成し、天文台が開いた。中の装置なら月晶の記録を読める。|十二種作物的收穫記錄補全了四季星圖，觀星臺的門打開了。那裡的設備能讀出月晶保存的記錄。
八枚月晶补齐了旧记录。原来月环靠共同生活的记忆发光，大家一起过日子，就能给它补上新的力量。|Eight crystals completed the record. The moonring runs on shared memories. Living together can give it fresh energy.|八つの月晶で記録がそろった。月環は共に暮らした記憶で光る。皆の日々が、新しい力になる。|八枚月晶補齊了舊記錄。原來月環靠共同生活的記憶發光，大家一起過日子，就能給它補上新的力量。
三道宴席菜上了桌，大家又聚到一起，月环终于重新亮了。小女巫也有了自己的家和一起吃饭的人。|The three feast dishes were served, everyone gathered, and the moonring shone again. The little witch now has a home and people to share dinner with.|宴の三品が並び、皆が集まると、月環がまた光った。小さな魔女にも、家と一緒に食事する人たちができた。|三道宴席菜上了桌，大家又聚到一起，月環終於重新亮了。小女巫也有了自己的家和一起吃飯的人。
''')

assign(before['guide']['current'], '''
陶陶还留着以前的菜单和备料篮。他嘴上不说，其实挺盼着食堂重新开门的。|Toma kept the old menu and prep basket. He won’t say it, but he’s really hoping the eatery will reopen.|トマは昔の献立と仕込み籠を残してるの。口には出さないけど、食堂の再開を楽しみにしてるんだよ。|陶陶還留著以前的菜單和備料籃。他嘴上不說，其實挺盼著食堂重新開門的。
陶陶把碗都擦好了，食材也齐了。大家都在等今晚这顿饭呢。|Toma’s cleaned the bowls, and we have the ingredients. Everyone’s looking forward to dinner tonight.|トマが器を洗って、食材もそろったよ。皆、今夜のご飯を楽しみにしてる。|陶陶把碗都擦好了，食材也齊了。大家都在等今晚這頓飯呢。
茉莉这几天总在看农场。那地荒了太久，她担心种子种不活。|Mori keeps checking on the farm. The field was empty for so long, she’s worried the seeds won’t grow.|モリ、このところ農場を気にしてるの。長く荒れてたから、種が育つか心配なんだって。|茉莉這幾天總在看農場。那地荒了太久，她擔心種子種不活。
余烬正在研究水门的图纸。齿轮坏了，修好以后湿地才能通水。|Ember’s studying the sluice plans. The gear’s broken. Once it’s fixed, water can reach the marsh again.|エンバーが水門の図面を調べてるよ。歯車が直れば、湿地に水が通るんだって。|餘燼正在研究水門的圖紙。齒輪壞了，修好以後濕地才能通水。
芦苇说水道通了，鱼也开始回来了。码头这几天比以前热闹多了。|Reed says the water’s flowing and the fish are coming back. The dock’s much livelier these days.|リードによると、水路が通って魚も戻り始めたんだって。最近、桟橋がにぎやかだよ。|蘆葦說水道通了，魚也開始回來了。碼頭這幾天比以前熱鬧多了。
熟客多了，大家也比以前熟了。不过皮普一提遗址就不自在，好像有事放不下。|We’ve got more regulars, and people are getting closer. But Pip still gets uneasy about the ruins. Something’s bothering him.|常連も増えて、皆も親しくなってきたね。でもピップは遺跡の話になると落ち着かなくて。何か気にしてるみたい。|熟客多了，大家也比以前熟了。不過皮普一提遺址就不自在，好像有事放不下。
皮普总算拿出了钥匙。他说，遗址里的旧零件可能还查得出当年出了什么事。|Pip finally brought out the key. He thinks the old parts in the ruins could help explain the accident.|ピップがやっと鍵を出してくれた。遺跡の部品を調べれば、事故のことがわかるかもしれないって。|皮普總算拿出了鑰匙。他說，遺址裡的舊零件可能還查得出當年出了什麼事。
来吃饭的人越来越多，座位都快不够了。山上的人也听说咱们食堂了。|More people keep coming for dinner. We’re almost out of seats. Even people up the mountain have heard about us.|食事に来る人が増えて、席が足りなくなりそう。山の人たちも、この食堂のことを聞いたんだって。|來吃飯的人越來越多，座位都快不夠了。山上的人也聽說咱們食堂了。
霜铃找到的邮戳只剩一半，日期不全。她一直惦记着，想知道那封旧信是哪天寄的。|Yuki’s postmark is only half there, so the date’s incomplete. She really wants to know when that old letter was sent.|ユキの見つけた消印は半分だけで、日付が欠けてるの。あの古い手紙がいつ出されたか、気になってるみたい。|霜鈴找到的郵戳只剩一半，日期不全。她一直惦記著，想知道那封舊信是哪天寄的。
星芒弄明白了，星图的空格对应不同作物。她正在核对农场的收获记录。|Aster worked it out: the chart’s blanks match different crops. She’s checking the farm’s harvest records.|アスターが星図の空欄を解いたよ。作物に対応してるんだって。今は農場の収穫記録を確かめてる。|星芒弄明白了，星圖的空格對應不同作物。她正在核對農場的收穫記錄。
观星台能读出月晶里的旧记录。不过内容还没齐，那晚发生的事还差几段。|The observatory can read the old records in the crystals. But some are still missing, so we don’t have the full story of that night.|天文台で月晶の記録を読めるようになったよ。でもまだ欠けた部分があって、あの夜のことは全部わかってないんだ。|觀星臺能讀出月晶裡的舊記錄。不過內容還沒齊，那晚發生的事還差幾段。
长桌摆好了，大家都说要来。陶陶翻出了宴席的食谱，今天可有得忙了。|The table’s set, and everyone says they’re coming. Toma’s found the feast recipes. It’s going to be a busy day.|長机の準備はできて、皆も来るって。トマが宴の料理帳を出してきたよ。今日は忙しくなりそう。|長桌擺好了，大家都說要來。陶陶翻出了宴席的食譜，今天可有得忙了。
''')

assign([line for topic in before['guide']['topics'] for line in topic['lines']], '''
林里有蘑菇，也有莓果。以前食堂常用这些，陶陶一说起来就停不下来。|There are mushrooms and berries in the woods. The eatery used them a lot. Toma could talk about those dishes all day.|森にはキノコもベリーもあるよ。昔の食堂でよく使ってたんだって。トマ、その話だと止まらないの。|林裡有蘑菇，也有莓果。以前食堂常用這些，陶陶一說起來就停不下來。
以前食堂一到饭点就坐满了，大家连谁爱喝什么汤都记得。我还挺想念那时候的。|The eatery used to fill up at dinnertime. Everyone knew each other’s favorite soup. I miss those days.|昔はご飯の時間になると食堂がいっぱいで、誰が何のスープを好きかも皆知ってたの。懐かしいな。|以前食堂一到飯點就坐滿了，大家連誰愛喝什麼湯都記得。我還挺想念那時候的。
茉莉最放心不下那片田。哪怕只有几棵苗，她也会记着今天长高了没有。|Mori’s always thinking about that field. Even with just a few seedlings, she notices whether they’ve grown.|モリはあの畑が気になるんだって。苗が数本だけでも、今日は伸びたかなって覚えてるの。|茉莉最放心不下那片田。哪怕只有幾棵苗，她也會記著今天長高了沒有。
余烬修过的东西都有图纸留底。以后再出毛病，就不用从头琢磨了。他做事挺仔细的。|Ember keeps plans for everything he repairs. If something breaks again, he won’t have to start from scratch. He’s thorough like that.|エンバーは修理したものの図面を残してるよ。また壊れても、一から調べずに済むんだって。まめだよね。|餘燼修過的東西都有圖紙留底。以後再出毛病，就不用從頭琢磨了。他做事挺仔細的。
芦苇和澪都记着什么时候能见到什么鱼。两人的本子一对，连那天谁在岸边聊天都想起来了。|Reed and Nagi both keep notes on which fish appear when. Comparing their notebooks even reminds them who was chatting on the bank.|リードもナギも、いつどんな魚がいたか書いてるの。帳面を見比べると、その日岸で話してた人まで思い出すんだって。|蘆葦和澪都記著什麼時候能見到什麼魚。兩人的本子一對，連那天誰在岸邊聊天都想起來了。
大家都有不太愿意提的事。现在熟一些了，有人总算愿意说说以前发生了什么。|Everyone has things they find hard to talk about. Now that we’re closer, some people are ready to tell us what happened.|皆、話しづらいこともあるよね。少し親しくなって、昔のことを話してくれる人も出てきたの。|大家都有不太願意提的事。現在熟一些了，有人總算願意說說以前發生了什麼。
没说完也没关系，下次还会见面的。有些事隔一阵再聊，反而容易开口。|It’s all right to leave some things for next time. We’ll see each other again. A little time can make talking easier.|全部話せなくても、また会えるから大丈夫。少し時間を置いたほうが、話しやすくなることもあるしね。|沒說完也沒關係，下次還會見面的。有些事隔一陣再聊，反而容易開口。
''')

assign([before['guide']['farewell']], '''
月环亮了，大家也都在。真好啊。以后有空，咱们还一起吃饭。|The moonring’s shining, and everyone’s here. It’s good to see. Let’s keep having dinner together.|月環も光って、皆もいる。よかったね。これからも一緒にご飯を食べよう。|月環亮了，大家也都在。真好啊。以後有空，咱們還一起吃飯。
''')

steps = before['onboarding']
assign([steps[key]['description'] for key in ['prepare', 'menu', 'first_meal', 'plant', 'water']], '''
厨房的基础原料是加工好的蘑菇、莓果和香草，最早的三道菜都用得上。|Prepared mushrooms, berries and herbs are the kitchen’s basic ingredients. The first three dishes use them.|仕込み済みのキノコ、ベリー、ハーブが厨房の基本材料。最初の三品で使われる。|廚房的基礎原料是加工好的蘑菇、莓果和香草，最早的三道菜都用得上。
菜单黑板还是空的，今晚供应什么菜还没定。|The menu board is still empty. Tonight’s dishes haven’t been decided yet.|献立の黒板はまだ空。今夜の料理はまだ決まっていない。|菜單黑板還是空的，今晚供應什麼菜還沒定。
第一位客人已经点了菜，正等着开饭。|The first guest has ordered and is waiting for dinner.|最初のお客さんは注文を済ませて、ご飯を待っている。|第一位客人已經點了菜，正等著開飯。
农场有五块田等着种新作物。香草四季都能长，其他作物有各自适合的季节。|Five farm plots are waiting for new crops. Herbs grow in every season; other crops have their own seasons.|農場には新しい作物を待つ畑が五区画ある。ハーブは四季に育つが、ほかの作物には合う季節がある。|農場有五塊田等著種新作物。香草四季都能長，其他作物有各自適合的季節。
土是湿的，作物第二天才会长。还没成熟的作物会留在田里。|Crops grow the next day if the soil is wet. Unripe crops stay in the field.|土が湿っていると作物は翌日に育つ。未熟な作物はそのまま畑に残る。|土是濕的，作物第二天才會長。還沒成熟的作物會留在田裡。
''')
assign([steps['water']['name']], '''
田里的水|Water for the Field|畑の水|田裡的水
''')
assign(['这一页的心愿已经实现。'], '''
这件事办成了，真好。|We did it. That’s good to see.|うまくいったね。よかった。|這件事辦成了，真好。
''')

# Each resident keeps the same story stages and first/last affinity lines.
npc_copy = {
    'mori': '''
我还是惦记着温室里的那些种子，不知道今年能不能种活。|I keep thinking about the greenhouse seeds. I wonder if they’ll grow this year.|温室の種が気になるの。今年は育つかな。|我還是惦記著溫室裡的那些種子，不知道今年能不能種活。
我妈妈失踪以后，我把她留下的最后一包种子藏在温室里。这事一直没跟人说过。|After my mother went missing, I hid her last packet of seeds in the greenhouse. I haven’t told anyone until now.|お母さんが行方不明になってから、最後に残した種を温室に隠したの。今まで誰にも話せなかった。|我媽媽失蹤以後，我把她留下的最後一包種子藏在溫室裡。這事一直沒跟人說過。
种子发芽了！妈妈研究的办法真的有用。我想把这些办法也告诉镇上的人。|The seeds sprouted! Mum’s research really works. I want to share what she learned with everyone here.|芽が出たよ！ お母さんが研究してた方法、本当に役に立ったの。町の皆にも伝えたいな。|種子發芽了！媽媽研究的辦法真的有用。我想把這些辦法也告訴鎮上的人。
看到新芽的时候，我一下就哭了。我还是很想妈妈，但也想把她留下的种子好好种下去。|I cried when I saw the shoots. I still miss Mum, but I want to keep growing the seeds she left me.|芽を見たら、泣いちゃった。お母さんには会いたい。でも、残してくれた種も大事に育てたいの。|看到新芽的時候，我一下就哭了。我還是很想媽媽，但也想把她留下的種子好好種下去。
第一批四季种子已经分给大家了。温室门口的新牌子写着：春天是大家的。|I’ve shared the first seasonal seeds with everyone. The new greenhouse sign says: Spring belongs to everyone.|最初の四季の種を皆に分けたよ。温室の新しい看板には「みんなの春」って書いたの。|第一批四季種子已經分給大家了。溫室門口的新牌子寫著：春天是大家的。
温室又能种东西了。妈妈要是看见，肯定会高兴的。|The greenhouse is growing things again. Mum would be so happy to see it.|温室でまた作物が育ってる。お母さんが見たら、きっと喜ぶね。|溫室又能種東西了。媽媽要是看見，肯定會高興的。
''',
    'ember': '''
打铁这活儿急不来，火候不对，敲再多下也没用。|You can’t rush a forge. If the heat’s wrong, more hammering won’t help.|鍛冶は急いでもだめだ。火加減が違えば、何度打っても無駄になる。|打鐵這活兒急不來，火候不對，敲再多下也沒用。
这徽章是当年做月环零件时留下的。出了那次事故，我就再没敢做过灯架。|I kept this badge from when I made parts for the moonring. After the accident, I couldn’t bring myself to make lantern stands again.|この徽章は月環の部品を作った頃のものだ。事故のあと、灯の台を作る勇気がなくなった。|這徽章是當年做月環零件時留下的。出了那次事故，我就再沒敢做過燈架。
旧图纸查清楚了，是核心失控，不是灯架出了问题。不过坏了的那些灯，我还是想修好。|The old plans make it clear: the core ran out of control. The stands weren’t faulty. Still, I want to repair those broken lanterns.|図面でわかった。暴走したのは核で、灯の台のせいじゃなかった。それでも、壊れた灯は直したい。|舊圖紙查清楚了，是核心失控，不是燈架出了問題。不過壞了的那些燈，我還是想修好。
新镇钟装好了，那枚旧徽章也熔在里面了。留着总是难受，不如做点用得上的东西。|The new town bell is up. I melted the old badge into it. Keeping it hurt. I’d rather make something useful out of it.|新しい町の鐘ができた。古い徽章も溶かして入れたよ。持っているとつらいから、役立つものにしたかった。|新鎮鐘裝好了，那枚舊徽章也熔在裡面了。留著總是難受，不如做點用得上的東西。
镇钟一响，我也该出炉房歇歇了。我留了三块好铁，打算给自己造条小船。|Once that bell rings, it’s time I took a break from the forge. I’ve saved three good ingots to build myself a little boat.|鐘が鳴ったら、俺も炉を出て休まないとな。いい鉄を三つ取ってある。自分の小舟を作るつもりだ。|鎮鐘一響，我也該出爐房歇歇了。我留了三塊好鐵，打算給自己造條小船。
这回做的东西，镇上用得着。我也算放心了。|The town can use what I’m making now. That puts my mind at ease.|今作っているものは、町で役に立つ。それなら俺も安心だ。|這回做的東西，鎮上用得著。我也算放心了。
''',
    'nagi': '''
今天海风挺大，吹得我一身都是咸味。|That sea wind’s strong today. I’ve got salt all over me.|今日は海風が強いね。体中しょっぱくなっちゃった。|今天海風挺大，吹得我一身都是鹹味。
这张旧船票我一直没舍得扔。答应爸爸守码头以后，我就觉得自己再也不能出海了。|I never could throw this old ticket away. After promising Dad I’d look after the dock, I thought I could never sail again.|この古い船券、捨てられなくて。お父さんに桟橋を守るって約束してから、もう海に出ちゃいけないと思ってた。|這張舊船票我一直沒捨得扔。答應爸爸守碼頭以後，我就覺得自己再也不能出海了。
爸爸的漂流瓶居然回来了。信里说，海那边也有我的家。他没想把我一直留在码头。|Dad’s bottle actually washed back! His letter says I have a home across the sea too. He never meant to keep me at the dock forever.|お父さんの流した瓶が戻ってきたの。海の向こうにも私の家はあるって。ずっと桟橋にいろって意味じゃなかったんだね。|爸爸的漂流瓶居然回來了。信裡說，海那邊也有我的家。他沒想把我一直留在碼頭。
旧海图我重画好了，出发和回来的日期都写上了。出去看看，也不是不回来了。|I’ve redrawn the old chart and written down both my departure and return dates. Going away doesn’t mean I won’t come back.|古い海図を描き直して、出発日も帰る日も書いたよ。出かけるからって、帰らないわけじゃないもんね。|舊海圖我重畫好了，出發和回來的日期都寫上了。出去看看，也不是不回來了。
新航线通了，我也准备出海了。改好的钓竿留在岸上，这次我把回来的日子都定好了。|The new route’s open, and I’m ready to sail. I left the improved rod ashore. This time I know when I’m coming home.|新しい航路が開いて、私も出航の準備ができたよ。改良した竿は岸に置いてある。今度は帰る日も決めてるんだ。|新航線通了，我也準備出海了。改好的釣竿留在岸上，這次我把回來的日子都定好了。
航线恢复了，出去一趟也能回来。我总算不用那么担心了。|The route’s back. I can go away and come home again. That’s a relief.|航路が戻ったから、出かけても帰ってこられる。やっと安心できたよ。|航線恢復了，出去一趟也能回來。我總算不用那麼擔心了。
''',
    'lumi': '''
橱窗里摆的都是订货。我自己设计的那盏灯，还没敢拿出来。|Everything in the window is a customer order. I haven’t dared put out the lamp I designed myself.|窓にあるのは全部注文の品なの。自分で考えた灯は、まだ出す勇気がなくて。|櫥窗裡擺的都是訂貨。我自己設計的那盞燈，還沒敢拿出來。
我一直照着客人的要求做东西。自己设计的都藏在柜子里，怕人家说好看是好看，就是没用。|I’ve always made what customers ask for. My own designs stay in a cupboard. I’m afraid people will call them pretty but useless.|いつもお客さんの希望どおりに作ってるの。自分の作品は戸棚の中。きれいだけど役に立たないって言われるのが怖くて。|我一直照著客人的要求做東西。自己設計的都藏在櫃子裡，怕人家說好看是好看，就是沒用。
月纱灯挂进食堂以后，客人都舍不得走。还有人问是谁做的，真的记住了我的名字。|Since the moonveil lamp went up, guests stay longer. Someone even asked who made it. They actually remembered my name.|月紗の灯を食堂につけたら、お客さんが長くいてくれたの。誰が作ったのって聞かれて、名前まで覚えてくれたんだよ。|月紗燈掛進食堂以後，客人都捨不得走。還有人問是誰做的，真的記住了我的名字。
远方工坊那份仿制订单，我没接。我想留在这儿，做些自己设计、大家也喜欢的家具。|I turned down that distant workshop’s copying job. I want to stay here and make my own furniture, things people will enjoy.|遠い工房の模造の仕事は断ったの。ここに残って、自分で考えた、皆にも喜んでもらえる家具を作りたい。|遠方工坊那份仿製訂單，我沒接。我想留在這兒，做些自己設計、大家也喜歡的家具。
我的工坊开张了！这张月牙桌送给你，桌子底下还有大家的小签名呢。|My workshop’s open! This moon table is for you. Everyone’s little signatures are underneath.|私の工房、開店したよ！ この三日月テーブルは贈り物。裏には皆の小さなサインもあるんだ。|我的工坊開張了！這張月牙桌送給你，桌子底下還有大家的小簽名呢。
原来大家真的喜欢我做的东西。现在我敢把自己的作品摆出来了。|People really do like what I make. Now I’m ready to put my own designs on display.|私の作ったもの、本当に喜んでもらえたんだね。今なら、自分の作品も店に出せるよ。|原來大家真的喜歡我做的東西。現在我敢把自己的作品擺出來了。
''',
    'aster': '''
星图缺的那一块，我一直没补。每次看见，都会想起以前的事。|I still haven’t filled in that part of the chart. It brings back old memories every time I look at it.|星図の欠けたところ、まだ埋めてないんだ。見るたびに昔のことを思い出してしまって。|星圖缺的那一塊，我一直沒補。每次看見，都會想起以前的事。
姐姐失踪那晚的星位，就在观测记录最后一页。我每次写到那里，都会把那页撕掉。|The last observation page shows the stars on the night my sister vanished. Every time I reach that page, I tear it out.|姉が行方不明になった夜の星の位置が、観測帳の最後の頁にあるんだ。そこまで書くと、いつも破ってしまう。|姐姐失蹤那晚的星位，就在觀測記錄最後一頁。我每次寫到那裡，都會把那頁撕掉。
月晶里的记录是姐姐留下的。她当年把记忆留在月环里，是为了护住山谷。原来是这样……|The records in the crystals came from my sister. She left her memories in the moonring to protect the valley. So that’s what happened…|月晶の記録は姉が残したものだった。谷を守るために、月環に記憶を残したんだ。そうだったのか……。|月晶裡的記錄是姐姐留下的。她當年把記憶留在月環裡，是為了護住山谷。原來是這樣……
最后一页，我终于写完了。旁边还画了姐姐爱喝的茶。现在我不想再把它撕掉了。|I finally finished the last page. I drew my sister’s favorite tea beside it. I don’t want to tear it out anymore.|最後の頁、やっと書けたよ。姉の好きなお茶も隣に描いた。今はもう、破りたくないんだ。|最後一頁，我終於寫完了。旁邊還畫了姐姐愛喝的茶。現在我不想再把它撕掉了。
观星台重新开放了。我留下五枚月晶，第一堂公开课，就讲大家每天都能看见的这片星空吧。|The observatory’s open again. I’ve left five moon crystals. For the first public class, I’ll talk about the sky we can all see from here.|天文台をまた開いたよ。月晶を五つ残しておいた。最初の公開授業では、皆が毎日見られるこの星空の話をしようかな。|觀星臺重新開放了。我留下五枚月晶，第一堂公開課，就講大家每天都能看見的這片星空吧。
我还是会想姐姐。不过现在看星星的时候，心里没那么难受了。|I still miss my sister. But looking at the stars doesn’t hurt quite so much now.|姉には今も会いたい。でも星を見ても、前ほどつらくなくなったよ。|我還是會想姐姐。不過現在看星星的時候，心裡沒那麼難受了。
''',
    'toma': '''
这本旧食谱，我翻了不知道多少遍。有几处空着的地方，总想弄明白原来写了什么。|I’ve read this old recipe book more times than I can count. I keep wondering what used to be in those blank spots.|この古い料理帳、何度読んだかわからないよ。空いたところに何が書いてあったのか、気になってね。|這本舊食譜，我翻了不知道多少遍。有幾處空著的地方，總想弄明白原來寫了什麼。
我老伴走了以后，我总说自己不会做饭了。可她用过的那把汤勺，我到现在还天天擦。|After my wife died, I kept saying I couldn’t cook anymore. But I still polish her old soup spoon every day.|妻が亡くなってから、もう料理はできないと言ってた。でも、あの人のスープ用の匙は、今も毎日磨いてるんだ。|我老伴走了以後，我總說自己不會做飯了。可她用過的那把湯勺，我到現在還天天擦。
食谱边上有她写的小字：南瓜多放点，他爱吃甜的。我以前怎么就没注意到呢。|There’s a little note she wrote in the margin: more pumpkin, he likes it sweet. How did I never notice it before?|料理帳の端にあの人の字があった。「カボチャを多めに。あの人は甘いのが好き」。どうして今まで気づかなかったんだろうね。|食譜邊上有她寫的小字：南瓜多放點，他愛吃甜的。我以前怎麼就沒注意到呢。
这锅南瓜汤，跟她做的还是不一样。不过挺好喝，我又添了一碗。这味道也该记下来。|This pumpkin soup’s different from hers, but it’s good. I had another bowl. This recipe deserves a place in the book too.|このカボチャスープ、あの人の味とは違うね。でもおいしい。おかわりしたよ。この味も書き残したいな。|這鍋南瓜湯，跟她做的還是不一樣。不過挺好喝，我又添了一碗。這味道也該記下來。
早餐摊我又开起来了，面粉和牛奶也送进食堂了。新食谱的第一页，这回写的是我自己的名字。|I’ve reopened my breakfast stall and brought flour and milk to the eatery. The new recipe book starts with my own name this time.|朝ご飯の店をまた始めて、食堂に小麦粉と牛乳も届けたよ。新しい料理帳の最初には、今度は自分の名前を書いた。|早餐攤我又開起來了，麵粉和牛奶也送進食堂了。新食譜的第一頁，這回寫的是我自己的名字。
新菜单上也有我做的菜了。好久没这么盼着开饭了。|The new menu has my cooking on it too. I haven’t looked forward to dinner this much in years.|新しい献立には、私の料理もあるんだ。こんなに食事が楽しみなのは久しぶりだよ。|新菜單上也有我做的菜了。好久沒這麼盼著開飯了。
''',
    'pip': '''
遗址里那些旧齿轮，看着旧，其实不少还能用。|Those gears in the ruins look worn, but a lot of them still work.|遺跡の歯車、古そうだけど、まだ使えるものも多いんだよ。|遺址裡那些舊齒輪，看著舊，其實不少還能用。
我做的第一台机器，把汤甩得到处都是。太丢人了，连失败记录都让我塞进了废铁堆。|My first machine flung soup everywhere. I was so embarrassed, I hid even the failure notes in the scrap pile.|最初に作った機械、スープをそこら中に飛ばしちゃって。恥ずかしくて、失敗の記録まで鉄くずに隠したんだ。|我做的第一臺機器，把湯甩得到處都是。太丟人了，連失敗記錄都讓我塞進了廢鐵堆。
遗址里那本日志，原来是爷爷写的！字跟我真像。他没解决的问题，我也碰上了。|That logbook in the ruins was Grandpa’s! Our handwriting’s so alike. I’ve run into the same problems he never solved.|遺跡の記録帳、おじいちゃんが書いたものだった！ 字も僕とそっくり。おじいちゃんが解けなかった問題に、僕もぶつかってたんだ。|遺址裡那本日誌，原來是爺爺寫的！字跟我真像。他沒解決的問題，我也碰上了。
那个只顾着加速的核心，我拆掉了，换成限速器。这下机器总算不乱响了，还磨出了一袋面粉！|I took out the core that kept speeding up and fitted a limiter. Now the machine’s quiet, and it’s milled a whole bag of flour!|加速ばかりする核を外して、速度を抑える装置に替えたよ。やっと静かになって、小麦粉が一袋できた！|那個只顧著加速的核心，我拆掉了，換成限速器。這下機器總算不亂響了，還磨出了一袋麵粉！
新磨粉机放农场边了，铭牌也刻好了：省下的时间，留给想陪的人。以后我可不在炉边吃冷饭了。|The new mill’s beside the farm. Its plate says: save time for the people you care about. No more cold dinners by the furnace for me.|新しい粉ひき機を農場のそばに置いたよ。銘板には「大事な人と過ごす時間のために」って。もう炉の横で冷たいご飯は食べないぞ。|新磨粉機放農場邊了，銘牌也刻好了：省下的時間，留給想陪的人。以後我可不在爐邊吃冷飯了。
有机器帮忙，总算能按时吃饭了。这可比让它转得更快实在多了。|With the machines helping, I can finally eat on time. That’s better than just making them run faster.|機械のおかげで、やっと時間どおりにご飯を食べられるよ。ただ速くするより、ずっといいね。|有機器幫忙，總算能按時吃飯了。這可比讓它轉得更快實在多了。
''',
    'reed': '''
湿地里其实一直有动静。水声小了，鸟叫也比以前少了。|There’s still life in the marsh. But the water’s quieter, and there aren’t as many birds singing.|湿地には今も生き物がいるよ。でも水音も小さくなって、鳥の声も昔より減ったね。|濕地裡其實一直有動靜。水聲小了，鳥叫也比以前少了。
我每年都记回来过的候鸟。水道断了以后，这张单子就一年比一年短。|I record the birds that return each year. Since the water stopped flowing, the list has got shorter every year.|毎年、戻ってきた渡り鳥を書き留めてるんだ。水路が止まってから、年々その数が減っていてね。|我每年都記回來過的候鳥。水道斷了以後，這張單子就一年比一年短。
查出来了，水渠是让树根和生锈的闸门堵住了。泉眼还在，水是被堵在上游了。|We found the problem: roots and a rusted gate blocked the channel. The spring’s still there; the water was trapped upstream.|原因がわかったよ。木の根とさびた水門が水路をふさいでいた。泉は今もあって、水が上流で止まってたんだ。|查出來了，水渠是讓樹根和生鏽的閘門堵住了。泉眼還在，水是被堵在上游了。
莲塘有清水了，连好久没见的候鸟也回来了。我总算又能在单子上添一笔了。|Clean water’s back in the pond. A bird I hadn’t seen in ages returned too. I finally got to add a name to the list.|蓮池にきれいな水が戻って、久しく見なかった渡り鳥も来たよ。やっと名簿に一つ書き足せた。|蓮塘有清水了，連好久沒見的候鳥也回來了。我總算又能在單子上添一筆了。
新水车上都落了候鸟。我把洒水器送去农场了，那边和湿地用的是同一条水道。|The birds are already perching on the new waterwheel. I sent the sprinkler to the farm. It shares the marsh’s waterway now.|新しい水車に、もう渡り鳥がとまってるよ。農場に散水器を届けた。あそこも湿地と同じ水路を使ってるんだ。|新水車上都落了候鳥。我把灑水器送去農場了，那邊和濕地用的是同一條水道。
水道通了，鱼和鸟也慢慢回来了。湿地总算又像以前那样了。|The water’s flowing, and the fish and birds are coming back. The marsh is starting to feel like it used to.|水路が通って、魚も鳥も少しずつ戻った。湿地もやっと、昔の姿に近づいてきたね。|水道通了，魚和鳥也慢慢回來了。濕地總算又像以前那樣了。
''',
    'yuki': '''
山上那条邮路，我好久没走了。邮袋倒是一直放在手边。|I haven’t taken the mountain mail route in a long time. I still keep the mailbag beside me, though.|山の郵便道、ずいぶん歩いてないな。でも郵袋は、ずっと手元に置いてあるの。|山上那條郵路，我好久沒走了。郵袋倒是一直放在手邊。
我总拿山路不通当借口。其实是邮袋里那封信，我一直不敢拆，怕看完更难受。|I keep blaming the blocked mountain road. Really, I’m afraid to open that letter in my bag. I’m scared it’ll hurt too much.|いつも山道が通れないせいにしてた。本当は郵袋の手紙を開けるのが怖かったの。読んだらもっとつらくなりそうで。|我總拿山路不通當藉口。其實是郵袋裡那封信，我一直不敢拆，怕看完更難受。
信里是他画的温室图。他没有怪我没跟着走，还想着我留下来，冬天也能种花。|The letter had his greenhouse plans. He wasn’t upset that I stayed. He wanted me to be able to grow flowers here, even in winter.|手紙には彼の描いた温室の図面があった。ついていかなかった私を責めるどころか、ここでも冬に花を育てられるよう考えてくれてた。|信裡是他畫的溫室圖。他沒有怪我沒跟著走，還想著我留下來，冬天也能種花。
我写了好长一封回信，食堂重新开门、山脚开了什么花，全写进去了。写完真的轻松多了。|I wrote a long reply about the eatery reopening and the flowers at the foot of the mountain. I felt so much better afterward.|長い返事を書いたよ。食堂がまた開いたことも、山の麓の花のことも全部。書き終えたら、すごく楽になった。|我寫了好長一封回信，食堂重新開門、山腳開了什麼花，全寫進去了。寫完真的輕鬆多了。
最后一块玻璃装好了，温室里暖和得很。回信也寄出去了，还附上了第一束冬花。|The last pane’s in, and the greenhouse is lovely and warm. I sent my reply too, with the first winter flowers.|最後のガラスをはめたよ。温室の中、あったかいんだ。返事も出した。最初に咲いた冬の花を添えて。|最後一塊玻璃裝好了，溫室裡暖和得很。回信也寄出去了，還附上了第一束冬花。
回信总算寄出去了。我现在每天都想去看看温室里的花。|I finally sent that reply. Now I look forward to checking the greenhouse flowers every day.|やっと返事を出せたよ。今は毎日、温室の花を見るのが楽しみなんだ。|回信總算寄出去了。我現在每天都想去看看溫室裡的花。
''',
    'orla': '''
这几年走了不少人，食堂也空了不少座位。我总想着，什么时候大家还能聚一聚。|A lot of people have left these past few years. So many seats are empty now. I keep hoping we’ll all have dinner together again.|この数年で、町を出た人が増えたね。食堂の空席も増えた。また皆で集まれたらって、いつも思うの。|這幾年走了不少人，食堂也空了不少座位。我總想著，什麼時候大家還能聚一聚。
那封没署名的信是我写的。我没敢告诉你镇上的实情，怕你看到账本上的亏空，就不肯来了。|I wrote the unsigned letter. I didn’t dare tell you how things were. I was afraid the town’s debts would keep you away.|匿名の手紙は私が書いたの。町の実情を話す勇気がなかった。帳簿の赤字を見たら、来てくれないと思って。|那封沒署名的信是我寫的。我沒敢告訴你鎮上的實情，怕你看到帳本上的虧空，就不肯來了。
我翻了翻旧账本，才发现大家一直在互相帮忙。我老觉得什么都得自己扛，其实真不是。|Looking through the old accounts, I realized everyone’s been helping each other all along. I thought I had to carry it all myself. I didn’t.|古い帳簿を見て、皆がずっと助け合っていたと気づいたの。全部自分が背負わなきゃと思ってたけど、そうじゃなかった。|我翻了翻舊帳本，才發現大家一直在互相幫忙。我老覺得什麼都得自己扛，其實真不是。
修复计划放到长桌上以后，大家都添了自己的想法。这回总算不是我一个人在那儿发愁了。|Once I put the repair plans on the long table, everyone added their ideas. This time, I’m not worrying about it all alone.|修復の計画を長机に出したら、皆が考えを書き足してくれた。今度は一人で頭を抱えなくていいんだね。|修復計劃放到長桌上以後，大家都添了自己的想法。這回總算不是我一個人在那兒發愁了。
新账本的第一页，我记的是今晚聚餐的人数，不是欠款。这次我也给自己算了个位子。|The first page of the new ledger lists tonight’s dinner guests, not debts. I’ve counted a place for myself this time too.|新しい帳簿の最初には、借金じゃなく今夜の食事の人数を書いたの。今度は自分の席も数に入れたよ。|新帳本的第一頁，我記的是今晚聚餐的人數，不是欠款。這次我也給自己算了個位子。
镇上的灯全亮了。看着大家都在，我这心总算踏实了。|All the town’s lanterns are shining. Seeing everyone here, I can finally relax.|町の灯が全部ついた。皆がここにいるのを見ると、やっと安心できるよ。|鎮上的燈全亮了。看著大家都在，我這心總算踏實了。
''',
}
for npc in before['npcs']:
    assign([npc['lines'][0], *npc['events'], npc['lines'][4]], npc_copy[npc['id']])


def rewrite_source(path, aliases):
    source = path.read_bytes()
    lines = source.splitlines(keepends=True)
    offsets = [0]
    for line in lines:
        offsets.append(offsets[-1] + len(line))
    tree = ast.parse(source.decode('utf-8'))
    edits = {}
    found = set()
    for node in ast.walk(tree):
        values = node.elts if isinstance(node, (ast.Tuple, ast.List)) else node.args if isinstance(node, ast.Call) else []
        for start in range(len(values) - 3):
            chunk = values[start:start + 4]
            if not all(isinstance(value, ast.Constant) and isinstance(value.value, str) for value in chunk):
                continue
            key = aliases.get(chunk[0].value, chunk[0].value)
            if key not in replacements:
                continue
            found.add(key)
            for value, new in zip(chunk, replacements[key]):
                position = (offsets[value.lineno - 1] + value.col_offset,
                            offsets[value.end_lineno - 1] + value.end_col_offset)
                encoded = json.dumps(new, ensure_ascii=False).encode('utf-8')
                assert position not in edits or edits[position] == encoded
                edits[position] = encoded
    for (start, end), value in sorted(edits.items(), reverse=True):
        source = source[:start] + value + source[end:]
    ast.parse(source.decode('utf-8'))
    return source, found


rewrite_path = ROOT / 'Scenes/Campaign/dialogue_rewrites.json'
aliases = json.loads(rewrite_path.read_text(encoding='utf-8'))
pending = {}
found = set()
for rel in ['Scenes/Campaign/story_content.py', 'Scenes/Campaign/build_content.py']:
    content, keys = rewrite_source(ROOT / rel, aliases)
    pending[ROOT / rel] = content
    found.update(keys)
assert found == replacements.keys(), replacements.keys() - found

# Retain legacy aliases for older authored keys; all new text lives in its source tuple.
for key, value in aliases.items():
    if value in replacements:
        aliases[key] = replacements[value][0]
pending[rewrite_path] = (json.dumps(aliases, ensure_ascii=False, indent=2) + '\n').encode('utf-8')

guide_path = ROOT / 'Scenes/Campaign/guide_profile.gd'
guide_source = guide_path.read_bytes()
old_ready = '这一页的心愿已经实现。'
assert old_ready.encode('utf-8') in guide_source
pending[guide_path] = guide_source.replace(old_ready.encode('utf-8'), replacements[old_ready][0].encode('utf-8'))

catalog_path = ROOT / 'Localization/messages.tsv'
with catalog_path.open(encoding='utf-8', newline='') as handle:
    catalog = list(csv.reader(handle, delimiter='\t'))
updated = [catalog[0]]
seen = {}
for row in catalog[1:]:
    row = replacements.get(row[0], row)
    if row[0] in seen:
        assert seen[row[0]] == row, row
        continue
    seen[row[0]] = row
    updated.append(row)

for path, content in pending.items():
    path.write_bytes(content)
with catalog_path.open('w', encoding='utf-8', newline='') as handle:
    csv.writer(handle, delimiter='\t', lineterminator='\n').writerows(updated)
(OUT / 'reviewed_replacements.json').write_text(json.dumps(replacements, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('REVIEWED_REWRITES', len(replacements), 'SOURCES_UPDATED', len(pending), 'CATALOG_ROWS', len(updated) - 1)
