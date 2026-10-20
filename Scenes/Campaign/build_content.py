"""Author original campaign content and register all four UI languages. Idempotent."""
import csv
import json
from pathlib import Path
from cooking_expansion import expand
from story_content import expand_story
from rebuilt_story import rebuild_story

ROOT = Path(__file__).resolve().parents[2]
TEXT = {}


def t(zh, en, ja, tw):
    TEXT[zh] = [zh, en, ja, tw]
    return zh


seasons = [t('春','Spring','春','春'), t('夏','Summer','夏','夏'), t('秋','Autumn','秋','秋'), t('冬','Winter','冬','冬')]
# id, four names, seasons, days, regrow, seed price, sell price, yield, color, silhouette
crop_rows = [
 ('herb',('香草','Herb','ハーブ','香草'),[0,1,2,3],3,0,2,3,1,'9bba75','leaf'),
 ('turnip',('月白萝卜','Moon Turnip','月白カブ','月白蘿蔔'),[0],3,0,4,11,1,'e8d6b7','root'),
 ('carrot',('琥珀胡萝卜','Amber Carrot','琥珀ニンジン','琥珀胡蘿蔔'),[0,2],4,0,5,15,1,'dd9658','carrot'),
 ('lettuce',('翡翠生菜','Jade Lettuce','翡翠レタス','翡翠生菜'),[0],4,0,5,14,1,'9ecb7d','leaf'),
 ('pea',('铃铛豌豆','Bell Pea','鈴エンドウ','鈴鐺豌豆'),[0],5,2,9,8,2,'9abf7f','pod'),
 ('strawberry',('露珠草莓','Dew Strawberry','露イチゴ','露珠草莓'),[0],6,3,14,12,2,'dd778c','berry'),
 ('rice',('星穗稻','Star Rice','星穂米','星穗稻'),[0,1],6,0,8,18,2,'e6cb8a','grain'),
 ('tomato',('绯红番茄','Scarlet Tomato','緋トマト','緋紅番茄'),[1],5,2,12,10,2,'d77765','round'),
 ('corn',('金羽玉米','Golden Corn','金羽トウモロコシ','金羽玉米'),[1,2],7,3,14,15,2,'edce79','corn'),
 ('cucumber',('青玉黄瓜','Jade Cucumber','青玉キュウリ','青玉黃瓜'),[1],4,2,9,9,2,'6fa486','long'),
 ('pepper',('焰心辣椒','Ember Pepper','炎心トウガラシ','焰心辣椒'),[1],5,2,10,10,2,'cb6b60','pepper'),
 ('melon',('蜜月甜瓜','Honey Melon','蜜月メロン','蜜月甜瓜'),[1],9,0,20,55,1,'d9c784','round'),
 ('eggplant',('紫绸茄子','Silk Eggplant','紫絹ナス','紫綢茄子'),[2],5,3,10,14,2,'9276ae','long'),
 ('pumpkin',('灯笼南瓜','Lantern Pumpkin','灯カボチャ','燈籠南瓜'),[2],8,0,16,43,1,'dda269','pumpkin'),
 ('sweet_potato',('暖砂红薯','Warm Sweet Potato','暖砂サツマイモ','暖砂紅薯'),[2],5,0,8,22,1,'be8297','root'),
 ('wheat',('风铃小麦','Chime Wheat','風鈴小麦','風鈴小麥'),[1,2],4,0,5,10,2,'dfc995','grain'),
 ('tea',('雾叶茶','Mist Tea','霧葉茶','霧葉茶'),[0,1,2],7,3,18,13,2,'7ba98c','leaf'),
 ('snow_cabbage',('雪心白菜','Snow Cabbage','雪心ハクサイ','雪心白菜'),[3],5,0,8,23,1,'c7ded1','leaf'),
 ('winter_radish',('霜晶萝卜','Frost Radish','霜晶ダイコン','霜晶蘿蔔'),[3],4,0,7,20,1,'cfdeeb','root'),
 ('moonflower',('月光花','Moonflower','月光花','月光花'),[2,3],8,0,18,48,1,'b5a2d6','flower'),
]
crops = []
for id,names,ss,days,regrow,buy,sell,yield_,color,shape in crop_rows:
    crops.append(dict(id=id,name=t(*names),seasons=ss,days=days,regrow=regrow,buy=buy,sell=sell,yield_count=yield_,color=color,shape=shape))

item_rows = [
 ('mushroom',('蘑菇','Mushroom','キノコ','蘑菇'),4,'be9e69','mushroom'),
 ('berry',('莓果','Berry','ベリー','莓果'),4,'c87898','berry'),
 ('egg',('鸡蛋','Egg','卵','雞蛋'),5,'f3dfbb','egg'),
 ('milk',('牛奶','Milk','牛乳','牛奶'),6,'dee7dc','bottle'),
 ('flour',('面粉','Flour','小麦粉','麵粉'),4,'e8d9b7','bag'),
 ('oil',('食用油','Cooking Oil','食用油','食用油'),4,'cdb06c','bottle'),
 ('salt',('海盐','Sea Salt','海塩','海鹽'),2,'d8dbe5','bag'),
 ('honey',('野蜂蜜','Wild Honey','野の蜂蜜','野蜂蜜'),8,'e1b76f','jar'),
 ('bamboo',('春笋','Bamboo Shoot','タケノコ','春筍'),5,'b7ba83','pod'),
 ('lotus',('莲藕','Lotus Root','レンコン','蓮藕'),6,'d9cba5','root'),
 ('chestnut',('山栗','Chestnut','山栗','山栗'),6,'a58066','round'),
 ('truffle',('松露','Truffle','トリュフ','松露'),12,'887589','mushroom'),
 ('crystal',('月晶','Moon Crystal','月晶','月晶'),15,'baa8e1','crystal'),
 ('scrap',('旧械零件','Old Machine Part','古い機械部品','舊械零件'),5,'9aabb6','gear'),
 ('wood',('木材','Wood','木材','木材'),1,'b68f68','log'),
 ('ore',('矿石','Ore','鉱石','礦石'),3,'929baa','crystal'),
 ('iron',('铁锭','Iron Ingot','鉄の延べ棒','鐵錠'),8,'bcc7ce','bar'),
]
items = {c['id']:dict(c) for c in crops}
for id,names,sell,color,shape in item_rows:
    items[id]=dict(id=id,name=t(*names),buy=sell*2,sell=sell,color=color,shape=shape)
fish_rows = [
 ('silverfin',('银鳞鱼','Silverfin','銀鱗魚','銀鱗魚'),'field',[0,1,2,3],6,18,1,10,'b9d1db'),
 ('brook_carp',('溪花鲤','Brook Carp','渓花コイ','溪花鯉'),'grove',[0,1],6,18,2,14,'dcb794'),
 ('moon_bass',('月影鲈','Moon Bass','月影スズキ','月影鱸'),'dock',[0,1,2,3],12,18,3,22,'aab8d2'),
 ('prawn',('潮汐虾','Tidal Prawn','潮エビ','潮汐蝦'),'dock',[1,2],6,18,2,16,'dfaaa2'),
 ('eel',('雨纹鳗','Rain Eel','雨紋ウナギ','雨紋鰻'),'marsh',[0,1,2],6,18,4,30,'a598b6'),
 ('lotus_fish',('莲灯鱼','Lotus Lanternfish','蓮灯魚','蓮燈魚'),'marsh',[1],12,18,4,36,'e2bccf'),
 ('ice_char',('霜尾鳟','Frost Char','霜尾マス','霜尾鱒'),'ridge',[3],6,18,3,25,'c4deed'),
 ('star_koi',('星河锦鲤','Star Koi','星河ニシキゴイ','星河錦鯉'),'observatory',[0,1,2,3],15,18,5,50,'d5c3eb'),
]
fishes=[]
for id,names,area,ss,start,end,difficulty,sell,color in fish_rows:
    f=dict(id=id,name=t(*names),area=area,seasons=ss,start=start,end=end,difficulty=difficulty,sell=sell,color=color,shape='fish',buy=sell*2)
    fishes.append(f); items[id]=dict(f)

tags={}
for id,names in [ ('warm',('暖食','Warm','温かい','暖食')),('sweet',('甜味','Sweet','甘味','甜味')),('vegetable',('素食','Vegetarian','菜食','素食')),('fish',('鱼鲜','Fish','魚料理','魚鮮')),('spicy',('辛香','Spicy','辛味','辛香')),('light',('清淡','Light','薄味','清淡')),('tea',('茶香','Tea','茶の香り','茶香')),('rare',('珍馐','Rare','珍味','珍饈')) ]:
    tags[id]=t(*names)
