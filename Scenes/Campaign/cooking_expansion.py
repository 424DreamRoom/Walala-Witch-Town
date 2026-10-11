"""Additional authored ingredients and recipe families; stable IDs append to legacy dishes."""

# id | Simplified Chinese | English | Japanese | Traditional Chinese | sell | CC0 icon
INGREDIENT_ROWS = {
    'vegetable': '''
potato|土豆|Potato|ジャガイモ|馬鈴薯|8|potato
onion|洋葱|Onion|タマネギ|洋蔥|7|onion_brown
garlic|大蒜|Garlic|ニンニク|大蒜|5|garlic
ginger|生姜|Ginger|ショウガ|生薑|5|ginger
scallion|小葱|Scallion|小ネギ|青蔥|4|scallions
spinach|菠菜|Spinach|ホウレンソウ|菠菜|7|spinach
broccoli|西兰花|Broccoli|ブロッコリー|青花菜|9|broccoli
cauliflower|花椰菜|Cauliflower|カリフラワー|白花椰菜|9|cauliflower
beet|甜菜|Beet|ビーツ|甜菜|8|beet
celery|芹菜|Celery|セロリ|芹菜|6|celery
asparagus|芦笋|Asparagus|アスパラガス|蘆筍|10|asparagus
leek|韭葱|Leek|リーキ|韭蔥|7|scallions
zucchini|西葫芦|Zucchini|ズッキーニ|櫛瓜|8|squash
bell_pepper|甜椒|Bell Pepper|パプリカ|甜椒|8|chili_pepper_red
cabbage|卷心菜|Cabbage|キャベツ|高麗菜|7|cabbage
shiitake|香菇|Shiitake|シイタケ|香菇|10|mushroom
enoki|金针菇|Enoki|エノキ|金針菇|9|mushroom
taro|芋头|Taro|サトイモ|芋頭|10|taro
''',
    'fruit': '''
apple|苹果|Apple|リンゴ|蘋果|8|apple_red
pear|梨|Pear|梨|梨|8|pear
peach|桃子|Peach|桃|桃子|10|peach
cherry|樱桃|Cherry|サクランボ|櫻桃|11|cherries
grape|葡萄|Grape|ブドウ|葡萄|9|grapes_purple
orange|橙子|Orange|オレンジ|柳橙|8|orange
lemon|柠檬|Lemon|レモン|檸檬|6|lemon
lime|青柠|Lime|ライム|萊姆|6|lemon_lime
banana|香蕉|Banana|バナナ|香蕉|7|banana
pineapple|菠萝|Pineapple|パイナップル|鳳梨|12|pineapple
coconut|椰子|Coconut|ココナッツ|椰子|12|coconut_whole
mango|芒果|Mango|マンゴー|芒果|12|mango
kiwi|猕猴桃|Kiwi|キウイ|奇異果|9|kiwi
blueberry|蓝莓|Blueberry|ブルーベリー|藍莓|10|blueberries
raspberry|树莓|Raspberry|ラズベリー|覆盆子|10|rubus_raspberry
blackberry|黑莓|Blackberry|ブラックベリー|黑莓|10|rubus_blackberry
cranberry|蔓越莓|Cranberry|クランベリー|蔓越莓|10|cranberries
plum|李子|Plum|スモモ|李子|8|plum
apricot|杏子|Apricot|アンズ|杏子|9|peach
fig|无花果|Fig|イチジク|無花果|12|fig
persimmon|柿子|Persimmon|柿|柿子|10|persimmon
watermelon|西瓜|Watermelon|スイカ|西瓜|12|watermelon_whole
''',
    'protein': '''
chicken|鸡肉|Chicken|鶏肉|雞肉|14|chicken_drumstick_raw
beef|牛肉|Beef|牛肉|牛肉|20|steak_raw
pork|猪肉|Pork|豚肉|豬肉|15|steak_raw
duck|鸭肉|Duck|鴨肉|鴨肉|18|chicken_drumstick_raw
lamb|羊肉|Lamb|ラム肉|羊肉|20|steak_raw
bacon|培根|Bacon|ベーコン|培根|12|bacon
ham|火腿|Ham|ハム|火腿|12|ham
sausage|香肠|Sausage|ソーセージ|香腸|12|sausage
tofu|豆腐|Tofu|豆腐|豆腐|7|tofu
salmon|鲑鱼|Salmon|サケ|鮭魚|18|fish_fillet
tuna|金枪鱼|Tuna|マグロ|鮪魚|20|fish_fillet
crab|螃蟹|Crab|カニ|螃蟹|18|crab_legs
clam|蛤蜊|Clam|アサリ|蛤蜊|12|oyster
scallop|扇贝|Scallop|ホタテ|扇貝|16|oyster
''',
    'grain': '''
barley|大麦|Barley|大麦|大麥|5|corn
oat|燕麦|Oat|オーツ麦|燕麥|6|corn
buckwheat|荞麦|Buckwheat|ソバ|蕎麥|7|corn
millet|小米|Millet|アワ|小米|5|corn
soybean|黄豆|Soybean|大豆|黃豆|6|garbanzo_beans
red_bean|红豆|Red Bean|小豆|紅豆|6|garbanzo_beans
mung_bean|绿豆|Mung Bean|緑豆|綠豆|6|garbanzo_beans
chickpea|鹰嘴豆|Chickpea|ヒヨコ豆|鷹嘴豆|7|garbanzo_beans
lentil|扁豆|Lentil|レンズ豆|扁豆|6|garbanzo_beans
glutinous_rice|糯米|Glutinous Rice|もち米|糯米|7|rice_ball
''',
    'seasoning': '''
sugar|砂糖|Sugar|砂糖|砂糖|3|canned_food_2
butter|黄油|Butter|バター|奶油|8|cheese
cream|鲜奶油|Cream|生クリーム|鮮奶油|8|icecream_vanilla
cheese|奶酪|Cheese|チーズ|起司|10|cheese
yogurt|酸奶|Yogurt|ヨーグルト|優格|7|icecream_vanilla
cocoa|可可|Cocoa|ココア|可可|9|chocolate
coffee|咖啡豆|Coffee Beans|コーヒー豆|咖啡豆|9|peanut
cinnamon|肉桂|Cinnamon|シナモン|肉桂|6|cinnamon
vanilla|香草荚|Vanilla|バニラ|香草莢|10|vanilla
mint|薄荷|Mint|ミント|薄荷|5|peppermint
sesame|芝麻|Sesame|ゴマ|芝麻|5|peanut
peanut|花生|Peanut|ピーナッツ|花生|6|peanut
walnut|核桃|Walnut|クルミ|核桃|9|chestnut
almond|杏仁|Almond|アーモンド|杏仁|9|pistachios
soy_sauce|酱油|Soy Sauce|醤油|醬油|4|canned_food_2
vinegar|米醋|Rice Vinegar|米酢|米醋|4|canned_food_2
''',
}

