"""Reviewed conversational edits; preserve a before snapshot for this revision."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
DRAFT = ROOT / 'Narrative/Rebuild_20261020'
before = OUT / 'before'
paths = list(DRAFT.glob('*')) + [ROOT / p for p in [
    'Scenes/Campaign/rebuilt_story.py', 'Scenes/Campaign/content.gd',
    'Scenes/Campaign/content.json', 'Localization/messages.tsv',
    'Localization/catalog.gd', 'Scenes/Campaign/README.md',
]]
for path in paths:
    if path.is_file():
        target = before / path.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            assert target.read_bytes() == path.read_bytes(), f'Already changed: {path}'
        else:
            shutil.copy2(path, target)
originals = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in (ROOT / 'MyArt').rglob('*') if p.is_file()}
(OUT / 'originals_before.json').write_text(json.dumps(originals, indent=2), encoding='utf-8')

manifest = json.loads((DRAFT / '场景索引.json').read_text(encoding='utf-8'))
translations = {}
current = None
for row in (DRAFT / 'translations_en_ja.txt').read_text(encoding='utf-8').splitlines():
    if row.startswith('@'):
        current = row[1:]
        translations[current] = []
    elif row.strip():
        translations[current].append(row.split('|'))
sources = {s['id']: (DRAFT / s['file']).read_text(encoding='utf-8').splitlines()
           for s in manifest['scenes']}
changes = []

def replace(scene, number, zh, en, ja):
    index = number - 1
    old = sources[scene][index]
    assert '：' in zh and len(zh.split('：', 1)) == 2
    if scene != 'opening':
        assert zh.split('：')[0] == old.split('：')[0], (scene, number, old, zh)
    assert len(translations[scene][index]) == 2
    sources[scene][index] = zh
    translations[scene][index] = [en, ja]
    changes.append(dict(scene=scene, line=number, before=old, after=zh))

def rows(scene, source):
    for row in source.strip().splitlines():
        number, zh, en, ja = row.split('|')
        replace(scene, int(number), zh, en, ja)

rows('opening', '''
1|澪：到啦，哗啦啦魔女镇。船上的行李都在这儿，是你的吧？|Here we are, Walala Witch Town. Is this all your luggage?|着いたよ、ワララ魔女町。船の荷物はこれで全部。あなたので合ってる？
2|薇尔莉娅：对，谢谢！总算到了，我腿都坐麻了。|Yes, thank you! At last. My legs have gone numb from sitting.|うん、ありがとう！ やっと着いた。座りっぱなしで足がしびれちゃった。
3|澪：这箱子还挺沉。里面装了什么？|This trunk's pretty heavy. What's in it?|この箱、結構重いね。何が入ってるの？
4|薇尔莉娅：锅和碗。我想开个小食堂，这些就先带来了。|Pots and bowls. I'm hoping to open a little eatery, so I brought what I had.|鍋と食器。小さな食堂を開きたくて、家にあるものを持ってきたの。
5|澪：月灯食堂？你就是来租房子的那位？|Moon Lantern Kitchen? You're the one here to rent it?|月灯食堂？ 借りに来るっていうのは、あなた？
6|薇尔莉娅：嗯，告示上说还有块田，第一季不用交租。我就想来看看。|Yes. The notice said there's a field too, and no rent for the first season. I thought I'd take a look.|うん。畑も付いてて、最初の季節は家賃がいらないって。見に来てみようと思って。
7|澪：那就没找错。我叫澪，平时管码头，也帮镇上收货。|You've got the right place. I'm Nagi. I run the dock and handle deliveries for the town.|ここで合ってるよ。私はナギ。普段は波止場で、町の荷物も受け取ってる。
8|薇尔莉娅：我叫薇尔莉娅。以后店里的东西，估计也得麻烦你收了。|I'm 薇尔莉娅. I expect I'll be asking you to take deliveries for the eatery too.|私は薇尔莉娅。お店の荷物も、これからお願いすることになりそう。
9|澪：没问题。等你开张了，我也去吃一顿。|No problem. I'll come by for a meal once you're open.|もちろん。開店したら、私もご飯を食べに行くね。
10|薇尔莉娅：好啊！我先把住的地方收拾好，开张了就告诉你。|I'd like that! I'll get settled in first, then let you know when we're open.|ぜひ！ まず住む所を片付けて、開店が決まったら知らせるね。
11|萤萝：薇尔莉娅？你到啦！我是萤萝，之前给你回过信。|薇尔莉娅? You're here! I'm Yingluo. I wrote back to you.|薇尔莉娅？ 着いたんだね！ 私、インルオ。手紙のお返事を書いたの。
12|薇尔莉娅：原来是你！我还怕船来晚了，让你们白等。|So that was you! I was worried the boat was late and I'd kept you waiting.|あなただったんだ！ 船が遅れて、待たせちゃったかと思って。
13|萤萝：没事，今天我正好在这条街巡灯。奥萝在食堂等你呢。|It's fine. I was checking the lamps on this street anyway. Orla's waiting at the eatery.|大丈夫。今日はちょうど、この通りの灯を見回ってたから。オルラは食堂で待ってるよ。
14|薇尔莉娅：你就是负责修灯的？那以后可认识熟人了。这屋子也是我租的？|You look after the lamps? Good to know someone who does. Is this cottage part of the rental too?|灯を直してるんだ？ 知り合えてよかった。この家も借りられるの？
15|萤萝：对，住这里。屋顶上个月刚补好，水管也通了，今晚就能住。|Yes, this is where you'll live. The roof was patched last month, and the water works. You can stay tonight.|うん、ここに住めるよ。屋根は先月直して、水道も通ったの。今夜から大丈夫。
16|薇尔莉娅：那我就放心了。刚看见田里这么多草，还以为屋里也得收拾好几天。|That's a relief. After seeing all those weeds, I thought the house might take days to sort out too.|よかった。畑が草だらけだったから、家の片付けも何日かかかるかと思ってた。
17|萤萝：屋里我们打扫过了。你一个人来开店，忙得过来吗？|We cleaned inside. Can you manage the eatery on your own?|中は掃除しておいたよ。一人でお店をやるの、大変じゃない？
18|薇尔莉娅：我在雾港后厨干了三年，做饭倒是不怕。开店嘛，还真是头一回。|I worked in a Fog Harbor kitchen for three years, so cooking doesn't worry me. Running a place is new, though.|霧港の厨房で三年働いたから、料理は大丈夫。でも、お店を持つのは初めてなの。
19|萤萝：那你怎么想到来这里？雾港不是更热闹吗？|What made you choose here? Isn't Fog Harbor busier?|じゃあ、どうしてここに？ 霧港のほうがにぎやかでしょう？
20|薇尔莉娅：那边房租太贵了。我攒的钱只够开个小店，这里第一季免租，正好试试。|The rent there is too high. I've only saved enough for a small place. A season rent-free gives me a chance to try.|向こうは家賃が高くて。貯金も小さなお店の分くらい。ここなら最初の季節は無料だし、やってみたくて。
21|萤萝：厨房也不大，不过锅灶都还在。你想好卖什么了吗？|The kitchen's small too, but the stove and pots are still there. Do you know what you'll serve?|厨房も小さいけど、かまども鍋も残ってるよ。何を出すか、もう決めた？
22|薇尔莉娅：先做汤和炖饭吧。我最拿手的就是这两样，客人少也不怕做太多。|Soup and rice stew to start. They're what I make best, and I can cook small batches while it's quiet.|まずはスープと煮込みご飯かな。その二つが得意だし、お客さんが少なくても少量ずつ作れるから。
23|萤萝：听着不错！后面那块田呢，你以前种过菜吗？|Sounds good! What about the field behind the house? Have you grown vegetables before?|いいね！ 裏の畑はどうする？ 野菜を育てたことはあるの？
24|薇尔莉娅：没种过。我先种一点试试，能给店里省点菜钱就好了。|No. I'll try a little at first. It'd be nice to save on vegetables for the eatery.|ないの。まず少しだけ育ててみたい。お店の野菜代がちょっとでも浮けばいいな。
25|萤萝：茉莉很会种菜，改天介绍你们认识。走，奥萝还等着呢。|Mori's good with plants. I'll introduce you sometime. Come on, Orla's still waiting.|モリは野菜を育てるのが上手だよ。今度紹介するね。さあ、オルラが待ってる。
26|奥萝：欢迎，我是奥萝。房子和厨房都看过了，觉得怎么样？|Welcome, I'm Orla. Now you've seen the cottage and kitchen, what do you think?|ようこそ、オルラよ。家も厨房も見たところで、どうかしら？
27|薇尔莉娅：比我想的好多了！不过有些地方挺旧，要是漏水了，修起来得我出钱吗？|Better than I expected! Some of it looks old, though. Would I have to pay to fix any leaks?|思ってたよりずっといいです！ でも古い所もあるし、雨漏りしたら私が修理代を出すんですか？
28|奥萝：屋顶、墙和原来的水管坏了，镇里来修。你不用担心这笔钱。|The town will repair the roof, walls and existing pipes. You don't need to budget for those.|屋根や壁、元からある水道管は町で直すわ。そのお金は心配しなくていいの。
29|薇尔莉娅：那农具和锅碗呢？我带的不多，可能还得添一些。|What about tools and cookware? I haven't brought much. I may need a few things.|農具や調理道具は？ あまり持ってこられなかったので、足りないかもしれません。
30|奥萝：农具能借，厨房留下的这些也能用，不另收钱。|You can borrow farm tools and use what's left in the kitchen, at no extra charge.|農具は貸せるし、厨房に残っている物も使っていいわ。別料金はかからないから。
31|陶陶：碗在柜子里，都洗过了。那只小汤锅底下有裂口，我已经放旁边了。|The bowls in the cupboard are washed. The little soup pot's cracked underneath, so I've set it aside.|戸棚の器は洗ってあるよ。小鍋は底が割れてたから、脇によけておいた。
32|薇尔莉娅：谢谢，省我好多事。奥萝，我再确认一下，是先租一年，第一季免费？|Thank you. That saves me a lot of work. Orla, just to check: a year's rental, first season free?|ありがとう、助かるわ。オルラ、確認なんですけど、一年借りて、最初の季節は無料で合ってます？
33|奥萝：对，后面按月交。你自己买的东西，以后不租了也能带走。|Yes, then you pay monthly. Anything you buy is yours to take if you leave.|ええ、その後は月払い。自分で買った物は、借りるのをやめる時に持っていっていいわ。
34|薇尔莉娅：那就好。我还没自己开过店，有点怕做不起来。|That's good. I've never run my own place before. I'm a little worried it won't work out.|よかった。自分でお店をやるのは初めてだから、うまくいくか少し心配で。
35|奥萝：先试一年，真不合适就不续租。租约在这儿，你想好了再定。|Try it for a year. If it doesn't suit you, you don't have to renew. Here's the lease; take your time deciding.|まずは一年やってみて、合わなかったら更新しなくていいの。契約書はここよ。よく考えて決めてね。
36|陶陶：锅灶我也试过了，能用。我叫陶陶，以前也在这儿做过饭。|I've tested the stove too. It works. I'm Toma. I used to cook here.|かまども試したよ。ちゃんと使える。僕はトマ。前はここで料理してたんだ。
37|薇尔莉娅：那太好了。我带了点干蘑菇，今晚煮锅汤，请你们尝尝？|That's great. I brought some dried mushrooms. Shall I make soup tonight for you all to try?|それは心強いわ。干しキノコを持ってきたの。今夜スープを作るから、皆で味見しない？
38|萤萝：我也能留下来吗？早上忙到现在，就吃了一个饼。|Can I stay too? I've been busy all day. All I've had is a little flatbread.|私も食べていい？ 朝からずっと忙しくて、おやきを一つ食べただけなの。
39|薇尔莉娅：当然能。不过我只带了三只碗……|Of course! Although I've only brought three bowls...|もちろん！ でも、持ってきた器は三つだけで……。
40|奥萝：柜子里还有，够我们几个人用了。今晚我也留下吃一碗。|There are more in the cupboard. Enough for all of us. I'll stay for a bowl too.|戸棚にまだあるから、皆の分も足りるわ。私も今夜、一杯いただこうかしら。
41|薇尔莉娅：好，那我就租下了。今晚先试试味道，明晚正式开张！|All right, I'll take it. We'll try the food tonight, then open tomorrow evening!|はい、借ります！ 今夜はまず味見をして、明日の夜から開店ね！
42|陶陶：行，汤还没好，先吃点面包。你也别饿着。|Right. Have some bread while the soup cooks. You need to eat too.|よし。スープができるまでパンでも食べよう。君もお腹を空かせたままじゃだめだよ。
43|薇尔莉娅：那我不客气了，坐了一天船，我还真饿了。|Don't mind if I do. A whole day on the boat's made me hungry.|じゃあ、いただきます。一日船に乗ってたから、ほんとにお腹ぺこぺこ。
''')

rows('chapter_01', '''
1|陶陶：菜单板我擦好了。你今天打算卖什么？|I've wiped the menu board. What are you serving today?|献立の板、拭いておいたよ。今日は何を出す？
2|薇尔莉娅：蘑菇汤。先卖这一样，会不会太少了？|Mushroom soup. Is just one dish too little to start with?|キノコスープ。最初はそれだけって、少なすぎるかな？
3|陶陶：你准备了多少？|How much have you made?|どのくらい作ったの？
4|薇尔莉娅：八碗。我有点担心，万一来的人多呢？|Eight bowls. I'm worried more people might turn up.|八杯分。もっと人が来たらどうしようって。
5|陶陶：先把这八碗做好。面包还有，吃不饱也能加一点。|Let's get those eight bowls right. There's bread if anyone's still hungry.|まずは八杯をおいしく作ろう。足りなければパンもあるよ。
6|薇尔莉娅：那我就写八份，卖完为止？|Then I'll write eight portions, while they last?|じゃあ八食分って書いて、売り切れたらおしまい？
7|陶陶：对。刚开张，少做一点也没关系。|Right. It's fine to start small on your first night.|そう。初日なんだから、少なめでも大丈夫。
8|薇尔莉娅：好，我不往锅里加水了。刚才还真动过这个念头。|Good. No extra water in the pot, then. I was honestly considering it.|うん、鍋に水を足すのはやめる。実はちょっと考えてたんだ。
11|萤萝：街上这些小灯归我管。山上那个月环，是另一套装置。|I look after the little street lamps. The moonring on the mountain is a separate system.|通りの小さな灯は私の担当。山の月環は、また別の設備なの。
13|萤萝：嗯，停了好多年了。街灯能自己亮，不靠它供着，你放心。|Yes, it's been off for years. The street lamps work on their own, though, so we'll have light.|うん、もう何年も止まってる。でも街灯は別にともせるから、明かりは大丈夫だよ。
19|薇尔莉娅：那就在这儿吃吧。汤盛好了，等会儿凉了就不好喝了。|Why not eat here? The soup's ready, and it's better while it's hot.|じゃあ、ここで食べていかない？ スープもよそったし、冷めないうちに。
32|薇尔莉娅：太好了！你还留着面粉？|Oh, good! You've still got flour?|よかった！ 小麦粉、まだあったの？
33|陶陶：嗯，以前做饭买的，最近没怎么用。|Yes, I bought it for cooking a while back. Haven't used much lately.|うん、前に料理用に買ったんだ。最近はあまり使ってなくてね。
34|薇尔莉娅：那我先买半袋。明天没面包，可就少卖一样了。|I'll buy half a bag, then. Without bread, tomorrow's menu will be even smaller.|じゃあ半袋買わせて。明日パンがないと、ただでさえ少ない献立が減っちゃう。
35|陶陶：行，明晚我来吃饭，再一起算钱。|Sure. I'll be here for dinner tomorrow; we can settle up then.|いいよ。明日の夜も食べに来るから、その時に払ってくれれば。
36|薇尔莉娅：你还来啊？我还怕今天做得不合你口味。|You're coming back? I was worried you hadn't liked today's soup.|また来てくれるの？ 今日のスープ、口に合わなかったかと思って。
37|陶陶：挺好喝的。就是我那碗已经空了半天，你也没看见。|I liked it. Though my bowl's been empty for a while and you haven't noticed.|おいしかったよ。ただ、さっきから器が空なのに、気付いてくれなくてね。
39|薇尔莉娅：我这就盛。对了，你们吃着怎么样？|Coming right up. How is everyone else finding it?|今よそうね。そうだ、皆はどう？
40|余烬：挺好。我想再加点盐。|Good. I'd like a little more salt.|うまい。塩を少し足したいな。
41|露米：盐就在你手边，少撒一点，上回你自己都嫌咸。|It's beside you. Go easy; last time even you thought you'd added too much.|塩は手元にあるでしょ。控えめにね。前は自分でもしょっぱいって言ってたから。
42|余烬：这回不会。|Won't happen this time.|今回は大丈夫だ。
43|薇尔莉娅：有哪里不合口味就说，我明天再改。|Tell me if anything isn't to your taste. I can adjust it tomorrow.|好みに合わない所があったら言ってね。明日また調整するから。
44|余烬：那明天给我留点面包。我来晚些。|Save me some bread tomorrow, then. I'll be a little late.|じゃあ明日、パンを取っておいてくれ。少し遅くなる。
''')
rows('chapter_02', '''
19|澪：先试一次吧。我还得跟船主商量，看他肯不肯定期来。|Let's try one trip first. I'll have to ask the skipper about a regular run.|まずは一回試そう。定期便にできるかは、船長とも相談しないと。
25|薇尔莉娅：那你先算算能卖多少，我再看明晚做几份。|Work out how much you can sell, then I'll plan tomorrow's portions.|売れる分が決まったら、明日の夜に何食作るか考えるね。
26|茉莉：不过有的长得不好，味道可能差点，你尝过再决定要不要。|Some haven't grown well and might not taste as good. Try them before deciding.|ただ、育ちの悪い物は味も落ちるかも。食べてみてから決めてね。
27|薇尔莉娅：好。价钱就按平时的来，你也别因为我刚开店就少收。|All right. Charge your usual price. Don't give me a discount just because I've only opened.|うん。値段はいつも通りでいいよ。開店したばかりだからって、安くしなくていいから。
29|薇尔莉娅：我怕你不好意思收。咱们熟归熟，菜钱还是要付的。|I was afraid you wouldn't want to charge me. We're friends, but I should still pay for the vegetables.|お金を取りにくいかなって。知り合いでも、野菜代はちゃんと払いたいの。
30|露米：你先听听报价再说，别一口就答应了。|At least hear the price before you agree to it.|まずは値段を聞いてからにしなさいよ。すぐにうんって言わないで。
34|薇尔莉娅：那回程也能挣点钱，运费就没那么难凑了。|If we earn something on the return trip too, the freight will be easier to cover.|帰りの便でも稼げたら、船代も出しやすくなるね。
38|薇尔莉娅：面粉还没到，先不卖了。省得客人白等。|No bread until the flour arrives. I don't want people waiting for food I can't make.|小麦粉が届くまではお休み。作れないのに待たせちゃ悪いから。
''')
rows('chapter_03', '''
12|茉莉：我那边分两批浇，能省一点水。不过收成肯定会少，得提前跟订菜的人说。|I'll water mine in two batches to save some water. The harvest will be smaller, so I'll warn my buyers.|私の畑は二回に分けて水をやるね。少し節約できるけど収穫は減るから、注文した人に伝えておかないと。
16|茉莉：嗯，得先算好够不够水。我去年就种多了，最后死了两盘苗。|Yes, check there's enough water first. I planted too much last year and lost two trays of seedlings.|うん、水が足りるか考えないとね。私は去年植えすぎて、苗を二鉢分枯らしたの。
20|皮普：这条沟里还埋着灯线。你看这些孔，水门和灯架原来是一起装的。|There are lamp cables buried here too. These holes show the gate and lamp frames were installed together.|この溝には灯の線も埋まってる。この穴を見ると、水門と灯架は一緒に取り付けられたみたいだ。
21|余烬：边上都熔了，像是烧过。不是用久了自然坏的。|The edge has melted, like it's been burned. This isn't ordinary wear.|端が溶けてる。焼けたんだろう。古くなっただけじゃ、こうはならない。
23|余烬：也可能是电线太热烧的。还没拆开，我也说不准。|Overheated wiring could have done it too. I won't know until it's opened up.|線が熱くなって焼けたのかもしれない。開けてみないと、まだわからないな。
27|薇尔莉娅：这样明晚就没什么像样的菜了。|That doesn't leave much for tomorrow's menu.|これだと明日の夜、ちゃんとした料理があまり出せないな。
30|陶陶：这不是挺好吗？昨天你那两道炖菜，吃起来都差不多。|Sounds fine to me. Yesterday's two stews tasted almost the same.|いいじゃないか。昨日の煮込み二品は、どっちも似た味だったし。
''')
rows('chapter_04', '''
13|薇尔莉娅：可灯一直不修，以后每趟船都得等，种苗还会坏啊。|But if the light stays broken, every boat has to wait. We'll keep losing seedlings.|でも灯を直さなかったら、船が来るたびに待つんでしょう。苗もまた傷んじゃう。
16|余烬：哪些是你真看出来的，哪些只是猜的，要说清楚。|Be clear about what you've checked and what you're only guessing.|確かめたことと、ただの予想は分けて話してくれ。
21|萤萝：在南方养伤。我们一直有通信，我也会把巡灯的记录寄给她。|She's recovering in the south. We still write, and I send her my lamp inspection records.|南の方で療養してる。ずっと手紙をやり取りしてて、私の見回りの記録も送ってるの。
23|萤萝：知道。她问过好几次修得怎么样了，我总说还在筹钱。|She knows. She's asked how repairs are going several times. I keep saying we're raising the money.|知ってる。修理はどうなったって何度も聞かれたけど、まだお金を集めてるって返すばかりで。
25|萤萝：也寄过种子。她身体好多了，还能在家种点花，我就放心些。|We exchange seeds too. She's feeling better and growing flowers at home. That's a relief.|種も送ってくれるよ。体調がよくなって家で花も育ててるって聞いて、少し安心した。
30|余烬：这是改接的记号。线从这里断开，换了个接法。|These marks show a wiring change. The lines were disconnected here and joined differently.|配線を変えた印だ。ここで線を外して、別のつなぎ方にしてる。
''')
rows('chapter_05', '''
12|奥萝：我知道。当时让它继续开着的单子，是我签的。|I know. I signed the order to keep it running.|わかってる。動かし続ける許可を出したのは私よ。
14|皮普：六条路都靠她一个人盯着？怪不得她连觉都睡不好。|She had to watch all six branches herself? No wonder she couldn't sleep properly.|六本全部、一人で見てたの？ それじゃ、ちゃんと眠れないよ。
23|奥萝：那时候我总说修好再解释。结果一直没修成，大家一提钱就吵，后来我也不敢再提了。|I kept saying I'd explain after the repairs. They never happened. Every money discussion became an argument, and I stopped bringing it up.|直ったら説明すると言い続けてた。でも直らないまま、お金の話をするたびにけんかになって。私も言い出せなくなったの。
24|陶陶：种田的着急没水，跑船的着急没灯。大家都难，慢慢就只说自己那边的事了。|Farmers needed water, boat crews needed lights. Everyone was struggling, and we ended up only talking about our own problems.|畑には水が、船には灯が必要だった。皆大変で、だんだん自分の困り事ばかり話すようになったんだ。
26|皮普：按后来这张图修，还是得有人守着，一晚上都不能走。|If we use the later plan, yes. Someone would have to stay there all night.|後から変えた図面通りに直すなら、そう。一晩中、誰かがいないと。
29|萤萝：好吧，我连饭都经常顾不上吃。再加夜班，确实撑不住。|All right. I barely find time to eat as it is. Night shifts too would be too much.|うん。今だってご飯を食べそびれるくらいだもんね。夜番まで増えたら、もたないか。
32|薇尔莉娅：贵多少，先算清楚吧。还有守夜要多少人、每个人守多久，也一起算。|Let's find out how much more. And work out how many people would have to keep watch, and for how long.|どれくらい高くなるか、まず計算しよう。夜番に何人必要で、一人何時間になるのかも。
33|露米：还有以前欠的材料钱。不能只算新修的，把旧账放着不管。|And the materials we still owe for. We can't budget new repairs and ignore old debts.|前の材料代もまだ残ってる。新しい修理代だけ計算して、昔の借りを放っておけないわ。
''')
rows('chapter_06', '''
13|薇尔莉娅：应该够了，剩下的我再想办法。|That should be enough. I'll work something out for the rest.|たぶん足りる。残りは私がなんとかするよ。
20|陶陶：你先把饭吃了。饿着肚子忙，更容易忘事。|Eat first. You're more likely to forget things if you're hungry.|先にご飯を食べよう。空腹で働いてると、余計に忘れっぽくなるよ。
21|澪：商队催菜单了。这封信寄出去，菜名和份数可就不能随便改了。|The merchants are asking for the menu. Once this letter goes out, we can't keep changing the dishes and quantities.|商隊が献立を急いでる。この返事を出したら、料理と数は簡単には変えられないよ。
34|薇尔莉娅：我知道谁都不是故意的，可这样一来，答应他们的菜就凑不齐了。|I know nobody meant for this to happen, but now I can't make the menu I promised.|誰もわざとじゃないのはわかってる。でも、これじゃ約束した料理が揃わない。
38|薇尔莉娅：我就是想把这次做好，让他们以后还愿意来。连价目表我都写好了。|I just wanted this to go well so they'd come back. I've even finished the price list.|今回うまくやって、また来たいって思ってほしかったの。値段表ももう書いたのに。
39|露米：可南瓜还在地里，鱼也没订够。你答应得太早了。|But the pumpkins are still growing, and you haven't secured enough fish. You promised too soon.|でもカボチャはまだ畑だし、魚も足りない。約束するのが早すぎたのよ。
''')
rows('chapter_07', '''
4|薇尔莉娅：天气确实不好，可食材还没订齐，我就答应了。这个也得告诉他们。|The weather's bad, yes, but I agreed before I'd secured the ingredients. They should know that too.|天気が悪いのは本当。でも食材を揃える前に引き受けたのは私。それもちゃんと伝えたい。
7|澪：会吧。他们愿意改成十二个人，就是还想来尝尝。|I think so. They offered to come as twelve because they still want to try your food.|あると思うよ。十二人でもいいって言ったのは、まだ食べてみたいからでしょう。
17|薇尔莉娅：谢谢。我还以为退了宴席，连平时的生意也要做不下去了。|Thank you. I thought cancelling the banquet might mean I couldn't keep the everyday business going either.|ありがとう。宴会を断ったら、普段のお店まで続けられなくなるかと思ってた。
18|芦苇：平时该怎么做还怎么做。我卖鱼，你做饭，大家总得吃饭吧。|We can carry on as usual. I sell fish, you cook. People still need dinner.|いつも通りでいいよ。僕は魚を売って、君は料理する。皆、ご飯は食べるんだから。
25|萤萝：今天我不赶着回去，晚饭能在这儿吃吗？|I'm not rushing off today. Can I eat dinner here?|今日は急いで帰らなくていいの。ここでご飯を食べてもいい？
26|薇尔莉娅：当然能。那我就不打包了？|Of course. No takeaway box, then?|もちろん。じゃあ、持ち帰り用に詰めなくていい？
27|萤萝：嗯，你也给自己盛一碗吧。忙到最后，锅里又没你的份了。|Right. Serve yourself a bowl too, or there'll be none left for you by the time you're done.|うん。自分の分もよそっておいて。最後まで忙しくしてたら、また鍋が空になっちゃうよ。
29|奥萝：修月环的钱也算好了。只换主环便宜，但要整晚守着。把支路分开修要贵些，不过能先修一部分。|We have the repair costs. Replacing just the ring is cheaper but needs an overnight watch. Separate branches cost more, but we can start with two.|月環の修理代も出たわ。主環だけなら安いけど夜番が必要。支線を分けると高くなるけど、一部から直せるの。
33|露米：那先修这两段。用了多少钱、干了多久，都记下来，剩下的以后再说。|Let's do those two first. Record the money and time they take; we'll discuss the rest later.|じゃあ、まずその二つね。費用もかかった時間も記録して、残りは後で考えましょう。
34|薇尔莉娅：修理那几天的午饭，我能做。不过人数得先定好，我还得留菜给晚上的客人。|I can make lunch on repair days. But I need the numbers beforehand, so there's food left for the evening guests.|修理の日のお昼は私が作れるよ。ただ、人数は先に決めてね。夜のお客さんの分も残さないと。
38|萤萝：这回你倒是先问清楚了。|You've asked about the details first this time.|今回はちゃんと、先に確かめたんだね。
39|薇尔莉娅：嗯，再来一次，我这点本钱可赔不起了。|Yes. I can't afford to lose that much again.|うん。もう一度あんなに損をしたら、お金が足りなくなっちゃう。
''')
rows('chapter_08', '''
6|星芒：我在河口测过亮度了。不用照山顶那么亮，太亮了水面反而晃眼。|I've checked the brightness at the river mouth. It needs less light than the summit; too much makes glare on the water.|河口の明るさも測ったよ。山頂ほど明るくなくていい。強すぎると水面がまぶしくなるから。
10|薇尔莉娅：放心，你那份有。没放葱的是霜铃和星芒的。|Don't worry, yours has onions. The ones without are for Yuki and Aster.|大丈夫、あなたの分には入ってる。ネギ抜きはユキとアスターのだよ。
15|奥萝：第二段比原先算的多花了一成。旧水渠底下有塌掉的石头，清出来费了不少工夫。|The second section cost ten percent more than expected. Clearing the fallen stone under the old channel took extra work.|二つ目は予定より一割高くなったの。古い水路の底に崩れた石があって、片付けに手間がかかって。
16|余烬：那层石头是我之前没看见。账上写清楚，多花的是清理的钱。|I missed that layer of stone. Mark the extra cost as clearance work.|あの石は見落としてた。増えた費用は片付け代だと、帳簿に書いておいてくれ。
17|露米：你昨天还做到天黑。多干的那几个小时，也得算钱。|You worked until dark yesterday too. Those extra hours need paying for.|昨日は暗くなるまで働いたでしょう。増えた時間の分も、ちゃんと払わないとね。
21|余烬：要是看不出来呢？|What if you can't tell what's wrong?|わからなかったら？
22|皮普：那就写上还没查清，把那条支路先关掉，等你来。|I'll note that it's unresolved, switch off that branch and wait for you.|まだ原因不明って書いて、その支線を止めて、あなたを待つよ。
23|余烬：嗯，别硬撑着让它亮。|Good. Don't keep it on just to make it work.|ああ。無理にともしたままにしなくていい。
32|星芒：她问我们有没有装总负荷的限制，免得同时用电太多。还提醒我们，旧图有个刻度印反了。|She asks if we've fitted a total load limit to prevent overloads. And warns that one scale on the old plan is reversed.|一度に使いすぎないよう、全体の負荷制限を付けたかって。それと、古い図面の目盛りが一つ逆だって。
34|星芒：就是你上周量过的那一处，你不是还说图上画错了吗？|The one you measured last week. You said the plan was wrong, remember?|先週、測り直した所。図面が間違ってるって言ってたでしょう？
37|薇尔莉娅：还有，大家中午都吃上饭了，晚上也不用一直守着。让她别惦记这个。|Tell her everyone's getting lunch, and nobody has to stay up there all night. She needn't worry about that.|皆、お昼も食べてるし、夜も山に居続けなくていいって。それは心配しなくていいって伝えてね。
''')
rows('chapter_09', '''
11|星芒：传消息的线没坏，是浮标卡住了，所以水位报得不准。我已经记下了，别的支路还能用。|The signal line's fine; the float is stuck, so its water reading is wrong. I've logged it. The other branches still work.|信号の線は切れてない。浮きが引っかかって水位がずれてるんだ。記録しておいたよ。他の支線は使える。
14|奥萝：我跟下游两家说过了，今晚不住临河仓房。露米，镇里的备用物资单给你，麻烦你对一下数。|I've told the two households downstream to stay out of the riverside storehouse tonight. Lumi, here's the town reserve list; could you check the quantities?|下流の二軒には、今夜は川沿いの倉庫を使わないよう伝えたわ。ルミ、町の備蓄一覧よ。数を確かめてもらえる？
21|皮普：漂木清掉了，闸门也能开了。不过旧支架裂了，余烬说今晚先别再往大了开。|The driftwood's clear and the gate opens. But the old bracket's cracked, so Ember says not to open it any further tonight.|流木は取れたし、水門も開くよ。でも古い支えにひびがあるから、今夜はこれ以上開けないって。
28|薇尔莉娅：平时来吃饭的照常付。临时没地方住、镇里安排过来的那几份，我单独记账。|Regular customers pay as usual. Meals for people the town sends here for shelter go on a separate bill.|普段のお客さんはいつも通り。泊まる所がなくて町から来る人の分は、別に帳簿をつけるね。
31|星芒：现在只接好了水门和河口，用得也不多，还没到上限的一半。我刚查过。|Only the gate and harbor are connected now, and they're using less than half the limit. I've just checked.|今つながってるのは水門と河口だけで、使ってる量も上限の半分以下。さっき確かめたよ。
32|萤萝：嗯，我知道现在有人轮着看。就是一听到下雨，还是忍不住担心。|Yes, I know we're taking turns now. Rain still makes me worry, that's all.|うん、今は交代で見てるってわかってる。ただ、雨が降るとまだ心配しちゃうんだ。
36|薇尔莉娅：好，那就等水小一点。明天先做南瓜炖饭，面粉到了再烤面包。|All right, we'll wait for the water to settle. Pumpkin rice stew tomorrow, and bread once the flour gets here.|うん、水が落ち着くのを待とう。明日はカボチャの煮込みご飯で、小麦粉が来たらパンを焼くね。
38|薇尔莉娅：能，锅里还有呢。忙完了就坐下吃吧。|Yes, there's plenty in the pot. Sit down for a bowl when you're done.|いいよ、鍋にまだあるから。仕事が終わったら座って食べてね。
''')
rows('chapter_10', '''
8|薇尔莉娅：听你们都开始安排明天的事，我才觉得这场雨真过去了。|Hearing you all make plans for tomorrow, it finally feels like we've got through the rain.|皆が明日の予定を話してると、やっと雨を乗り切ったんだなって思う。
9|陶陶：是啊。昨晚一直忙到半夜，今天总算能好好吃顿饭了。|Yes. We were busy half the night yesterday. Today we can finally sit down to a meal.|そうだね。昨日は夜中まで忙しかったけど、今日はやっと落ち着いてご飯が食べられる。
10|奥萝：对了，你试着开店也快一年了。还想继续租吗？我把新租约带来了，还是按月交钱。|That reminds me, your trial year's nearly up. Would you like to stay? I've brought the new lease; rent is still monthly.|そうだ、試しに始めてもうすぐ一年ね。これからも借りる？ 新しい契約書を持ってきたわ。家賃は引き続き月払いよ。
14|奥萝：当然可以，又没规定你天天开门。|Of course. There's no rule saying you have to open every day.|もちろん。毎日開ける決まりなんてないもの。
15|薇尔莉娅：我知道，就是忙起来老觉得，少开一天会少赚好多。现在想想，也不能一直这么干。|I know. When I'm busy, a day off feels like losing so much income. But I can't keep going like this every day.|わかってるんだけど、忙しいと一日休むだけでずいぶん損した気がして。でも、毎日この調子じゃ続かないね。
23|奥萝：好，租约放这儿。你不急着扩院子，先把店做稳当。|Good. Here's the lease. There's no hurry to expand the yard; give the eatery time to settle in.|よかった。契約書はここに置くわ。庭を広げるのは急がなくていいから、まずはお店を落ち着かせましょう。
24|薇尔莉娅：嗯，先把现在这些菜做好。等忙得过来，再加新的。|Yes. I'll get the current menu right, then add more when I can manage it.|うん、まずは今の料理をちゃんと作る。余裕ができたら、新しいのを増やすよ。
25|萤萝：那我还想吃你上回做的蘑菇炖饭。下回有吗？|I'd love that mushroom rice stew you made last time. Will you make it again soon?|この前のキノコの煮込みご飯、また食べたいな。今度もある？
26|薇尔莉娅：有，等这批蘑菇到了就做。先给你留一份。|Yes, once the next mushrooms arrive. I'll save you a portion.|うん、次のキノコが届いたら作るね。一食分、取っておく。
28|奥萝：有，我来回信。她这次是来玩的，不用再住值守站了。|Yes, I'll write back. She's coming to visit this time; she doesn't need to stay at the watch station.|あるわ。私が返事を書く。今回は遊びに来るんだから、詰所に泊まらなくていいの。
30|余烬：我也想让她看看修好的支路。不过先吃饭、歇够了，再慢慢看。|I'd like her to see the repaired branches too. But after she's had dinner and a proper rest.|直した支線も見てほしいな。でも飯を食って、ゆっくり休んでからでいい。
41|芦苇：还有煎鱼，刚做好，带过来时还烫手呢。|And fried fish, fresh from the pan. It was still too hot to hold when I brought it.|焼き魚もあるよ。焼きたてで、持ってくる時はまだ熱かったんだ。
44|萤萝：拿好了，你的也在这儿。今天不用你忙，坐着吃就行。|They're ready. Yours is here too. You're off kitchen duty today; sit down and eat.|もう出してあるよ。あなたの分もここ。今日は料理しなくていいから、座って食べて。
45|薇尔莉娅：这锅汤也是你们做的？|Did you make this soup too?|このスープも皆が作ったの？
46|澪：我煮的，陶陶在旁边帮我看着。|I did. Toma kept an eye on it with me.|私が作ったんだ。トマに隣で見てもらいながらね。
47|薇尔莉娅：你今天还有空做饭啊？|You had time to cook today?|今日は料理する時間もあったんだ？
48|澪：船还没来，我也歇一会儿。你先尝尝咸淡怎么样。|The boat's not here yet. I'm taking a break too. Tell me what you think of the seasoning.|船はまだ来ないし、私も少し休憩。味はどうかな？
''')

def write_revision():
    combined = []
    for scene in manifest['scenes']:
        lines = sources[scene['id']]
        assert len(lines) == len(translations[scene['id']])
        (DRAFT / scene['file']).write_text('\n'.join(lines) + '\n', encoding='utf-8')
        if scene['id'] != 'opening':
            combined += lines
    (DRAFT / '主线剧情对白.txt').write_text('\n'.join(combined) + '\n', encoding='utf-8')
    translated = []
    for scene in manifest['scenes']:
        translated.append('@' + scene['id'])
        translated += ['|'.join(pair) for pair in translations[scene['id']]]
    (DRAFT / 'translations_en_ja.txt').write_text('\n'.join(translated) + '\n', encoding='utf-8')
    (OUT / 'reviewed_changes.json').write_text(json.dumps(changes, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Updated {len(changes)} dialogue lines.')

if __name__ == '__main__':
    write_revision()