recipe_rows = [
 ('mushroom_soup',('蘑菇汤','Mushroom Soup','キノコスープ','蘑菇湯'),{'mushroom':2},12,['warm','vegetable'],0,'pot'),
 ('berry_pie',('莓果派','Berry Pie','ベリーパイ','莓果派'),{'berry':2},14,['sweet'],0,'oven'),
 ('herb_stew',('香草炖菇','Herb Mushroom Stew','ハーブキノコ煮','香草燉菇'),{'mushroom':1,'herb':1},18,['warm','vegetable'],0,'pot'),
 ('turnip_soup',('月白萝卜汤','Moon Turnip Soup','月白カブスープ','月白蘿蔔湯'),{'turnip':2,'salt':1},30,['warm','light'],0,'pot'),
 ('carrot_salad',('琥珀田园沙拉','Amber Garden Salad','琥珀サラダ','琥珀田園沙拉'),{'carrot':1,'lettuce':1,'oil':1},32,['vegetable','light'],0,'board'),
 ('pea_rice',('铃铛豌豆饭','Bell Pea Rice','鈴エンドウご飯','鈴鐺豌豆飯'),{'pea':1,'rice':1,'salt':1},38,['warm','vegetable'],0,'pot'),
 ('strawberry_tart',('露珠草莓挞','Dew Strawberry Tart','露イチゴタルト','露珠草莓塔'),{'strawberry':1,'flour':1,'milk':1},44,['sweet'],1,'oven'),
 ('bamboo_rice',('春笋香饭','Bamboo Rice','タケノコご飯','春筍香飯'),{'bamboo':1,'rice':1},34,['vegetable','light'],0,'pot'),
 ('herb_omelet',('香草煎蛋','Herb Omelet','ハーブオムレツ','香草煎蛋'),{'herb':1,'egg':1,'oil':1},28,['warm'],0,'pan'),
 ('berry_milk',('莓果牛乳','Berry Milk','ベリーミルク','莓果牛乳'),{'berry':1,'milk':1},24,['sweet'],0,'kettle'),
 ('tomato_noodle',('绯红番茄面','Scarlet Tomato Noodles','緋トマト麺','緋紅番茄麵'),{'tomato':2,'flour':1},42,['warm','vegetable'],0,'pot'),
 ('corn_soup',('金羽玉米浓汤','Golden Corn Chowder','金羽コーンスープ','金羽玉米濃湯'),{'corn':1,'milk':1},38,['warm','sweet'],0,'pot'),
 ('cucumber_roll',('青玉凉卷','Jade Cool Rolls','青玉涼巻き','青玉涼捲'),{'cucumber':1,'rice':1},32,['vegetable','light'],0,'board'),
 ('pepper_fish',('焰心香煎鱼','Ember Pan Fish','炎心焼き魚','焰心香煎魚'),{'silverfin':1,'pepper':1,'oil':1},46,['fish','spicy'],1,'pan'),
 ('melon_ice',('蜜月冰沙','Honey Melon Ice','蜜月シャーベット','蜜月冰沙'),{'melon':1,'honey':1},78,['sweet'],1,'board'),
 ('prawn_rice',('潮汐虾饭','Tidal Prawn Rice','潮エビご飯','潮汐蝦飯'),{'prawn':1,'rice':1},52,['fish','warm'],1,'pot'),
 ('lotus_salad',('莲塘凉拌','Lotus Pond Salad','蓮池和え','蓮塘涼拌'),{'lotus':1,'cucumber':1,'salt':1},42,['vegetable','light'],0,'board'),
 ('eggplant_pan',('紫绸煎茄','Silk Pan Eggplant','紫絹焼きナス','紫綢煎茄'),{'eggplant':2,'oil':1},44,['vegetable','warm'],1,'pan'),
 ('pumpkin_stew',('灯笼南瓜煲','Lantern Pumpkin Stew','灯カボチャ煮','燈籠南瓜煲'),{'pumpkin':1,'milk':1},64,['warm','sweet'],1,'pot'),
 ('sweet_potato_roast',('暖砂烤红薯','Warm Roast Sweet Potato','暖砂焼き芋','暖砂烤紅薯'),{'sweet_potato':2},50,['sweet','warm'],1,'oven'),
 ('chestnut_rice',('山栗焖饭','Chestnut Rice','山栗ご飯','山栗燜飯'),{'chestnut':1,'rice':1},44,['warm','vegetable'],1,'pot'),
 ('wheat_bread',('风铃面包','Chime Bread','風鈴パン','風鈴麵包'),{'wheat':2,'milk':1},44,['warm'],1,'oven'),
 ('truffle_pasta',('松露奶油面','Truffle Cream Pasta','トリュフクリーム麺','松露奶油麵'),{'truffle':1,'flour':1,'milk':1},72,['rare','warm'],2,'pot'),
 ('snow_cabbage_pot',('雪心暖锅','Snow Cabbage Hotpot','雪心鍋','雪心暖鍋'),{'snow_cabbage':2,'mushroom':1},60,['warm','vegetable'],1,'pot'),
 ('winter_radish_broth',('霜晶清汤','Frost Clear Broth','霜晶澄まし汁','霜晶清湯'),{'winter_radish':2,'salt':1},52,['warm','light'],1,'pot'),
 ('moonflower_cake',('月光花糕','Moonflower Cake','月光花菓子','月光花糕'),{'moonflower':1,'flour':1,'honey':1},88,['sweet','rare'],2,'oven'),
 ('mist_tea',('雾叶清茶','Mist Leaf Tea','霧葉茶湯','霧葉清茶'),{'tea':1},22,['tea','light'],0,'kettle'),
 ('honey_tea',('蜜香花茶','Honey Blossom Tea','蜜花茶','蜜香花茶'),{'tea':1,'honey':1},38,['tea','sweet'],1,'kettle'),
 ('carp_broth',('溪花鱼羹','Brook Carp Broth','渓花コイ汁','溪花魚羹'),{'brook_carp':1,'herb':1},44,['fish','light'],1,'pot'),
 ('moon_bass_grill',('月影烤鲈','Moon Bass Grill','月影スズキ焼き','月影烤鱸'),{'moon_bass':1,'salt':1},54,['fish','warm'],1,'pan'),
 ('eel_rice',('雨纹鳗鱼饭','Rain Eel Rice','雨紋ウナギご飯','雨紋鰻魚飯'),{'eel':1,'rice':1,'oil':1},72,['fish','warm'],2,'pan'),
 ('lotus_fish_steam',('莲灯清蒸','Steamed Lanternfish','蓮灯魚蒸し','蓮燈清蒸'),{'lotus_fish':1,'lotus':1},88,['fish','rare','light'],2,'pot'),
 ('ice_char_roast',('霜尾香烤','Roast Frost Char','霜尾マス焼き','霜尾香烤'),{'ice_char':1,'herb':1},62,['fish','warm'],2,'oven'),
 ('star_koi_banquet',('星河宴','Star River Banquet','星河の宴','星河宴'),{'star_koi':1,'moonflower':1,'rice':1},140,['fish','rare'],3,'pot'),
 ('four_seasons_platter',('四季团圆盘','Four Seasons Platter','四季団らん皿','四季團圓盤'),{'turnip':1,'tomato':1,'pumpkin':1,'snow_cabbage':1},130,['vegetable','rare'],3,'board'),
 ('lantern_dessert',('万家灯火甜点','Lantern Home Dessert','万家灯火デザート','萬家燈火甜點'),{'strawberry':1,'moonflower':1,'milk':1,'honey':1},110,['sweet','rare'],3,'oven'),
]
recipes=[]
for i,(id,names,cost,price,tt,tier,station) in enumerate(recipe_rows):
    recipes.append(dict(id=id,name=t(*names),cost=cost,price=price,tags=tt,tier=tier,station=station,seconds=3 if i<3 else 3+tier,color=['cba571','c77b99','91af78','e4ce96'][i%4],shape=['soup','pie','plate','cup'][i%4]))