INGREDIENT_CATEGORIES = {
    'vegetable': ('蔬菜与菌菇', 'Vegetables & Mushrooms', '野菜とキノコ', '蔬菜與菌菇'),
    'fruit': ('水果', 'Fruit', '果物', '水果'),
    'seafood': ('水产', 'Seafood', '魚介', '水產'),
    'protein': ('肉蛋奶', 'Meat, Eggs & Dairy', '肉・卵・乳製品', '肉蛋奶'),
    'grain': ('谷物与豆类', 'Grains & Beans', '穀物と豆', '穀物與豆類'),
    'seasoning': ('调味与花草', 'Seasonings & Botanicals', '調味料と花草', '調味與花草'),
}
RECIPE_CATEGORIES = {
    'soup': ('汤羹', 'Soups', 'スープ', '湯羹'),
    'staple': ('主食', 'Main Dishes', '主食', '主食'),
    'plate': ('家常菜', 'Side Dishes', 'おかず', '家常菜'),
    'dessert': ('甜点', 'Desserts', 'デザート', '甜點'),
    'drink': ('饮品', 'Drinks', '飲み物', '飲品'),
    'banquet': ('宴席', 'Banquets', '宴料理', '宴席'),
}
NON_FOOD = {'wood', 'ore', 'iron', 'crystal', 'scrap'}
STAPLES = ['egg', 'milk', 'flour', 'oil', 'salt', 'rice', 'wheat']
SEAFOOD = {'salmon', 'tuna', 'crab', 'clam', 'scallop'}


