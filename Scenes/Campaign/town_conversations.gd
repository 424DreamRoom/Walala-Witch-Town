extends RefCounted
## Small daily exchanges develop the existing residents without advancing a quest.
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const Witch = preload("res://Art/Character/Storybook/WalalaWitchAseprite32/witch_animation.gd")
const EXCHANGES := {
	"mori": ["我在种子袋上缝了年份。哪一年的春天太急，拆开线就想起来了。", "那今年这袋，留一截宽松的线吧。我的第一块田也不想赶时间。"],
	"ember": ["铁离了炉子还会发红，人却总以为不冒火就是凉了。今天又烫坏一只袖口。", "今晚那碗汤，我也会等它不烫手再端出来。袖口已经很有说服力了。"],
	"nagi": ["早上那条鱼没咬钩，倒把我的浮标拖到芦苇里睡了一觉。", "它比我懂得休息。今天的菜单，看来少了一位挑剔的客人。"],
	"lumi": ["新货架空了一层。我以前总急着填满，现在觉得空着也方便看清少了什么。", "我的菜单也还空着几行。先把写上的几道做好，空白就不难看了。"],
	"aster": ["我把昨晚的星位抄错了一格。纸上的月亮走得很快，天上的倒很耐心。", "那张错的纸别扔。等我的账本也算歪了，我们还能比一比。"],
	"toma": ["我熬汤时总爱多放一把盐，手比舌头更记得旧厨房的份量。", "我也是。只做一小锅的时候，原来得重新学一遍自己的手。"],
	"pip": ["新齿轮转起来没响，我反倒蹲着听了半天。习惯了坏声音，安静也让人不放心。", "今晚碗盘要是也安静一会儿，我大概会忍不住再数一次客人。"],
	"reed": ["水沟今天只湿了一半。另一半留给草根，满满当当也不总是好事。", "听着像我的备料台。留一点空地方，锅盖才有地方落下。"],
	"yuki": ["冬天的围巾还没收。我每次想收，摸到它软软的边，又想多留一天。", "那就留着。店里也有一条旧围裙，我还舍不得把它叠到箱底。"],
	"orla": ["今天账上最整齐的，是写错后划掉的那一列。每个零都站得特别直。", "我的第一张菜单也涂得很满。以后再看，应该能想起当时为什么改。"]
}

static func exchange(s, id: String) -> Array:
	if not EXCHANGES.has(id): return []
	var npc := C.entry(C.D.npcs, id)
	return [
		{"source": EXCHANGES[id][0], "args": [], "speaker": npc.name, "portrait": "res://Art/Characters/NPC32/portraits/" + id + ".aseprite", "portrait_region": Rect2(0,0,32,32)},
		{"source": EXCHANGES[id][1], "args": [], "speaker": s.campaign.player_name, "translate_speaker": s.campaign.player_name == C.DEFAULT_PLAYER_NAME, "portrait": Witch.SHEET, "portrait_region": Rect2(0,0,32,32)}
	]