npc_rows=[
 ('mori',('茉莉','Mori','モリ','茉莉'),'grove',['vegetable','tea'],'spicy','tea',0,'7c9c7a','braids',("我还是惦记着温室里的那些种子，不知道今年能不能种活。","I keep thinking about the greenhouse seeds. I wonder if they’ll grow this year.","温室の種が気になるの。今年は育つかな。","我還是惦記著溫室裡的那些種子，不知道今年能不能種活。"),("温室又能种东西了。妈妈要是看见，肯定会高兴的。","The greenhouse is growing things again. Mum would be so happy to see it.","温室でまた作物が育ってる。お母さんが見たら、きっと喜ぶね。","溫室又能種東西了。媽媽要是看見，肯定會高興的。")),
 ('ember',('余烬','Ember','エンバー','餘燼'),'quarry',['warm','spicy'],'sweet','pepper',3,'b68b76','short',("打铁这活儿急不来，火候不对，敲再多下也没用。","You can’t rush a forge. If the heat’s wrong, more hammering won’t help.","鍛冶は急いでもだめだ。火加減が違えば、何度打っても無駄になる。","打鐵這活兒急不來，火候不對，敲再多下也沒用。"),("这回做的东西，镇上用得着。我也算放心了。","The town can use what I’m making now. That puts my mind at ease.","今作っているものは、町で役に立つ。それなら俺も安心だ。","這回做的東西，鎮上用得著。我也算放心了。")),
 ('nagi',('澪','Nagi','ナギ','澪'),'dock',['fish','light'],'spicy','moon_bass',1,'7b9eb9','bob',("今天海风挺大，吹得我一身都是咸味。","That sea wind’s strong today. I’ve got salt all over me.","今日は海風が強いね。体中しょっぱくなっちゃった。","今天海風挺大，吹得我一身都是鹹味。"),("航线恢复了，出去一趟也能回来。我总算不用那么担心了。","The route’s back. I can go away and come home again. That’s a relief.","航路が戻ったから、出かけても帰ってこられる。やっと安心できたよ。","航線恢復了，出去一趟也能回來。我總算不用那麼擔心了。")),
 ('lumi',('露米','Lumi','ルミ','露米'),'town',['sweet','tea'],'spicy','strawberry',5,'bc92ad','long',("橱窗里摆的都是订货。我自己设计的那盏灯，还没敢拿出来。","Everything in the window is a customer order. I haven’t dared put out the lamp I designed myself.","窓にあるのは全部注文の品なの。自分で考えた灯は、まだ出す勇気がなくて。","櫥窗裡擺的都是訂貨。我自己設計的那盞燈，還沒敢拿出來。"),("原来大家真的喜欢我做的东西。现在我敢把自己的作品摆出来了。","People really do like what I make. Now I’m ready to put my own designs on display.","私の作ったもの、本当に喜んでもらえたんだね。今なら、自分の作品も店に出せるよ。","原來大家真的喜歡我做的東西。現在我敢把自己的作品擺出來了。")),
 ('aster',('星芒','Aster','アスター','星芒'),'observatory',['rare','tea'],'spicy','moonflower',4,'8aa7ad','locks',("星图缺的那一块，我一直没补。每次看见，都会想起以前的事。","I still haven’t filled in that part of the chart. It brings back old memories every time I look at it.","星図の欠けたところ、まだ埋めてないんだ。見るたびに昔のことを思い出してしまって。","星圖缺的那一塊，我一直沒補。每次看見，都會想起以前的事。"),("我还是会想姐姐。不过现在看星星的时候，心里没那么难受了。","I still miss my sister. But looking at the stars doesn’t hurt quite so much now.","姉には今も会いたい。でも星を見ても、前ほどつらくなくなったよ。","我還是會想姐姐。不過現在看星星的時候，心裡沒那麼難受了。")),
 ('toma',('陶陶','Toma','トマ','陶陶'),'town',['warm','vegetable'],'rare','pumpkin',2,'b18499','curls',("这本旧食谱，我翻了不知道多少遍。有几处空着的地方，总想弄明白原来写了什么。","I’ve read this old recipe book more times than I can count. I keep wondering what used to be in those blank spots.","この古い料理帳、何度読んだかわからないよ。空いたところに何が書いてあったのか、気になってね。","這本舊食譜，我翻了不知道多少遍。有幾處空著的地方，總想弄明白原來寫了什麼。"),("新菜单上也有我做的菜了。好久没这么盼着开饭了。","The new menu has my cooking on it too. I haven’t looked forward to dinner this much in years.","新しい献立には、私の料理もあるんだ。こんなに食事が楽しみなのは久しぶりだよ。","新菜單上也有我做的菜了。好久沒這麼盼著開飯了。")),
 ('pip',('皮普','Pip','ピップ','皮普'),'ruins',['spicy','warm'],'light','corn',3,'c5a16f','short',("遗址里那些旧齿轮，看着旧，其实不少还能用。","Those gears in the ruins look worn, but a lot of them still work.","遺跡の歯車、古そうだけど、まだ使えるものも多いんだよ。","遺址裡那些舊齒輪，看著舊，其實不少還能用。"),("有机器帮忙，总算能按时吃饭了。这可比让它转得更快实在多了。","With the machines helping, I can finally eat on time. That’s better than just making them run faster.","機械のおかげで、やっと時間どおりにご飯を食べられるよ。ただ速くするより、ずっといいね。","有機器幫忙，總算能按時吃飯了。這可比讓它轉得更快實在多了。")),
 ('reed',('芦苇','Reed','リード','蘆葦'),'marsh',['light','vegetable'],'fish','lotus',0,'89a590','braids',("湿地里其实一直有动静。水声小了，鸟叫也比以前少了。","There’s still life in the marsh. But the water’s quieter, and there aren’t as many birds singing.","湿地には今も生き物がいるよ。でも水音も小さくなって、鳥の声も昔より減ったね。","濕地裡其實一直有動靜。水聲小了，鳥叫也比以前少了。"),("水道通了，鱼和鸟也慢慢回来了。湿地总算又像以前那样了。","The water’s flowing, and the fish and birds are coming back. The marsh is starting to feel like it used to.","水路が通って、魚も鳥も少しずつ戻った。湿地もやっと、昔の姿に近づいてきたね。","水道通了，魚和鳥也慢慢回來了。濕地總算又像以前那樣了。")),
 ('yuki',('霜铃','Yuki','ユキ','霜鈴'),'ridge',['warm','sweet'],'spicy','snow_cabbage',1,'b4b8d2','bob',("山上那条邮路，我好久没走了。邮袋倒是一直放在手边。","I haven’t taken the mountain mail route in a long time. I still keep the mailbag beside me, though.","山の郵便道、ずいぶん歩いてないな。でも郵袋は、ずっと手元に置いてあるの。","山上那條郵路，我好久沒走了。郵袋倒是一直放在手邊。"),("回信总算寄出去了。我现在每天都想去看看温室里的花。","I finally sent that reply. Now I look forward to checking the greenhouse flowers every day.","やっと返事を出せたよ。今は毎日、温室の花を見るのが楽しみなんだ。","回信總算寄出去了。我現在每天都想去看看溫室裡的花。")),
 ('orla',('奥萝','Orla','オルラ','奧蘿'),'town',['tea','rare'],'spicy','honey',4,'b9a481','locks',("这几年走了不少人，食堂也空了不少座位。我总想着，什么时候大家还能聚一聚。","A lot of people have left these past few years. So many seats are empty now. I keep hoping we’ll all have dinner together again.","この数年で、町を出た人が増えたね。食堂の空席も増えた。また皆で集まれたらって、いつも思うの。","這幾年走了不少人，食堂也空了不少座位。我總想著，什麼時候大家還能聚一聚。"),("镇上的灯全亮了。看着大家都在，我这心总算踏实了。","All the town’s lanterns are shining. Seeing everyone here, I can finally relax.","町の灯が全部ついた。皆がここにいるのを見ると、やっと安心できるよ。","鎮上的燈全亮了。看著大家都在，我這心總算踏實了。")),
]
npcs=[]
for index,(id,names,area,likes,dislike,gift,variant,color,hair,first,last) in enumerate(npc_rows):
    # Every character has five affinity stages and four item/story milestones.
    middle=[
     t(f'这里的晚餐让我想起很久以前的事。', 'Dinner here brings back old memories.','ここの夕食は昔を思い出させる。','這裡的晚餐讓我想起很久以前的事。'),
     t('有些往事，现在终于能说出口了。','I can finally speak about some of the past.','ようやく話せる思い出もある。','有些往事，現在終於能說出口了。'),
     t('我开始期待明天的小镇了。','I am looking forward to tomorrow in town.','町の明日が楽しみになった。','我開始期待明天的小鎮了。')]
    story_titles=[t(names[0]+'的旧物',names[1]+'’s Keepsake',names[2]+'の形見',names[3]+'的舊物'),t(names[0]+'的牵挂',names[1]+'’s Concern',names[2]+'の気がかり',names[3]+'的牽掛'),t(names[0]+'的约定',names[1]+'’s Promise',names[2]+'の約束',names[3]+'的約定'),t(names[0]+'的新生活',names[1]+'’s New Life',names[2]+'の新生活',names[3]+'的新生活')]
    npcs.append(dict(id=id,name=t(*names),area=area,likes=likes,dislike=dislike,gift=gift,variant=variant,color=color,hair_style=hair,birthday=[index%4,3+index*2],lines=[t(*first),*middle,t(*last)],stories=story_titles))