def expand(items, recipes, t):
    categories = {key: t(*names) for key, names in INGREDIENT_CATEGORIES.items()}
    recipe_categories = {key: t(*names) for key, names in RECIPE_CATEGORIES.items()}
    t('全部', 'All', 'すべて', '全部')
    t('搜索', 'Search', '検索', '搜尋')
    t('资源', 'Resources', '資源', '資源')
    original_categories = {
        'fruit': {'berry', 'strawberry', 'melon', 'chestnut'},
        'protein': {'egg', 'milk'},
        'grain': {'rice', 'wheat', 'flour'},
        'seasoning': {'herb', 'oil', 'salt', 'honey', 'tea', 'moonflower'},
    }
    for item in items.values():
        item['category'] = 'resource' if item['id'] in NON_FOOD else 'seafood' if item.get('shape') == 'fish' or item['id'] == 'prawn' else 'vegetable'
        for category, ids in original_categories.items():
            if item['id'] in ids:
                item['category'] = category
        item['shop'] = item['id'] in STAPLES

    added, icons, names_by_id, families = [], {}, {}, {}
    for category, block in INGREDIENT_ROWS.items():
        families[category] = []
        for line in block.strip().splitlines():
            id, zh, en, ja, tw, sell, icon = line.split('|')
            assert id not in items, id
            names = (zh, en, ja, tw)
            actual = 'seafood' if id in SEAFOOD else 'protein' if id in {'butter', 'cream', 'cheese', 'yogurt'} else category
            items[id] = dict(id=id, name=t(*names), buy=int(sell)*2, sell=int(sell), color='d6b985', shape='food', category=actual, shop=True)
            added.append(id)
            names_by_id[id] = names
            icons[id] = icon
            families[category].append(id)
    assert len(added) == 80
    ingredients = [id for id in items if id not in NON_FOOD]
    assert len(ingredients) == 120

    # Existing indices, costs, prices and tier unlocks remain stable.
    for recipe in recipes:
        id = recipe['id']
        recipe['category'] = ('banquet' if id in {'star_koi_banquet', 'four_seasons_platter', 'lantern_dessert'}
                              else 'drink' if recipe['station'] == 'kettle'
                              else 'soup' if 'soup' in id or 'broth' in id or 'stew' in id or id.endswith('_pot')
                              else 'dessert' if 'sweet' in recipe['tags'] and recipe['station'] in {'oven', 'board'}
                              else 'staple' if any(word in id for word in ('rice', 'noodle', 'pasta', 'bread')) else 'plate')

    def dish(id, names, cost, category, station, tier, tags, icon):
        # A positive margin over all purchased ingredients, including oil and salt.
        buy_cost = sum(items[key]['buy'] * count for key, count in cost.items())
        price = ((buy_cost * 135 + 499) // 500) * 5 + tier * 5
        recipes.append(dict(id=id, name=t(*names), cost=cost, price=price, tags=tags, tier=tier,
                            station=station, seconds=3+tier, color='d6b985', shape='plate', category=category))
        icons['dish_'+id] = icon

    def family(id, suffix, labels, cost, category, station, tier, tags, icon):
        n = names_by_id[id]
        names = (n[0]+labels[0], n[1]+' '+labels[1], n[2]+labels[2], n[3]+labels[3])
        dish(id+'_'+suffix, names, cost, category, station, tier, tags, icon)

    # 110 fruit recipes: fresh dishes, bakery, preserves and tea.
    for id in families['fruit']:
        family(id, 'yogurt', ('酸奶碗', 'Yogurt Bowl', 'ヨーグルトボウル', '優格碗'), {id:1,'yogurt':1}, 'dessert','board',0,['sweet','light'],'icecream_vanilla')
        family(id, 'smoothie', ('奶昔', 'Smoothie', 'ミルクシェイク', '奶昔'), {id:1,'milk':1}, 'drink','kettle',0,['sweet'],'dish_berry_milk')
        family(id, 'butter_tart', ('黄油挞', 'Butter Tart', 'バタータルト', '奶油塔'), {id:1,'flour':1,'butter':1}, 'dessert','oven',1,['sweet'],'pie_cherry_whole')
        family(id, 'compote', ('糖煮果', 'Compote', 'コンポート', '糖煮果'), {id:2,'sugar':1}, 'dessert','pot',0,['sweet'],'fruitcake')
        family(id, 'fruit_tea', ('果茶', 'Fruit Tea', 'フルーツティー', '果茶'), {id:1,'tea':1}, 'drink','kettle',0,['tea','light'],'dish_mist_tea')

    # 72 vegetable recipes with dairy, grains, garlic and herbs.
    for id in families['vegetable']:
        family(id, 'cream_soup', ('奶油浓汤', 'Cream Soup', 'クリームスープ', '奶油濃湯'), {id:2,'cream':1}, 'soup','pot',1,['warm','vegetable'],'soup_mushroom')
        family(id, 'stir_fry', ('清炒', 'Stir Fry', '炒め', '清炒'), {id:2,'oil':1,'salt':1}, 'plate','pan',0,['warm','vegetable'],'lettuce')
        family(id, 'garden_rice', ('田园饭', 'Garden Rice', '菜園ご飯', '田園飯'), {id:1,'rice':1,'soy_sauce':1}, 'staple','pot',0,['warm','vegetable'],'rice_ball')
        family(id, 'herb_roast', ('香草烤盘', 'Herb Roast', 'ハーブ焼き', '香草烤盤'), {id:2,'herb':1,'oil':1}, 'plate','oven',1,['warm','vegetable'],'pizza_vegetable_whole')

    # 56 meat, tofu and seafood recipes; vegetarian tags are never applied to meat.
    for id in families['protein']:
        base_tags = ['vegetable'] if id == 'tofu' else ['fish'] if id in SEAFOOD else []
        family(id, 'braised_rice', ('焖饭', 'Braised Rice', '炊き込みご飯', '燜飯'), {id:1,'rice':1,'soy_sauce':1}, 'staple','pot',1,base_tags+['warm'],'rice_ball')
        family(id, 'ginger_broth', ('姜香汤', 'Ginger Broth', '生姜スープ', '薑香湯'), {id:1,'ginger':1,'scallion':1}, 'soup','pot',0,base_tags+['warm','light'],'soup_miso')
        family(id, 'garlic_pan', ('蒜香煎盘', 'Garlic Sear', 'ガーリック焼き', '蒜香煎盤'), {id:1,'garlic':1,'oil':1}, 'plate','pan',1,base_tags+['warm'],'tofu' if id=='tofu' else 'fish_fillet' if id in SEAFOOD else 'steak_grilled')
        family(id, 'pepper_fritter', ('椒香脆饼', 'Pepper Fritters', '唐辛子揚げ', '椒香脆餅'), {id:1,'pepper':1,'flour':1,'oil':1}, 'plate','pan',2,base_tags+['spicy','warm'],'shrimp_fried' if id in SEAFOOD else 'falafel')

    # 40 grain and bean dishes.
    for id in families['grain']:
        family(id, 'porridge', ('暖粥', 'Porridge', '粥', '暖粥'), {id:2,'salt':1}, 'staple','pot',0,['warm','vegetable','light'],'soup_pea')
        family(id, 'pumpkin_rice', ('南瓜杂粮饭', 'Pumpkin Grain Rice', 'カボチャ雑穀ご飯', '南瓜雜糧飯'), {id:1,'pumpkin':1,'rice':1}, 'staple','pot',1,['warm','vegetable'],'rice_ball')
        family(id, 'sesame_cake', ('芝麻饼', 'Sesame Cakes', 'ゴマ焼き餅', '芝麻餅'), {id:1,'sesame':1,'flour':1,'oil':1}, 'staple','pan',1,['warm','vegetable'],'flatbread')
        family(id, 'honey_bun', ('蜂蜜蒸糕', 'Honey Buns', '蜂蜜蒸しパン', '蜂蜜蒸糕'), {id:1,'honey':1,'flour':1}, 'dessert','pot',1,['sweet','vegetable'],'muffin_plain')

    # 46 individual recipes complete dairy, nuts, condiments and the original harvests.
    specials = '''
cheese_omelet|奶酪蛋卷|Cheese Omelet|チーズオムレツ|起司蛋捲|egg:2,cheese:1,oil:1|plate|pan|0|warm|egg_fried
tomato_egg_rice|番茄鸡蛋饭|Tomato Egg Rice|トマト卵ご飯|番茄雞蛋飯|tomato:1,egg:1,rice:1|staple|pan|0|warm|rice_ball
butter_mushroom|黄油煎蘑菇|Butter Mushrooms|キノコのバター焼き|奶油煎蘑菇|mushroom:2,butter:1,garlic:1|plate|pan|0|warm,vegetable|mushroom
cream_pasta|奶油宽面|Cream Pasta|クリームパスタ|奶油寬麵|flour:1,cream:1,cheese:1|staple|pot|1|warm,vegetable|macaroni
garlic_flatbread|蒜香薄饼|Garlic Flatbread|ガーリック薄焼きパン|蒜香薄餅|flour:2,garlic:1,butter:1|staple|oven|0|warm,vegetable|flatbread
scallion_pancake|葱油饼|Scallion Pancake|ネギ油餅|蔥油餅|flour:2,scallion:1,oil:1|staple|pan|0|warm,vegetable|flatbread
vinegar_cucumber|醋香黄瓜|Vinegar Cucumber|キュウリの酢の物|醋香黃瓜|cucumber:2,vinegar:1,sesame:1|plate|board|0|light,vegetable|cucumber
soy_braised_egg|酱香卤蛋|Soy Braised Eggs|味付け卵|醬香滷蛋|egg:2,soy_sauce:1,sugar:1|plate|pot|0|warm|egg_whole_brown
sesame_tofu|芝麻豆腐|Sesame Tofu|豆腐のゴマ和え|芝麻豆腐|tofu:2,sesame:1,soy_sauce:1|plate|board|0|light,vegetable|tofu
peanut_noodles|花生拌面|Peanut Noodles|ピーナッツ和え麺|花生拌麵|flour:1,peanut:1,soy_sauce:1,vinegar:1|staple|pot|0|vegetable|macaroni
walnut_bread|核桃面包|Walnut Bread|クルミパン|核桃麵包|wheat:1,walnut:1,butter:1|staple|oven|1|warm,vegetable|bread_loaf_brown
almond_cookie|杏仁曲奇|Almond Cookies|アーモンドクッキー|杏仁餅乾|flour:1,almond:1,butter:1,sugar:1|dessert|oven|1|sweet|cookie
cocoa_cookie|可可曲奇|Cocoa Cookies|ココアクッキー|可可餅乾|flour:1,cocoa:1,butter:1,sugar:1|dessert|oven|1|sweet|cookie
cinnamon_roll|肉桂卷|Cinnamon Roll|シナモンロール|肉桂捲|flour:1,cinnamon:1,butter:1,sugar:1|dessert|oven|1|sweet|croissant
vanilla_pudding|香草布丁|Vanilla Pudding|バニラプリン|香草布丁|milk:1,egg:1,vanilla:1,sugar:1|dessert|pot|1|sweet|flan
mint_chocolate|薄荷巧克力|Mint Chocolate|ミントチョコ|薄荷巧克力|mint:1,cocoa:1,milk:1,sugar:1|dessert|board|1|sweet|chocolate
cheese_cake|乳酪蛋糕|Cheesecake|チーズケーキ|乳酪蛋糕|cheese:1,egg:1,flour:1,sugar:1|dessert|oven|2|sweet|cake_slice_plain
cream_scone|奶油司康|Cream Scone|クリームスコーン|奶油司康|cream:1,flour:1,butter:1|dessert|oven|1|sweet|muffin_plain
yogurt_honey|蜂蜜酸奶|Honey Yogurt|蜂蜜ヨーグルト|蜂蜜優格|yogurt:2,honey:1|dessert|board|0|sweet,light|icecream_vanilla
sesame_rice_ball|芝麻糯米团|Sesame Rice Balls|ゴマ団子|芝麻糯米糰|glutinous_rice:1,sesame:1,sugar:1|dessert|pot|1|sweet|dango
red_bean_mochi|红豆糯米糕|Red Bean Mochi|小豆餅|紅豆糯米糕|glutinous_rice:1,red_bean:1,sugar:1|dessert|pot|1|sweet|mochi
peanut_brittle|花生糖|Peanut Brittle|ピーナッツ飴|花生糖|peanut:2,sugar:1|dessert|pan|0|sweet|cookie
walnut_honey_cake|核桃蜂蜜糕|Walnut Honey Cake|クルミ蜂蜜ケーキ|核桃蜂蜜糕|walnut:1,honey:1,flour:1,egg:1|dessert|oven|2|sweet|fruitcake
almond_milk|杏仁牛乳|Almond Milk Drink|アーモンドミルク飲料|杏仁牛乳|almond:1,milk:1,sugar:1|drink|kettle|0|sweet|dish_berry_milk
black_coffee|醇香咖啡|Black Coffee|ブラックコーヒー|醇香咖啡|coffee:1|drink|kettle|0|light|dish_mist_tea
milk_coffee|牛乳咖啡|Milk Coffee|ミルクコーヒー|牛乳咖啡|coffee:1,milk:1|drink|kettle|0|sweet|dish_berry_milk
cocoa_milk|热可可|Hot Cocoa|ホットココア|熱可可|cocoa:1,milk:1,sugar:1|drink|kettle|0|sweet,warm|dish_berry_milk
cinnamon_coffee|肉桂咖啡|Cinnamon Coffee|シナモンコーヒー|肉桂咖啡|coffee:1,cinnamon:1,milk:1|drink|kettle|1|warm|dish_mist_tea
vanilla_latte|香草拿铁|Vanilla Latte|バニララテ|香草拿鐵|coffee:1,vanilla:1,milk:1|drink|kettle|1|sweet|dish_berry_milk
mint_tea|薄荷清茶|Mint Tea|ミントティー|薄荷清茶|mint:1,tea:1|drink|kettle|0|tea,light|dish_mist_tea
ginger_honey_tea|姜蜜茶|Ginger Honey Tea|生姜蜂蜜茶|薑蜜茶|ginger:1,honey:1,tea:1|drink|kettle|0|tea,warm|dish_honey_tea
salted_caramel_milk|海盐焦糖牛乳|Salted Caramel Milk|塩キャラメルミルク|海鹽焦糖牛乳|salt:1,sugar:1,milk:1,butter:1|drink|kettle|1|sweet,warm|dish_berry_milk
corn_cheese_bake|玉米奶酪焗盘|Corn Cheese Bake|コーンチーズ焼き|玉米起司焗盤|corn:1,cheese:1,cream:1|plate|oven|1|warm,vegetable|pizza_cheese_whole
pea_potato_salad|豌豆土豆沙拉|Pea Potato Salad|エンドウポテトサラダ|豌豆馬鈴薯沙拉|pea:1,potato:1,yogurt:1|plate|board|0|light,vegetable|lettuce
bamboo_mushroom_soup|春笋菌菇汤|Bamboo Mushroom Soup|タケノコキノコ汁|春筍菌菇湯|bamboo:1,shiitake:1,salt:1|soup|pot|1|warm,vegetable,light|soup_mushroom
lotus_pork_soup|莲藕排骨汤|Lotus Pork Soup|レンコン豚肉スープ|蓮藕排骨湯|lotus:1,pork:1,ginger:1|soup|pot|1|warm|soup_miso
chestnut_chicken|栗香炖鸡|Chestnut Chicken|栗と鶏の煮物|栗香燉雞|chestnut:1,chicken:1,soy_sauce:1|plate|pot|1|warm|chicken_drumstick_cooked
truffle_cheese_rice|松露奶酪烩饭|Truffle Cheese Risotto|トリュフチーズリゾット|松露起司燉飯|truffle:1,rice:1,cheese:1,cream:1|staple|pot|2|warm,rare,vegetable|rice_ball
moonflower_almond_cake|月光杏仁糕|Moonflower Almond Cake|月光花アーモンド菓子|月光杏仁糕|moonflower:1,almond:1,flour:1,honey:1|dessert|oven|2|sweet,rare|moon_cake
snow_cabbage_dumpling|雪心白菜饺|Snow Cabbage Dumplings|雪心ハクサイ餃子|雪心白菜餃|snow_cabbage:1,pork:1,flour:1|staple|pot|1|warm|dumpling
radish_beef_stew|霜晶牛肉煲|Frost Radish Beef Stew|霜晶ダイコン牛肉煮|霜晶牛肉煲|winter_radish:1,beef:1,ginger:1|soup|pot|2|warm|soup_miso
prawn_garlic_noodle|蒜香虾面|Garlic Prawn Noodles|ガーリックエビ麺|蒜香蝦麵|prawn:1,garlic:1,flour:1,oil:1|staple|pan|1|fish,warm|macaroni
silverfin_lemon|柠香银鳞鱼|Lemon Silverfin|銀鱗魚のレモン焼き|檸香銀鱗魚|silverfin:1,lemon:1,butter:1|plate|pan|1|fish,warm|fish_fillet
carp_tofu_soup|溪鲤豆腐汤|Carp Tofu Soup|コイと豆腐のスープ|溪鯉豆腐湯|brook_carp:1,tofu:1,ginger:1|soup|pot|1|fish,warm,light|soup_miso
pumpkin_milk_pudding|南瓜牛乳布丁|Pumpkin Milk Pudding|カボチャミルクプリン|南瓜牛乳布丁|pumpkin:1,milk:1,egg:1,sugar:1|dessert|pot|1|sweet|flan
sweet_potato_cheese|红薯奶酪焗碗|Sweet Potato Cheese Bake|サツマイモチーズ焼き|紅薯起司焗碗|sweet_potato:1,cheese:1,butter:1|plate|oven|1|warm,vegetable|yam
'''
    for row in specials.strip().splitlines():
        id, zh, en, ja, tw, raw_cost, category, station, tier, tags, icon = row.split('|')
        cost = {part.split(':')[0]: int(part.split(':')[1]) for part in raw_cost.split(',')}
        dish(id, (zh,en,ja,tw), cost, category, station, int(tier), tags.split(','), icon)

    assert len(recipes) == 360, len(recipes)
    assert len({recipe['id'] for recipe in recipes}) == len(recipes)
    assert len({recipe['name'] for recipe in recipes}) == len(recipes)
    assert set(ingredients) == {id for recipe in recipes for id in recipe['cost']}
    return dict(ingredients=ingredients, added_ingredients=added, ingredient_categories=categories,
                recipe_categories=recipe_categories, food_icons=icons)
