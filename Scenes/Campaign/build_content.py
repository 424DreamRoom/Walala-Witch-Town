"""Author original campaign content and register all four UI languages. Idempotent."""
import csv
import json
from pathlib import Path
from cooking_expansion import expand

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
 ('mori',('茉莉','Mori','モリ','茉莉'),'grove',['vegetable','tea'],'spicy','tea',0,'7c9c7a','braids',('种子记得每一场雨。','Seeds remember every rain.','種は雨を覚えている。','種子記得每一場雨。'),('母亲的温室终于又透进了光。','Mother’s greenhouse holds sunlight again.','母の温室にまた光が差した。','母親的溫室終於又透進了光。')),
 ('ember',('余烬','Ember','エンバー','餘燼'),'quarry',['warm','spicy'],'sweet','pepper',3,'b68b76','short',('火候和锤声都有自己的节拍。','Fire and hammers each have a rhythm.','火も槌も独自の拍子がある。','火候和錘聲都有自己的節拍。'),('这一次，我打造的是留给小镇的东西。','This time, I am forging something for our town.','今度は町に残すものを鍛える。','這一次，我打造的是留給小鎮的東西。')),
 ('nagi',('澪','Nagi','ナギ','澪'),'dock',['fish','light'],'spicy','moon_bass',1,'7b9eb9','bob',('海风今天带着远方的盐味。','The wind carries salt from far away.','海風が遠くの塩を運んでくる。','海風今天帶著遠方的鹽味。'),('旧航线重新亮了，我也有了回来的理由。','The old route shines again. I have a reason to return.','古い航路が輝き、帰る理由ができた。','舊航線重新亮了，我也有了回來的理由。')),
 ('lumi',('露米','Lumi','ルミ','露米'),'town',['sweet','tea'],'spicy','strawberry',5,'bc92ad','long',('橱窗里还少一盏属于自己的灯。','My window is missing a light of its own.','窓辺にはまだ自分の灯りがない。','櫥窗裡還少一盞屬於自己的燈。'),('原来我的手艺也能成为别人的纪念。','My craft can become someone’s treasured memory.','私の手仕事も誰かの思い出になる。','原來我的手藝也能成為別人的紀念。')),
 ('aster',('星芒','Aster','アスター','星芒'),'observatory',['rare','tea'],'spicy','moonflower',4,'8aa7ad','locks',('星图缺失的地方，总有人留下名字。','Someone left a name where the chart is missing.','星図の欠けた場所に名前が残っている。','星圖缺失的地方，總有人留下名字。'),('星光不是告别，是我们共同的坐标。','Starlight is our shared coordinate.','星の光は私たち共通の座標だ。','星光不是告別，是我們共同的座標。')),
 ('toma',('陶陶','Toma','トマ','陶陶'),'town',['warm','vegetable'],'rare','pumpkin',2,'b18499','curls',('旧食谱的空白，比字迹更让人在意。','The gaps in old recipes say as much as the ink.','古い料理帳の余白が気になる。','舊食譜的空白，比字跡更讓人在意。'),('这张新菜单上，也写着我们的名字。','Our names belong on this new menu too.','新しい献立には私たちの名前もある。','這張新菜單上，也寫著我們的名字。')),
 ('pip',('皮普','Pip','ピップ','皮普'),'ruins',['spicy','warm'],'light','corn',3,'c5a16f','short',('废墟里的齿轮还在等下一次转动。','The ruins’ gears await their next turn.','廃墟の歯車は次の回転を待っている。','廢墟裡的齒輪還在等下一次轉動。'),('机器省下来的时间，终于够大家一起吃饭了。','The machines leave us time to eat together.','機械のおかげで皆で食事する時間ができた。','機器省下來的時間，終於夠大家一起吃飯了。')),
 ('reed',('芦苇','Reed','リード','蘆葦'),'marsh',['light','vegetable'],'fish','lotus',0,'89a590','braids',('沼泽没有沉默，只是声音很轻。','The marsh speaks softly.','湿地の声はただ静かなだけだ。','沼澤沒有沉默，只是聲音很輕。'),('干涸的水道恢复了，候鸟也会回来。','The channels flow again. The birds will return.','水路が戻れば渡り鳥も帰ってくる。','乾涸的水道恢復了，候鳥也會回來。')),
 ('yuki',('霜铃','Yuki','ユキ','霜鈴'),'ridge',['warm','sweet'],'spicy','snow_cabbage',1,'b4b8d2','bob',('雪线那边，有我没寄出的信。','Beyond the snow line waits my unsent letter.','雪線の向こうに出せなかった手紙がある。','雪線那邊，有我沒寄出的信。'),('信终于寄出了，春天也就不远了。','The letter is sent. Spring feels near.','手紙を出した。春はもう近い。','信終於寄出了，春天也就不遠了。')),
 ('orla',('奥萝','Orla','オルラ','奧蘿'),'town',['tea','rare'],'spicy','honey',4,'b9a481','locks',('镇上的灯少了一盏，桌边就会空一处。','One lost town lantern leaves a place empty.','町の灯が一つ消えると席が一つ空く。','鎮上的燈少了一盞，桌邊就會空一處。'),('这一次，镇上的灯一盏也没有少。','This time, every town lantern is shining.','今度は町の灯が一つも欠けていない。','這一次，鎮上的燈一盞也沒有少。')),
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
  ('温室旧玻璃上映着两个身影。茉莉第一次提起失踪的母亲，以及没有发芽的最后一包种子。','Two shadows cross the old greenhouse glass. Mori speaks of her missing mother and the last seeds that never sprouted.','古い温室に二つの影。モリは行方不明の母と芽吹かなかった最後の種を語った。','溫室舊玻璃上映著兩個身影。茉莉第一次提起失蹤的母親，以及沒有發芽的最後一包種子。'),
  ('那包种子没有死去，只是在等待一场温暖的雨。茉莉决定把母亲的研究留给整个小镇。','Those seeds were waiting for warm rain. Mori decides to share her mother’s research with the town.','種は温かな雨を待っていた。モリは母の研究を町に伝えると決めた。','那包種子沒有死去，只是在等待一場溫暖的雨。茉莉決定把母親的研究留給整個小鎮。'),
  ('新苗顶开泥土时，茉莉哭了。她终于相信，照顾留下来的生命并不是背叛远行的人。','Mori weeps as the shoots emerge. Caring for those who remain does not betray those who left.','芽が土を押し上げた時、モリは泣いた。残る命を守ることは旅立った人を裏切らない。','新苗頂開泥土時，茉莉哭了。她終於相信，照顧留下來的生命並不是背叛遠行的人。'),
  ('茉莉把第一批四季种子分给大家。温室门上挂起新牌子：属于所有人的春天。','Mori shares the first seasonal seeds. The greenhouse sign reads: Spring belongs to everyone.','モリは四季の種を分けた。温室の看板には「みんなの春」。','茉莉把第一批四季種子分給大家。溫室門上掛起新牌子：屬於所有人的春天。')],
 'ember':[
  ('铁砧下压着一枚烧黑的徽章。余烬曾为封闭月环打造零件，从此不敢再锻造灯架。','A scorched badge lies under the anvil. Ember forged parts that sealed the moonring and has feared making lanterns since.','金床の下に焦げた徽章。月環を閉ざす部品を鍛えたエンバーは、灯の台を作れずにいた。','鐵砧下壓著一枚燒黑的徽章。餘燼曾為封閉月環打造零件，從此不敢再鍛造燈架。'),
  ('修复的旧图纸证明，事故来自失控的核心。余烬仍然坚持为每一盏熄灭的灯补做灯架。','The restored plans reveal a runaway core caused the accident. Ember still chooses to rebuild every lost lantern stand.','修復した図面は事故の原因が暴走した核だと示した。それでもエンバーは灯台を作り直す。','修復的舊圖紙證明，事故來自失控的核心。餘燼仍然堅持為每一盞熄滅的燈補做燈架。'),
  ('最后一枚铆钉落下。余烬把旧徽章熔进新的镇钟，过去的伤痕终于有了新的声音。','The last rivet falls. Ember melts the badge into the new town bell, giving the past a new voice.','最後の鋲が打たれた。古い徽章は新しい町の鐘になり、過去に新しい音が生まれた。','最後一枚鉚釘落下。餘燼把舊徽章熔進新的鎮鐘，過去的傷痕終於有了新的聲音。'),
  ('镇钟响起时，余烬终于走出炉房。他留下三块好铁，准备打造属于自己的第一艘小船。','When the bell rings, Ember leaves the forge. Three fine ingots remain as he begins planning his own little boat.','鐘が鳴り、エンバーは炉を出た。鉄を三つ残し、自分の小舟の計画を始めた。','鎮鐘響起時，餘燼終於走出爐房。他留下三塊好鐵，準備打造屬於自己的第一艘小船。')],
 'nagi':[
  ('澪保存着一张褪色船票。她答应过父亲守住码头，却把留下当成了不能离开的惩罚。','Nagi keeps a faded ticket. Her promise to guard the dock has begun to feel like a sentence.','ナギは色あせた船券を持っている。港を守る約束は、出られない罰のようになっていた。','澪保存著一張褪色船票。她答應過父親守住碼頭，卻把留下當成了不能離開的懲罰。'),
  ('潮水送回父亲的漂流瓶。信里没有要求，只有一句：海的另一边也有你的家。','The tide returns her father’s bottle. His letter asks nothing: there is a home for you across the sea too.','潮が父の瓶を返した。手紙は何も求めず「海の向こうにも君の家がある」と伝えた。','潮水送回父親的漂流瓶。信裡沒有要求，只有一句：海的另一邊也有你的家。'),
  ('澪重新绘出停航多年的海图。她第一次把归期写在出航日期旁边。','Nagi redraws the long-abandoned sea chart. For the first time, she writes a return date beside her departure.','ナギは長く途絶えた海図を描き直し、出航日の隣に初めて帰港日を書いた。','澪重新繪出停航多年的海圖。她第一次把歸期寫在出航日期旁邊。'),
  ('新航线的第一声汽笛响起。澪把改良钓竿留在岸边，笑着说，这次远行也有归途。','The new route sounds its first whistle. Nagi leaves an improved rod ashore: this journey has a way home.','新航路の汽笛。ナギは改良した竿を岸に残し「今度の旅には帰り道がある」と笑った。','新航線的第一聲汽笛響起。澪把改良釣竿留在岸邊，笑著說，這次遠行也有歸途。')],
 'lumi':[
  ('露米的订单簿只写着别人的名字。她把自己的作品藏在柜底，怕小镇不需要这些漂亮而无用的东西。','Lumi’s order book holds only other names. Her own designs hide in a drawer, waiting to be wanted.','ルミの注文帳には他人の名前ばかり。自分の作品は必要とされる日を待ち、引き出しに眠る。','露米的訂單簿只寫著別人的名字。她把自己的作品藏在櫃底，怕小鎮不需要這些漂亮而無用的東西。'),
  ('第一盏月纱灯挂进餐厅后，客人久久没有离开。露米第一次听见有人记得她的名字。','Guests linger beneath her first moonveil lamp. For the first time, Lumi hears someone remember her name.','月紗の灯の下で客は長くくつろいだ。ルミは初めて自分の名を覚えてくれた人に会った。','第一盞月紗燈掛進餐廳後，客人久久沒有離開。露米第一次聽見有人記得她的名字。'),
  ('露米拒绝了远方工坊的仿制订单。她决定留下，制作只属于哗啦啦的家具。','Lumi turns down a distant workshop’s copies. She will stay and make furniture that belongs to Walala.','ルミは遠い工房の模造依頼を断った。ここに残り、ワララだけの家具を作る。','露米拒絕了遠方工坊的仿製訂單。她決定留下，製作只屬於嘩啦啦的家具。'),
  ('月牙桌下刻着所有人的小小签名。露米把它作为礼物，庆祝自己的第一家工坊开张。','Tiny signatures fill the underside of the moon table. Lumi gifts it to celebrate her own workshop’s opening.','三日月テーブルの裏には皆の署名。自分の工房の開店祝いに、ルミはそれを贈った。','月牙桌下刻著所有人的小小簽名。露米把它作為禮物，慶祝自己的第一家工坊開張。')],
 'aster':[
  ('星芒总把观测记录的最后一页撕掉。那上面写着月环熄灭当夜，姐姐最后出现的星位。','Aster tears out every final observation page. It marks where her sister vanished the night the moonring dimmed.','アスターは観測帳の最後を破る。月環が消えた夜、姉が消えた星の位置だった。','星芒總把觀測記錄的最後一頁撕掉。那上面寫著月環熄滅當夜，姐姐最後出現的星位。'),
  ('散落的月晶拼成了一段旧记录。姐姐没有消失，她把记忆留在月环里，保护了整个山谷。','Moon crystals reveal an old record. Her sister placed her memories within the moonring to shelter the valley.','月晶から古い記録が現れた。姉は谷を守るため、記憶を月環に残したのだ。','散落的月晶拼成了一段舊記錄。姐姐沒有消失，她把記憶留在月環裡，保護了整個山谷。'),
  ('星芒终于补全了最后一页。她在星位旁添上了姐姐最喜欢的茶，以及今晚餐厅的灯光。','Aster completes the final page, adding her sister’s favorite tea and tonight’s kitchen lantern beside the stars.','アスターは最後の頁を埋めた。星の隣に姉の好きな茶と今夜の食堂の灯を描いた。','星芒終於補全了最後一頁。她在星位旁添上了姐姐最喜歡的茶，以及今晚餐廳的燈光。'),
  ('观星台重新开放。星芒留下五枚月晶，把第一堂公开课取名为：与远方的人共享夜空。','The observatory reopens. Aster leaves five crystals and names her first class: A Sky Shared Across Distance.','天文台が再開した。アスターは月晶を五つ残し、初授業を「遠い人と分かち合う空」と名づけた。','觀星臺重新開放。星芒留下五枚月晶，把第一堂公開課取名為：與遠方的人共享夜空。')],
 'toma':[
  ('陶陶说自己早已忘记做饭。可他仍然每天擦拭那只属于亡妻的旧汤勺。','Toma claims he has forgotten cooking, yet polishes his late wife’s soup ladle every day.','トマは料理を忘れたと言う。それでも亡き妻のお玉を毎日磨いている。','陶陶說自己早已忘記做飯。可他仍然每天擦拭那隻屬於亡妻的舊湯勺。'),
  ('旧食谱空白处出现了一行小字：南瓜多一点，他喜欢甜的。陶陶沉默了很久。','A tiny note hides in the recipe margins: more pumpkin, he likes it sweet. Toma falls silent.','料理帳の余白に「カボチャ多め、彼は甘いのが好き」。トマは長く黙った。','舊食譜空白處出現了一行小字：南瓜多一點，他喜歡甜的。陶陶沉默了很久。'),
  ('那锅南瓜汤没有完全一样的味道。陶陶却又盛了一碗，说新的味道也值得留下。','The pumpkin soup tastes different. Toma takes another bowl: new flavors are worth keeping too.','カボチャのスープは同じ味ではなかった。トマはおかわりし、新しい味も残そうと言った。','那鍋南瓜湯沒有完全一樣的味道。陶陶卻又盛了一碗，說新的味道也值得留下。'),
  ('陶陶重开了早餐摊，把面粉和牛奶送进食堂。他终于在新食谱第一页写下了自己的名字。','Toma reopens his breakfast stall and sends flour and milk. His new recipe book begins with his own name.','トマは朝食屋を再開し、小麦粉と牛乳を届けた。新しい料理帳の最初には自分の名があった。','陶陶重開了早餐攤，把麵粉和牛奶送進食堂。他終於在新食譜第一頁寫下了自己的名字。')],
 'pip':[
  ('皮普造的第一台机器只会把汤搅得到处都是。他偷偷把失败记录塞进废铁堆。','Pip’s first machine only splashed soup. He hid its failure notes among the scrap.','ピップの最初の機械はスープを飛ばすだけだった。失敗帳は鉄くずの中に隠された。','皮普造的第一臺機器只會把湯攪得到處都是。他偷偷把失敗記錄塞進廢鐵堆。'),
  ('旧械遗址里的日志与皮普的笔迹很像。那是祖父留下的设计，也留下了从未解决的问题。','Logs in the ruins resemble Pip’s handwriting. His grandfather left both designs and unfinished questions.','遺跡の記録はピップの字に似ていた。祖父は設計と解けなかった問題を残していた。','舊械遺址裡的日誌與皮普的筆跡很像。那是祖父留下的設計，也留下了從未解決的問題。'),
  ('皮普拆掉了追求速度的核心，换上一个简单的限速器。机器第一次安静地磨出了一袋面粉。','Pip replaces the speed-hungry core with a simple governor. The mill quietly makes its first bag of flour.','ピップは速さを求める核を調速器に替えた。機械は初めて静かに小麦粉を挽いた。','皮普拆掉了追求速度的核心，換上一個簡單的限速器。機器第一次安靜地磨出了一袋麵粉。'),
  ('新磨粉机停在农场边。皮普在铭牌上刻下：节省时间，是为了和重要的人一起度过。','The new mill stands by the farm. Pip engraves: Time saved is time shared with those who matter.','新しい製粉機が農場に置かれた。銘板には「大切な人と過ごすために時間をつくる」。','新磨粉機停在農場邊。皮普在銘牌上刻下：節省時間，是為了和重要的人一起度過。')],
 'reed':[
  ('芦苇守着一张越来越短的候鸟清单。湿地断流后，回来的名字一年比一年少。','Reed guards a shrinking list of migratory birds. Since the marsh dried, fewer names return each year.','リードの渡り鳥の名簿は短くなっていた。湿地の水が止まって以来、帰る名は減り続けた。','蘆葦守著一張越來越短的候鳥清單。濕地斷流後，回來的名字一年比一年少。'),
  ('旧水渠被树根和锈闸堵住。芦苇发现，所谓消失的泉眼只是在等待有人重新倾听。','Roots and a rusted gate choke the channel. The lost spring was waiting for someone to listen again.','古い水路は根と錆びた堰で塞がれていた。消えた泉は、また耳を傾ける人を待っていた。','舊水渠被樹根和鏽閘堵住。蘆葦發現，所謂消失的泉眼只是在等待有人重新傾聽。'),
  ('第一股清水回到莲塘。芦苇没有说话，只在清单末尾添上了一个久违的名字。','Clear water returns to the lotus pond. Reed quietly adds a long-missing name to the list.','蓮池に清水が戻った。リードは静かに、久しくなかった名を名簿に添えた。','第一股清水回到蓮塘。蘆苇沒有說話，只在清單末尾添上了一個久違的名字。'),
  ('候鸟落上新水车。芦苇把自动洒水器送到农场，小镇和湿地从此共享同一条清流。','Birds settle on the waterwheel. Reed brings a sprinkler, linking farm and marsh through the same clear stream.','鳥が新しい水車に止まった。リードの散水機で、農場と湿地は同じ清流を分かち合う。','候鳥落上新水車。蘆葦把自動灑水器送到農場，小鎮和濕地從此共享同一條清流。')],
 'yuki':[
  ('霜铃的邮袋里，有一封写给自己的信。她总说山路还没通，其实是不敢读懂信里的告别。','Yuki carries a letter addressed to herself. The mountain road is open; she fears the farewell inside.','ユキの鞄には自分宛ての手紙。山道は通じていたが、中の別れを読むのが怖かった。','霜鈴的郵袋裡，有一封寫給自己的信。她總說山路還沒通，其實是不敢讀懂信裡的告別。'),
  ('信里是一份温室设计。远行的朋友并没有责怪她留下，只希望她的冬天也能开花。','The letter holds greenhouse plans. Her traveling friend wanted her winters to bloom, without blaming her for staying.','手紙には温室の図面。旅立った友は残る彼女を責めず、冬にも花が咲くよう願った。','信裡是一份溫室設計。遠行的朋友並沒有責怪她留下，只希望她的冬天也能開花。'),
  ('霜铃写了很长的回信，讲小镇的新食堂和山脚的花。邮袋终于比从前轻了。','Yuki writes about the new kitchen and flowers below the mountain. Her mailbag finally feels lighter.','ユキは新しい食堂と山麓の花を長い返事に書いた。郵便鞄はようやく軽くなった。','霜鈴寫了很長的回信，講小鎮的新食堂和山腳的花。郵袋終於比從前輕了。'),
  ('温室在雪中亮起。霜铃把最后一块玻璃安好，第一束冬花将和回信一起远行。','The greenhouse glows in snow. Yuki fits the final pane; winter flowers will travel with her reply.','雪の中で温室が輝いた。ユキが最後のガラスをはめると、冬の花は返事と共に旅立つ。','溫室在雪中亮起。霜鈴把最後一塊玻璃安好，第一束冬花將和回信一起遠行。')],
 'orla':[
  ('奥萝承认，那封没有署名的信出自她手。她害怕你看见账簿上濒临停摆的小镇。','Orla admits she wrote the unsigned letter. She feared the town’s failing accounts would send you away.','オルラは無署名の手紙を書いたと告白した。町の窮状を見て去られるのが怖かった。','奧蘿承認，那封沒有署名的信出自她手。她害怕你看見帳簿上瀕臨停擺的小鎮。'),
  ('旧账簿记着每一次无声的帮助。奥萝发现，小镇从来不是靠一个人撑到今天。','The old ledger records countless quiet kindnesses. Orla sees that no one carried the town alone.','古い帳簿には静かな助けが数えきれない。町は一人で支えられていたのではなかった。','舊帳簿記著每一次無聲的幫助。奧蘿發現，小鎮從來不是靠一個人撐到今天。'),
  ('奥萝把修复计划摆上公共长桌。第一次，所有居民都在计划旁写下了自己的愿望。','Orla lays the restoration plan on a public table. Every resident writes a wish beside it.','オルラは修復計画を皆の机に広げた。住民は初めて自分の願いを書き添えた。','奧蘿把修復計劃擺上公共長桌。第一次，所有居民都在計劃旁寫下了自己的願望。'),
  ('新账簿第一页没有欠款，只有今夜聚餐的人数。奥萝终于给自己也留了一个座位。','The new ledger opens with tonight’s dinner count instead of debt. Orla finally saves a seat for herself.','新しい帳簿の最初は借金ではなく今夜の人数。オルラはようやく自分の席も残した。','新帳簿第一頁沒有欠款，只有今夜聚餐的人數。奧蘿終於給自己也留了一個座位。')],
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
 (('长夜里的信','A Letter in the Long Night','長い夜の手紙','長夜裡的信'),('最后一盏月灯熄灭前，一封没有署名的信抵达了你的窗边。','Before the last moon lantern faded, an unsigned letter reached your window.','最後の月灯が消える前、差出人のない手紙が窓辺に届いた。','最後一盞月燈熄滅前，一封沒有署名的信抵達了你的窗邊。'),'letter'),
 (('哗啦啦魔女镇','Walala Witch Town','ワララ魔女の町','嘩啦啦魔女鎮'),('雾中的小镇失去了四季的回声，田野荒芜，食堂的炉火也冷了。','The mistbound town lost the echo of its seasons. Fields lay empty and the kitchen grew cold.','霧の町は四季の響きを失い、畑は荒れ、食堂の炉も冷えた。','霧中的小鎮失去了四季的回聲，田野荒蕪，食堂的爐火也冷了。'),'town'),
 (('旧食谱','The Old Recipe Book','古い料理帳','舊食譜'),('旧食谱里藏着一张星图。每一顿被记住的晚餐，都能让月环重新发光。','A star chart hides in the recipe book. Every remembered dinner can rekindle the moonring.','古い料理帳には星図がある。心に残る夕食が月環を再び照らす。','舊食譜裡藏著一張星圖。每一頓被記住的晚餐，都能讓月環重新發光。'),'kitchen'),
 (('炉火与归途','Hearth and Homecoming','炉と帰り道','爐火與歸途'),('你带着种子与食谱留下来。今夜起，这里会再次有热汤和等候的人。','You stayed with seeds and recipes. Tonight, warm soup and familiar faces will return.','種と料理帳を手に残った。今夜から、温かなスープと待つ人が戻ってくる。','你帶著種子與食譜留下來。今夜起，這裡會再次有熱湯和等候的人。'),'home')]]
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
data=dict(seasons=seasons,crops=crops,items=items,fish=fishes,tags=tags,recipes=recipes,npcs=npcs,regions=regions,quests=quests,furniture=furniture,stations=stations,upgrades=upgrades,intro=intro,**food)
target=ROOT/'Scenes/Campaign/content.gd'
target.write_text('extends RefCounted\n## Generated by build_content.py. Stable IDs; original content.\nconst DATA = '+json.dumps(data,ensure_ascii=False,indent=1)+'\nconst DISH_NAMES = '+json.dumps([x['name'] for x in recipes],ensure_ascii=False)+'\nconst DISH_PRICES = '+json.dumps([x['price'] for x in recipes])+'\n',encoding='utf-8')
(ROOT/'Scenes/Campaign/content.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
tsv=ROOT/'Localization/messages.tsv'
with tsv.open(encoding='utf-8',newline='') as f: rows=list(csv.reader(f,delimiter='\t'))
known={r[0] for r in rows[1:]}
with tsv.open('a',encoding='utf-8',newline='') as f:
    writer=csv.writer(f,delimiter='\t',lineterminator='\n')
    writer.writerows(row for key,row in TEXT.items() if key not in known)
print(f'CAMPAIGN: {len(crops)} crops, {len(recipes)} dishes, {len(npcs)} residents, {len(regions)} regions, {len(furniture)} furniture, {len(quests)} chapters')