event_rows={
 'mori':[
  ("我妈妈失踪以后，我把她留下的最后一包种子藏在温室里。这事一直没跟人说过。","After my mother went missing, I hid her last packet of seeds in the greenhouse. I haven’t told anyone until now.","お母さんが行方不明になってから、最後に残した種を温室に隠したの。今まで誰にも話せなかった。","我媽媽失蹤以後，我把她留下的最後一包種子藏在溫室裡。這事一直沒跟人說過。"),
  ("种子发芽了！妈妈研究的办法真的有用。我想把这些办法也告诉镇上的人。","The seeds sprouted! Mum’s research really works. I want to share what she learned with everyone here.","芽が出たよ！ お母さんが研究してた方法、本当に役に立ったの。町の皆にも伝えたいな。","種子發芽了！媽媽研究的辦法真的有用。我想把這些辦法也告訴鎮上的人。"),
  ("看到新芽的时候，我一下就哭了。我还是很想妈妈，但也想把她留下的种子好好种下去。","I cried when I saw the shoots. I still miss Mum, but I want to keep growing the seeds she left me.","芽を見たら、泣いちゃった。お母さんには会いたい。でも、残してくれた種も大事に育てたいの。","看到新芽的時候，我一下就哭了。我還是很想媽媽，但也想把她留下的種子好好種下去。"),
  ("第一批四季种子已经分给大家了。温室门口的新牌子写着：春天是大家的。","I’ve shared the first seasonal seeds with everyone. The new greenhouse sign says: Spring belongs to everyone.","最初の四季の種を皆に分けたよ。温室の新しい看板には「みんなの春」って書いたの。","第一批四季種子已經分給大家了。溫室門口的新牌子寫著：春天是大家的。")],
 'ember':[
  ("这徽章是当年做月环零件时留下的。出了那次事故，我就再没敢做过灯架。","I kept this badge from when I made parts for the moonring. After the accident, I couldn’t bring myself to make lantern stands again.","この徽章は月環の部品を作った頃のものだ。事故のあと、灯の台を作る勇気がなくなった。","這徽章是當年做月環零件時留下的。出了那次事故，我就再沒敢做過燈架。"),
  ("旧图纸查清楚了，是核心失控，不是灯架出了问题。不过坏了的那些灯，我还是想修好。","The old plans make it clear: the core ran out of control. The stands weren’t faulty. Still, I want to repair those broken lanterns.","図面でわかった。暴走したのは核で、灯の台のせいじゃなかった。それでも、壊れた灯は直したい。","舊圖紙查清楚了，是核心失控，不是燈架出了問題。不過壞了的那些燈，我還是想修好。"),
  ("新镇钟装好了，那枚旧徽章也熔在里面了。留着总是难受，不如做点用得上的东西。","The new town bell is up. I melted the old badge into it. Keeping it hurt. I’d rather make something useful out of it.","新しい町の鐘ができた。古い徽章も溶かして入れたよ。持っているとつらいから、役立つものにしたかった。","新鎮鐘裝好了，那枚舊徽章也熔在裡面了。留著總是難受，不如做點用得上的東西。"),
  ("镇钟一响，我也该出炉房歇歇了。我留了三块好铁，打算给自己造条小船。","Once that bell rings, it’s time I took a break from the forge. I’ve saved three good ingots to build myself a little boat.","鐘が鳴ったら、俺も炉を出て休まないとな。いい鉄を三つ取ってある。自分の小舟を作るつもりだ。","鎮鐘一響，我也該出爐房歇歇了。我留了三塊好鐵，打算給自己造條小船。")],
 'nagi':[
  ("这张旧船票我一直没舍得扔。答应爸爸守码头以后，我就觉得自己再也不能出海了。","I never could throw this old ticket away. After promising Dad I’d look after the dock, I thought I could never sail again.","この古い船券、捨てられなくて。お父さんに桟橋を守るって約束してから、もう海に出ちゃいけないと思ってた。","這張舊船票我一直沒捨得扔。答應爸爸守碼頭以後，我就覺得自己再也不能出海了。"),
  ("爸爸的漂流瓶居然回来了。信里说，海那边也有我的家。他没想把我一直留在码头。","Dad’s bottle actually washed back! His letter says I have a home across the sea too. He never meant to keep me at the dock forever.","お父さんの流した瓶が戻ってきたの。海の向こうにも私の家はあるって。ずっと桟橋にいろって意味じゃなかったんだね。","爸爸的漂流瓶居然回來了。信裡說，海那邊也有我的家。他沒想把我一直留在碼頭。"),
  ("旧海图我重画好了，出发和回来的日期都写上了。出去看看，也不是不回来了。","I’ve redrawn the old chart and written down both my departure and return dates. Going away doesn’t mean I won’t come back.","古い海図を描き直して、出発日も帰る日も書いたよ。出かけるからって、帰らないわけじゃないもんね。","舊海圖我重畫好了，出發和回來的日期都寫上了。出去看看，也不是不回來了。"),
  ("新航线通了，我也准备出海了。改好的钓竿留在岸上，这次我把回来的日子都定好了。","The new route’s open, and I’m ready to sail. I left the improved rod ashore. This time I know when I’m coming home.","新しい航路が開いて、私も出航の準備ができたよ。改良した竿は岸に置いてある。今度は帰る日も決めてるんだ。","新航線通了，我也準備出海了。改好的釣竿留在岸上，這次我把回來的日子都定好了。")],
 'lumi':[
  ("我一直照着客人的要求做东西。自己设计的都藏在柜子里，怕人家说好看是好看，就是没用。","I’ve always made what customers ask for. My own designs stay in a cupboard. I’m afraid people will call them pretty but useless.","いつもお客さんの希望どおりに作ってるの。自分の作品は戸棚の中。きれいだけど役に立たないって言われるのが怖くて。","我一直照著客人的要求做東西。自己設計的都藏在櫃子裡，怕人家說好看是好看，就是沒用。"),
  ("月纱灯挂进食堂以后，客人都舍不得走。还有人问是谁做的，真的记住了我的名字。","Since the moonveil lamp went up, guests stay longer. Someone even asked who made it. They actually remembered my name.","月紗の灯を食堂につけたら、お客さんが長くいてくれたの。誰が作ったのって聞かれて、名前まで覚えてくれたんだよ。","月紗燈掛進食堂以後，客人都捨不得走。還有人問是誰做的，真的記住了我的名字。"),
  ("远方工坊那份仿制订单，我没接。我想留在这儿，做些自己设计、大家也喜欢的家具。","I turned down that distant workshop’s copying job. I want to stay here and make my own furniture, things people will enjoy.","遠い工房の模造の仕事は断ったの。ここに残って、自分で考えた、皆にも喜んでもらえる家具を作りたい。","遠方工坊那份仿製訂單，我沒接。我想留在這兒，做些自己設計、大家也喜歡的家具。"),
  ("我的工坊开张了！这张月牙桌送给你，桌子底下还有大家的小签名呢。","My workshop’s open! This moon table is for you. Everyone’s little signatures are underneath.","私の工房、開店したよ！ この三日月テーブルは贈り物。裏には皆の小さなサインもあるんだ。","我的工坊開張了！這張月牙桌送給你，桌子底下還有大家的小簽名呢。")],
 'aster':[
  ("姐姐失踪那晚的星位，就在观测记录最后一页。我每次写到那里，都会把那页撕掉。","The last observation page shows the stars on the night my sister vanished. Every time I reach that page, I tear it out.","姉が行方不明になった夜の星の位置が、観測帳の最後の頁にあるんだ。そこまで書くと、いつも破ってしまう。","姐姐失蹤那晚的星位，就在觀測記錄最後一頁。我每次寫到那裡，都會把那頁撕掉。"),
  ("月晶里的记录是姐姐留下的。她当年把记忆留在月环里，是为了护住山谷。原来是这样……","The records in the crystals came from my sister. She left her memories in the moonring to protect the valley. So that’s what happened…","月晶の記録は姉が残したものだった。谷を守るために、月環に記憶を残したんだ。そうだったのか……。","月晶裡的記錄是姐姐留下的。她當年把記憶留在月環裡，是為了護住山谷。原來是這樣……"),
  ("最后一页，我终于写完了。旁边还画了姐姐爱喝的茶。现在我不想再把它撕掉了。","I finally finished the last page. I drew my sister’s favorite tea beside it. I don’t want to tear it out anymore.","最後の頁、やっと書けたよ。姉の好きなお茶も隣に描いた。今はもう、破りたくないんだ。","最後一頁，我終於寫完了。旁邊還畫了姐姐愛喝的茶。現在我不想再把它撕掉了。"),
  ("观星台重新开放了。我留下五枚月晶，第一堂公开课，就讲大家每天都能看见的这片星空吧。","The observatory’s open again. I’ve left five moon crystals. For the first public class, I’ll talk about the sky we can all see from here.","天文台をまた開いたよ。月晶を五つ残しておいた。最初の公開授業では、皆が毎日見られるこの星空の話をしようかな。","觀星臺重新開放了。我留下五枚月晶，第一堂公開課，就講大家每天都能看見的這片星空吧。")],
 'toma':[
  ("我老伴走了以后，我总说自己不会做饭了。可她用过的那把汤勺，我到现在还天天擦。","After my wife died, I kept saying I couldn’t cook anymore. But I still polish her old soup spoon every day.","妻が亡くなってから、もう料理はできないと言ってた。でも、あの人のスープ用の匙は、今も毎日磨いてるんだ。","我老伴走了以後，我總說自己不會做飯了。可她用過的那把湯勺，我到現在還天天擦。"),
  ("食谱边上有她写的小字：南瓜多放点，他爱吃甜的。我以前怎么就没注意到呢。","There’s a little note she wrote in the margin: more pumpkin, he likes it sweet. How did I never notice it before?","料理帳の端にあの人の字があった。「カボチャを多めに。あの人は甘いのが好き」。どうして今まで気づかなかったんだろうね。","食譜邊上有她寫的小字：南瓜多放點，他愛吃甜的。我以前怎麼就沒注意到呢。"),
  ("这锅南瓜汤，跟她做的还是不一样。不过挺好喝，我又添了一碗。这味道也该记下来。","This pumpkin soup’s different from hers, but it’s good. I had another bowl. This recipe deserves a place in the book too.","このカボチャスープ、あの人の味とは違うね。でもおいしい。おかわりしたよ。この味も書き残したいな。","這鍋南瓜湯，跟她做的還是不一樣。不過挺好喝，我又添了一碗。這味道也該記下來。"),
  ("早餐摊我又开起来了，面粉和牛奶也送进食堂了。新食谱的第一页，这回写的是我自己的名字。","I’ve reopened my breakfast stall and brought flour and milk to the eatery. The new recipe book starts with my own name this time.","朝ご飯の店をまた始めて、食堂に小麦粉と牛乳も届けたよ。新しい料理帳の最初には、今度は自分の名前を書いた。","早餐攤我又開起來了，麵粉和牛奶也送進食堂了。新食譜的第一頁，這回寫的是我自己的名字。")],
 'pip':[
  ("我做的第一台机器，把汤甩得到处都是。太丢人了，连失败记录都让我塞进了废铁堆。","My first machine flung soup everywhere. I was so embarrassed, I hid even the failure notes in the scrap pile.","最初に作った機械、スープをそこら中に飛ばしちゃって。恥ずかしくて、失敗の記録まで鉄くずに隠したんだ。","我做的第一臺機器，把湯甩得到處都是。太丟人了，連失敗記錄都讓我塞進了廢鐵堆。"),
  ("遗址里那本日志，原来是爷爷写的！字跟我真像。他没解决的问题，我也碰上了。","That logbook in the ruins was Grandpa’s! Our handwriting’s so alike. I’ve run into the same problems he never solved.","遺跡の記録帳、おじいちゃんが書いたものだった！ 字も僕とそっくり。おじいちゃんが解けなかった問題に、僕もぶつかってたんだ。","遺址裡那本日誌，原來是爺爺寫的！字跟我真像。他沒解決的問題，我也碰上了。"),
  ("那个只顾着加速的核心，我拆掉了，换成限速器。这下机器总算不乱响了，还磨出了一袋面粉！","I took out the core that kept speeding up and fitted a limiter. Now the machine’s quiet, and it’s milled a whole bag of flour!","加速ばかりする核を外して、速度を抑える装置に替えたよ。やっと静かになって、小麦粉が一袋できた！","那個只顧著加速的核心，我拆掉了，換成限速器。這下機器總算不亂響了，還磨出了一袋麵粉！"),
  ("新磨粉机放农场边了，铭牌也刻好了：省下的时间，留给想陪的人。以后我可不在炉边吃冷饭了。","The new mill’s beside the farm. Its plate says: save time for the people you care about. No more cold dinners by the furnace for me.","新しい粉ひき機を農場のそばに置いたよ。銘板には「大事な人と過ごす時間のために」って。もう炉の横で冷たいご飯は食べないぞ。","新磨粉機放農場邊了，銘牌也刻好了：省下的時間，留給想陪的人。以後我可不在爐邊吃冷飯了。")],
 'reed':[
  ("我每年都记回来过的候鸟。水道断了以后，这张单子就一年比一年短。","I record the birds that return each year. Since the water stopped flowing, the list has got shorter every year.","毎年、戻ってきた渡り鳥を書き留めてるんだ。水路が止まってから、年々その数が減っていてね。","我每年都記回來過的候鳥。水道斷了以後，這張單子就一年比一年短。"),
  ("查出来了，水渠是让树根和生锈的闸门堵住了。泉眼还在，水是被堵在上游了。","We found the problem: roots and a rusted gate blocked the channel. The spring’s still there; the water was trapped upstream.","原因がわかったよ。木の根とさびた水門が水路をふさいでいた。泉は今もあって、水が上流で止まってたんだ。","查出來了，水渠是讓樹根和生鏽的閘門堵住了。泉眼還在，水是被堵在上游了。"),
  ("莲塘有清水了，连好久没见的候鸟也回来了。我总算又能在单子上添一笔了。","Clean water’s back in the pond. A bird I hadn’t seen in ages returned too. I finally got to add a name to the list.","蓮池にきれいな水が戻って、久しく見なかった渡り鳥も来たよ。やっと名簿に一つ書き足せた。","蓮塘有清水了，連好久沒見的候鳥也回來了。我總算又能在單子上添一筆了。"),
  ("新水车上都落了候鸟。我把洒水器送去农场了，那边和湿地用的是同一条水道。","The birds are already perching on the new waterwheel. I sent the sprinkler to the farm. It shares the marsh’s waterway now.","新しい水車に、もう渡り鳥がとまってるよ。農場に散水器を届けた。あそこも湿地と同じ水路を使ってるんだ。","新水車上都落了候鳥。我把灑水器送去農場了，那邊和濕地用的是同一條水道。")],
 'yuki':[
  ("我总拿山路不通当借口。其实是邮袋里那封信，我一直不敢拆，怕看完更难受。","I keep blaming the blocked mountain road. Really, I’m afraid to open that letter in my bag. I’m scared it’ll hurt too much.","いつも山道が通れないせいにしてた。本当は郵袋の手紙を開けるのが怖かったの。読んだらもっとつらくなりそうで。","我總拿山路不通當藉口。其實是郵袋裡那封信，我一直不敢拆，怕看完更難受。"),
  ("信里是他画的温室图。他没有怪我没跟着走，还想着我留下来，冬天也能种花。","The letter had his greenhouse plans. He wasn’t upset that I stayed. He wanted me to be able to grow flowers here, even in winter.","手紙には彼の描いた温室の図面があった。ついていかなかった私を責めるどころか、ここでも冬に花を育てられるよう考えてくれてた。","信裡是他畫的溫室圖。他沒有怪我沒跟著走，還想著我留下來，冬天也能種花。"),
  ("我写了好长一封回信，食堂重新开门、山脚开了什么花，全写进去了。写完真的轻松多了。","I wrote a long reply about the eatery reopening and the flowers at the foot of the mountain. I felt so much better afterward.","長い返事を書いたよ。食堂がまた開いたことも、山の麓の花のことも全部。書き終えたら、すごく楽になった。","我寫了好長一封回信，食堂重新開門、山腳開了什麼花，全寫進去了。寫完真的輕鬆多了。"),
  ("最后一块玻璃装好了，温室里暖和得很。回信也寄出去了，还附上了第一束冬花。","The last pane’s in, and the greenhouse is lovely and warm. I sent my reply too, with the first winter flowers.","最後のガラスをはめたよ。温室の中、あったかいんだ。返事も出した。最初に咲いた冬の花を添えて。","最後一塊玻璃裝好了，溫室裡暖和得很。回信也寄出去了，還附上了第一束冬花。")],
 'orla':[
  ("那封没署名的信是我写的。我没敢告诉你镇上的实情，怕你看到账本上的亏空，就不肯来了。","I wrote the unsigned letter. I didn’t dare tell you how things were. I was afraid the town’s debts would keep you away.","匿名の手紙は私が書いたの。町の実情を話す勇気がなかった。帳簿の赤字を見たら、来てくれないと思って。","那封沒署名的信是我寫的。我沒敢告訴你鎮上的實情，怕你看到帳本上的虧空，就不肯來了。"),
  ("我翻了翻旧账本，才发现大家一直在互相帮忙。我老觉得什么都得自己扛，其实真不是。","Looking through the old accounts, I realized everyone’s been helping each other all along. I thought I had to carry it all myself. I didn’t.","古い帳簿を見て、皆がずっと助け合っていたと気づいたの。全部自分が背負わなきゃと思ってたけど、そうじゃなかった。","我翻了翻舊帳本，才發現大家一直在互相幫忙。我老覺得什麼都得自己扛，其實真不是。"),
  ("修复计划放到长桌上以后，大家都添了自己的想法。这回总算不是我一个人在那儿发愁了。","Once I put the repair plans on the long table, everyone added their ideas. This time, I’m not worrying about it all alone.","修復の計画を長机に出したら、皆が考えを書き足してくれた。今度は一人で頭を抱えなくていいんだね。","修復計劃放到長桌上以後，大家都添了自己的想法。這回總算不是我一個人在那兒發愁了。"),
  ("新账本的第一页，我记的是今晚聚餐的人数，不是欠款。这次我也给自己算了个位子。","The first page of the new ledger lists tonight’s dinner guests, not debts. I’ve counted a place for myself this time too.","新しい帳簿の最初には、借金じゃなく今夜の食事の人数を書いたの。今度は自分の席も数に入れたよ。","新帳本的第一頁，我記的是今晚聚餐的人數，不是欠款。這次我也給自己算了個位子。")],
}
for npc in npcs:
    npc['events']=[t(*names) for names in event_rows[npc['id']]]
    npc['lines']=[npc['lines'][0],*npc['events'][:3],npc['lines'][4]]

region_rows=[
 ('grove',('萤灯森林','Firefly Grove','蛍灯の森','螢燈森林'),0,['mushroom','berry','bamboo','honey'],'wood','799775'),
 ('quarry',('余烬石谷','Ember Quarry','残火の石谷','餘燼石谷'),2,['ore','scrap','crystal'],'ore','9b9396'),
 ('marsh',('莲雾湿地','Lotus Marsh','蓮霧の湿地','蓮霧濕地'),4,['lotus','herb','berry'],'wood','7dada6'),
 ('ruins',('旧械遗址','Clockwork Ruins','古機の遺跡','舊械遺址'),6,['scrap','ore','truffle'],'ore','9c9caa'),
 ('ridge',('霜铃山径','Frost Ridge','霜鈴の山道','霜鈴山徑'),8,['chestnut','crystal','mushroom'],'ore','afbfc7'),
 ('observatory',('月环观星台','Moonring Observatory','月環天文台','月環觀星臺'),10,['moonflower','crystal','tea'],'wood','a49abb'),
]
regions=[dict(id=id,name=t(*names),chapter=chapter,items=ids,resource=resource,color=color) for id,names,chapter,ids,resource,color in region_rows]

main_rows=[
 (('炉火重燃','The Hearth Rekindled','再び灯る炉','爐火重燃'),'gather',3,30),
 (('第一桌晚餐','The First Dinner','最初の夕食','第一桌晚餐'),'serve',3,40),
 (('小镇的根','Roots of the Town','町の根','小鎮的根'),'harvest',5,60),
 (('炉石与铁','Hearthstone and Iron','炉石と鉄','爐石與鐵'),'ore',6,60),
 (('重新流动的水','Water Flows Again','再び流れる水','重新流動的水'),'fish',5,80),
 (('熟悉的座位','A Familiar Seat','いつもの席','熟悉的座位'),'friend',200,80),
 (('旧械的心跳','Clockwork Heartbeat','古機の鼓動','舊械的心跳'),'scrap',8,100),
 (('月灯食堂','Moon Lantern Kitchen','月灯食堂','月燈食堂'),'restaurant',2,120),
 (('山径的来信','Letter from the Ridge','山道からの便り','山徑的來信'),'ridge',6,140),
 (('四季的种子','Seeds of Four Seasons','四季の種','四季的種子'),'crop_types',12,160),
 (('月环重明','Moonring Relit','月環再灯','月環重明'),'crystal',8,180),
 (('万家灯火宴','The Lantern Home Feast','万家灯火の宴','萬家燈火宴'),'banquet',3,300),
]
quests=[dict(id='main_%02d'%i,name=t(*names),metric=metric,goal=goal,reward=reward) for i,(names,metric,goal,reward) in enumerate(main_rows)]
objective_rows=[
 ('采集食材','Ingredients gathered','食材採集','採集食材'),('成功上菜','Meals served','配膳成功','成功上菜'),('收获作物','Crops harvested','作物収穫','收穫作物'),('累计矿石','Ore gathered','鉱石採集','累計礦石'),('累计鱼获','Fish caught','釣果','累計魚獲'),('最高好感','Highest friendship','最高親密度','最高好感'),('累计零件','Parts gathered','部品採集','累計零件'),('餐厅等级','Restaurant level','食堂レベル','餐廳等級'),('居民故事','Resident stories','住民の物語','居民故事'),('作物图鉴','Crop collection','作物図鑑','作物圖鑑'),('累计月晶','Crystals gathered','月晶採集','累計月晶'),('宴会料理','Banquet dishes served','宴料理の配膳','宴會料理')]
quest_lines=[
 ('冷却的炉膛里仍有一粒火种。新鲜食材的香气，让食堂又像一个家。','A spark remains in the cold hearth. Fresh ingredients make the kitchen feel like home again.','冷えた炉にも火種がある。新鮮な食材で食堂は再び家になった。','冷卻的爐膛裡仍有一粒火種。新鮮食材的香氣，讓食堂又像一個家。'),
 ('第一批客人记住了今晚的热汤。森林的萤灯也随着笑声重新亮起。','The first guests remember tonight’s soup. Firefly lanterns glow with their laughter.','最初の客は今夜のスープを覚えている。笑い声と共に森の蛍灯が灯った。','第一批客人記住了今晚的熱湯。森林的螢燈也隨著笑聲重新亮起。'),
 ('田地重新结出了果实。土壤里埋着通向石谷的旧路标。','The fields bear crops again. Beneath the soil lies an old sign to the quarry.','畑が再び実った。土の中には石谷への古い道標があった。','田地重新結出了果實。土壤裡埋著通向石谷的舊路標。'),
 ('旧闸门的齿轮缺了一角。余烬听见矿石落在铁砧上，重新燃起了炉火。','The old gate lacks a gear. Ore strikes Ember’s anvil and the forge awakens.','古い水門の歯車は欠けていた。エンバーの金床に鉱石が落ち、炉が目覚めた。','舊閘門的齒輪缺了一角。餘燼聽見礦石落在鐵砧上，重新燃起了爐火。'),
 ('鱼群沿着恢复的水道游回湿地。月环的一片碎影浮出了水面。','Fish return along the restored channel. A shard of moonring light rises from the marsh.','戻った水路を魚が湿地へ泳ぐ。月環の光の欠片が水面に浮かんだ。','魚群沿著恢復的水道游回濕地。月環的一片碎影浮出了水面。'),
 ('有一位居民开始为明天预留座位。旧械遗址的钥匙，也不再由一个人独自保管。','A resident saves a seat for tomorrow. The ruins’ key is no longer kept by one person alone.','明日の席を残す住民が現れた。遺跡の鍵も、もう一人だけで守られてはいない。','有一位居民開始為明天預留座位。舊械遺址的鑰匙，也不再由一個人獨自保管。'),
 ('废弃核心里没有怪物，只有一台忘记停止的机器。新的零件让它终于安静下来。','No monster waits in the old core, only a machine that forgot to stop. New parts let it rest.','古い核に怪物はいなかった。ただ止まることを忘れた機械。新しい部品が休息を与えた。','廢棄核心裡沒有怪物，只有一臺忘記停止的機器。新的零件讓它終於安靜下來。'),
 ('月灯食堂有了更大的桌子。山上的来信第一次写下了这里的名字。','Moon Lantern Kitchen gains a larger table. A mountain letter names it for the first time.','月灯食堂に大きな机ができた。山からの手紙に初めてその名が記された。','月燈食堂有了更大的桌子。山上的來信第一次寫下了這裡的名字。'),
 ('八段被尘封的故事重新有了结尾。霜铃山径的雪，也露出了春天的颜色。','Eight quiet stories find new endings. The ridge snow begins to reveal spring colors.','眠っていた八つの物語に続きができた。山道の雪にも春の色が見え始めた。','八段被塵封的故事重新有了結尾。霜鈴山徑的雪，也露出了春天的顏色。'),
 ('不同季节的种子在同一本图鉴里相遇。观星台终于认出了完整的四季星图。','Seeds from different seasons meet in one collection. The observatory recognizes the full seasonal chart.','違う季節の種が一冊に集まった。天文台は完全な四季の星図を認めた。','不同季節的種子在同一本圖鑑裡相遇。觀星臺終於認出了完整的四季星圖。'),
 ('月晶拼回环形星图。它需要的从来不是献祭，而是有人愿意记住的共同生活。','Crystals restore the ring chart. It needs shared lives worth remembering, not a sacrifice.','月晶が環状の星図を戻した。必要なのは犠牲ではなく、共に記憶する暮らしだった。','月晶拼回環形星圖。它需要的從來不是獻祭，而是有人願意記住的共同生活。'),
 ('最后三道宴席料理端上长桌。月环重新照亮山谷，而你也终于成为了这座小镇故事里的人。','The final banquet dishes reach the table. The moonring lights the valley, and you belong to the town’s story.','最後の宴料理が机に並んだ。月環は谷を照らし、あなたもこの町の物語の一人になった。','最後三道宴席料理端上長桌。月環重新照亮山谷，而你也終於成為了這座小鎮故事裡的人。')]
for q,objective,line in zip(quests,objective_rows,quest_lines):
    q['objective']=t(*objective);q['description']=t(*line)
quests[8]['objective']=t('山径调查','Ridge survey','山道の調査','山徑調查')
quests[8]['description']=t('山径的风铃重新响起，雪下露出的旧信封，记着月环最后一次亮起的夜晚。','The ridge chimes ring again. A letter beneath the snow recalls the night the moonring last shone.','山道の風鈴が再び鳴った。雪の下の古い手紙には、月環が最後に輝いた夜が記されていた。','山徑的風鈴重新響起，雪下露出的舊信封，記著月環最後一次亮起的夜晚。')
furniture_rows=[
 ('oak_chair',('橡木椅','Oak Chair','オーク椅','橡木椅'),'chair',4,0,1),('round_table',('圆木桌','Round Table','丸木テーブル','圓木桌'),'table',8,0,2),
 ('velvet_chair',('绒面椅','Velvet Chair','ベルベット椅','絨面椅'),'chair',8,1,3),('moon_table',('月牙桌','Moon Table','三日月テーブル','月牙桌'),'table',12,2,5),
 ('oak_bed',('橡木床','Oak Bed','オークのベッド','橡木床'),'bed',10,0,2),('moon_bed',('月纱床','Moonveil Bed','月紗ベッド','月紗床'),'bed',16,2,5),
 ('bookcase',('旧书架','Old Bookcase','古い本棚','舊書架'),'shelf',8,0,2),('tea_shelf',('茶器架','Tea Shelf','茶器棚','茶器架'),'shelf',10,1,3),
 ('cupboard',('碗碟柜','Dish Cupboard','食器棚','碗碟櫃'),'shelf',12,1,3),('pantry',('储物柜','Pantry Cabinet','貯蔵棚','儲物櫃'),'shelf',8,1,2),
 ('lantern',('月灯','Moon Lantern','月灯','月燈'),'lamp',4,1,3),('floor_lamp',('落地灯','Floor Lamp','フロアランプ','落地燈'),'lamp',6,2,4),
 ('flowerpot',('野花盆','Wildflower Pot','野花の鉢','野花盆'),'pot',3,0,1),('tea_planter',('茶树盆景','Tea Bonsai','茶の盆栽','茶樹盆景'),'pot',5,0,2),
 ('rug',('暖色地毯','Warm Rug','暖色のラグ','暖色地毯'),'rug',4,0,2),('star_rug',('星图地毯','Star Chart Rug','星図のラグ','星圖地毯'),'rug',8,1,4),
 ('wall_clock',('风铃挂钟','Chime Clock','風鈴時計','風鈴掛鐘'),'clock',6,2,3),('painting',('四季画框','Seasons Painting','四季の絵','四季畫框'),'painting',5,0,2),
 ('sofa',('莓色沙发','Berry Sofa','ベリー色ソファ','莓色沙發'),'sofa',12,1,4),('bench',('林间长椅','Forest Bench','森のベンチ','林間長椅'),'bench',6,0,2),
 ('aquarium',('潮汐鱼缸','Tidal Aquarium','潮の水槽','潮汐魚缸'),'tank',10,3,5),('fountain',('月晶喷泉','Crystal Fountain','月晶噴水','月晶噴泉'),'fountain',12,4,6),
 ('sign',('木刻招牌','Carved Sign','木彫り看板','木刻招牌'),'sign',4,0,1),('trophy',('月灯奖杯','Lantern Trophy','月灯トロフィー','月燈獎盃'),'trophy',8,4,8),
]
furniture=[dict(id=id,name=t(*names),shape=shape,wood=wood,iron=iron,comfort=comfort,color=['c7a477','a28ba6','9db694','d0b693'][i%4]) for i,(id,names,shape,wood,iron,comfort) in enumerate(furniture_rows)]
stations={id:t(*names) for id,names in [('pot',('汤锅','Pot','鍋','湯鍋')),('pan',('煎锅','Pan','フライパン','煎鍋')),('oven',('烤炉','Oven','オーブン','烤爐')),('board',('料理台','Prep Board','調理台','料理臺')),('kettle',('茶炉','Tea Kettle','茶炉','茶爐'))]}
upgrades=[dict(name=t(*names),coins=coins,wood=wood,iron=iron,seats=seats,menu=menu,patience=patience,speed=speed) for names,coins,wood,iron,seats,menu,patience,speed in [
 (('林间小食铺','Woodland Stall','森の小屋','林間小食鋪'),0,0,0,3,3,25,1.0),
 (('温暖小餐馆','Cozy Bistro','温かな食堂','溫暖小餐館'),100,12,2,3,5,30,1.15),
 (('月灯食堂','Moon Lantern Kitchen','月灯食堂','月燈食堂'),280,24,6,4,7,35,1.3),
 (('四季宴馆','Four Seasons Hall','四季の宴館','四季宴館'),650,40,12,5,9,40,1.5),
 (('星河大食堂','Star River Dining Hall','星河大食堂','星河大食堂'),1200,60,20,6,12,45,1.8)]]
intro=[dict(title=t(*title),line=t(*line),scene=scene) for title,line,scene in [
 # Opening film: the protagonist's past, the letter, the journey, the dark town and the waiting door.
 (('雾港的后厨','The Fog Harbor Kitchen','霧港の厨房','霧港的後廚'),("小女巫从小在雾港旅店的后厨帮忙。每天做一大锅饭，却总是她一个人在厨房吃。","The little witch grew up helping in a Fog Harbor inn kitchen. She cooked for everyone, then ate alone in the kitchen.","小さな魔女は霧港の宿の厨房で育った。皆のご飯を作っても、自分はいつも厨房で一人で食べていた。","小女巫從小在霧港旅店的後廚幫忙。每天做一大鍋飯，卻總是她一個人在廚房吃。"),'kitchen'),
 (('写着名字的信','A Letter with Her Name','名前の書かれた手紙','寫著名字的信'),("一个下雨的晚上，一封信落在洗碗台上。收信人是她，却没写谁寄的。信里问：今年能来一起吃顿饭吗？","One rainy evening, a letter landed by the sink. It was addressed to her, with no sender’s name. It asked: could you join us for dinner this year?","雨の晩、流し台に手紙が落ちてきた。宛名は彼女、差出人は書いていない。「今年、一緒にご飯を食べませんか」とあった。","一個下雨的晚上，一封信落在洗碗臺上。收信人是她，卻沒寫誰寄的。信裡問：今年能來一起吃頓飯嗎？"),'letter'),
 (('半箱锅子','Half a Trunk of Pots','鍋で半分の鞄','半箱鍋子'),("信里还附着一本旧食谱。她收拾好衣服和锅子，头一回独自出远门，去找信里说的小镇。","An old recipe book came with the letter. She packed her clothes and pots, then set off alone for the town it mentioned.","古い料理帳も添えてあった。服と鍋を鞄に詰め、手紙にあった町へ、初めて一人で遠出した。","信裡還附著一本舊食譜。她收拾好衣服和鍋子，頭一回獨自出遠門，去找信裡說的小鎮。"),'road'),
 (('熄灯的小镇','The Town Without Lights','灯の消えた町','熄燈的小鎮'),("哗啦啦魔女镇的月环已经很久没亮了。季节照常变，田却荒着，食堂也关了门，大家很少再一起吃饭。","Walala Witch Town’s moonring had been dark for years. The seasons still changed, but the fields lay empty and the eatery was closed. People rarely ate together anymore.","ワララ魔女の町の月環は、長い間消えたまま。季節は変わっても畑は荒れ、食堂も閉まっていた。皆で食事することも減っていた。","嘩啦啦魔女鎮的月環已經很久沒亮了。季節照常變，田卻荒著，食堂也關了門，大家很少再一起吃飯。"),'town'),
 (('等她的门','A Door That Waited','待っていた扉','等她的門'),("月芽农场的小屋没锁门。她放下箱子，松了口气：总算到了，以后也许就住这儿了。","The cottage on Moonsprout Farm was unlocked. She set down her trunk with a sigh of relief. She had made it. Maybe this could be her home.","月芽農場の小屋には鍵がかかっていなかった。鞄を下ろして、ほっと息をつく。やっと着いた。ここで暮らせるかもしれない。","月芽農場的小屋沒鎖門。她放下箱子，鬆了口氣：總算到了，以後也許就住這兒了。"),'home')]]

# Retain aliases for legacy Chinese copy. Current dialogue and its translations
# are authored together in the four-language tuples above and in story_content.py.
rewrite_path = ROOT / 'Scenes/Campaign/dialogue_rewrites.json'
dialogue_rewrites = json.loads(rewrite_path.read_text(encoding='utf-8'))

def _rewrite_dialogue(value):
    if isinstance(value, str):
        return dialogue_rewrites.get(value, value)
    if isinstance(value, list):
        return [_rewrite_dialogue(item) for item in value]
    if isinstance(value, dict):
        return {key: _rewrite_dialogue(item) for key, item in value.items()}
    return value

npcs = _rewrite_dialogue(npcs)
quests = _rewrite_dialogue(quests)
intro = _rewrite_dialogue(intro)
for old, new in dialogue_rewrites.items():
    if old in TEXT:
        row = TEXT.pop(old)
        row[0] = new
        TEXT[new] = row

ui=[
 ('选用','Select','選択','選用'),('已选','Selected','選択済み','已選'),
 ('熔炼','Smelt','精錬','熔煉'),('取出','Withdraw','取り出す','取出'),
 ('四季手记','Season Journal','四季の手帳','四季手記'),('种子','Seeds','種','種子'),('食谱','Recipes','料理帳','食譜'),('居民','Residents','住民','居民'),('探索','Explore','探索','探索'),('成长','Growth','成長','成長'),('仓储','Pantry','食料庫','倉儲'),('家具','Furniture','家具','家具'),('故事','Story','物語','故事'),
 ('购入','Buy','購入','購入'),('售出','Sell','売却','售出'),('完成','Complete','完了','完成'),('出发','Depart','出発','出發'),('赠礼','Gift','贈り物','贈禮'),('交谈','Talk','会話','交談'),('继续','Continue','続ける','繼續'),('略过','Skip','省略','略過'),('制作','Craft','製作','製作'),('摆放','Place','配置','擺放'),('收纳','Store','収納','收納'),
 ('季节不符','Wrong season','季節が合わない','季節不符'),('种子不足','Not enough seeds','種が足りない','種子不足'),('材料不足','Not enough materials','材料不足','材料不足'),('今日已赠礼','Gift already given today','今日は贈呈済み','今日已贈禮'),('今日已交谈','Already talked today','今日は会話済み','今日已交談'),('尚未开放','Unavailable','未開放','尚未開放'),('已达上限','Limit reached','上限に達した','已達上限'),('已完成','Completed','完了済み','已完成'),('未满足条件','Requirements unmet','条件未達','未滿足條件'),('目标达成','Objective complete','目標達成','目標達成'),('菜单已满','Menu full','献立が満杯','菜單已滿'),('夜间关闭','Closed at night','夜間閉鎖','夜間關閉'),('已售罄','Sold out','売り切れ','已售罄'),('地块已成熟','Crop ready','収穫可能','地塊已成熟'),
 ('自动洒水器','Sprinkler','スプリンクラー','自動灑水器'),('磨粉机','Mill','製粉機','磨粉機'),('蜂箱','Beehive','養蜂箱','蜂箱'),('温室','Greenhouse','温室','溫室'),('钓竿','Fishing Rod','釣り竿','釣竿'),('升级','Upgrade','強化','升級'),('厨房原料','Kitchen Ingredients','厨房の食材','廚房原料'),('资源入库','Resources Stored','資源保管','資源入庫'),('结识居民','Meet Residents','住民との出会い','結識居民'),('春芽节','Spring Sprout Festival','春芽祭','春芽節'),('潮灯节','Tide Lantern Festival','潮灯祭','潮燈節'),('丰收宴','Harvest Feast','収穫の宴','豐收宴'),('长夜灯会','Long Night Lanterns','長夜の灯祭','長夜燈會'),
 ('金币不足','Not enough coins','お金が足りない','金幣不足'),('已保存','Saved','保存済み','已儲存'),('保存失败','Save failed','保存失敗','儲存失敗'),('营业中','Open','営業中','營業中'),('已上架','Listed','提供中','已上架'),('未上架','Unlisted','未提供','未上架'),('食材不足','Not enough ingredients','食材不足','食材不足'),('好感','Friendship','親密度','好感'),('声望','Reputation','評判','聲望'),('主线','Main Story','本編','主線'),('布置','Decor','装飾','佈置'),('今日庆典','Today’s Festival','今日の祭り','今日慶典'),('灯会纪念','Lantern Memento','灯祭の記念','燈會紀念'),('制作完成','Crafted','製作完了','製作完成'),('收获完成','Harvested','収穫完了','收穫完成'),('播种完成','Planted','種まき完了','播種完成'),('浇水完成','Watered','水やり完了','澆水完成'),('施肥','Fertilize','施肥','施肥'),('肥料','Fertilizer','肥料','肥料'),('今日已施肥','Already fertilized today','今日は施肥済み','今日已施肥'),
 ('%s · 第%d年 · %d日','%s · Year %d · Day %d','%s・%d年・%d日','%s · 第%d年 · %d日'),('%s ×%d','%s ×%d','%s ×%d','%s ×%d'),('%s · %d金','%s · %dG','%s・%dG','%s · %d金'),('生长 %d/%d','Growth %d/%d','成長 %d/%d','生長 %d/%d'),('好感 %d/1000 · 故事 %d/4','Friendship %d/1000 · Story %d/4','親密度 %d/1000・物語 %d/4','好感 %d/1000 · 故事 %d/4'),('目标 %d/%d · 奖励 %d金','Goal %d/%d · Reward %dG','目標 %d/%d・報酬 %dG','目標 %d/%d · 獎勵 %d金'),('容量 %d · 菜单 %d · 声望 %d','Seats %d · Menu %d · Reputation %d','席 %d・献立 %d・評判 %d','容量 %d · 菜單 %d · 聲望 %d'),
]
ui += [
 ('没有使用中的存档','No active save','使用中のセーブなし','沒有使用中的存檔'),
 ('不在料理台旁','Not at the cooking station','調理台のそばではない','不在料理臺旁'),
 ('支线','Side Stories','サイドストーリー','支線'),
 ('暂缓','Defer','保留','暫緩'),
 ('好感 %d/%d · 奖励 %d金','Friendship %d/%d · Reward %dG','親密度 %d/%d・報酬 %dG','好感 %d/%d · 獎勵 %d金'),
]
for names in ui: t(*names)

food = expand(items, recipes, t)
story_text = {}
def story_t(*names):
    key = t(*names)
    story_text[key] = TEXT[key]
    return key
story = expand_story(quests, intro, story_t)
story = rebuild_story(quests, intro, regions, npcs, story, story_t)
data=dict(seasons=seasons,crops=crops,items=items,fish=fishes,tags=tags,recipes=recipes,npcs=npcs,regions=regions,quests=quests,furniture=furniture,stations=stations,upgrades=upgrades,intro=intro,**food,**story)
target=ROOT/'Scenes/Campaign/content.gd'
target.write_text('extends RefCounted\n## Generated by build_content.py. Stable IDs; original content.\nconst DATA = '+json.dumps(data,ensure_ascii=False,indent=1)+'\nconst DISH_NAMES = '+json.dumps([x['name'] for x in recipes],ensure_ascii=False)+'\nconst DISH_PRICES = '+json.dumps([x['price'] for x in recipes])+'\n',encoding='utf-8')
(ROOT/'Scenes/Campaign/content.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
tsv=ROOT/'Localization/messages.tsv'
with tsv.open(encoding='utf-8',newline='') as f: rows=list(csv.reader(f,delimiter='\t'))
known={r[0] for r in rows[1:]}
# Story wording and its four translations are maintained together. Preserve all
# unrelated catalog records, including local edits to the legacy content.
rows = [story_text.get(row[0], row) for row in rows]
with tsv.open('w',encoding='utf-8',newline='') as f:
    writer=csv.writer(f,delimiter='\t',lineterminator='\n')
    writer.writerows(rows)
    writer.writerows(row for key,row in TEXT.items() if key not in known)
print(f'CAMPAIGN: {len(crops)} crops, {len(recipes)} dishes, {len(npcs)} residents, {len(regions)} regions, {len(furniture)} furniture, {len(quests)} chapters')
