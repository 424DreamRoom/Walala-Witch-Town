extends RefCounted
## Yingluo speaks about the town and the current chapter; input belongs in docs.
const C = preload("res://Scenes/Campaign/campaign_state.gd")
const NAME := "萤萝 · 巡灯员"
const PORTRAIT := "res://Art/Characters/NPC32/guides/yingluo.png"
const SPRITE := "res://Art/Characters/NPC32/guides/yingluo.png"
const WELCOME := [
	"我是萤萝，负责照看镇上的月灯，也替大家保管那些尚未写完的故事。",
	"你就是收到那封信的小女巫吧。这间小屋为你留了很久，今天终于有了主人。",
	"月环熄灭以后，山谷失去了四季的回声。田地荒了，旧食堂也不再有人等候。",
	"那本旧食谱留下了一条线索：被大家记住的晚餐，能让月灯重新发光。",
	"镇上的人仍记得食堂飘出热汤香气的夜晚。也许，你的第一顿晚餐会成为新故事的开头。",
	"这本手记曾记着每一户人家的灯火。如今还有许多空白，不过，你的故事已经开始了。"
]
const CHAPTERS := [
	"旧食堂的炉火熄了很久。林间的蘑菇与莓果，是这座小镇最熟悉的味道。",
	"食堂在傍晚亮灯，一直温暖到夜里。第一桌晚餐，值得被好好记在手记上。",
	"月芽农场的土壤仍然肥沃。作物记着季节与雨水，也记着每天照料它的人。",
	"石谷的矿脉连接着旧闸门。余烬炉里的火，已经等这些矿石很久了。",
	"水道恢复后，鱼群也有了归途。不同水域与时节，会留下不同的鱼影。",
	"每天的问候、合心意的礼物和一顿晚餐，会让陌生的面孔慢慢变成熟悉的朋友。",
	"旧械遗址里散落着小镇过去的零件。那些安静的齿轮，仍记得曾经的心跳。",
	"更多座位、更多菜香，让旧食堂有了新的模样。月灯食堂的名字，已经传到了山上。",
	"山径上的风铃还在响。那些散落的旧物，记着月环熄灭那晚的风雪。",
	"四季的作物各有自己的颜色。十二种收获，将为旧星图添上完整的季节。",
	"观星台的月晶还缺最后几片。每一片微光里，都有小镇共同生活的记忆。",
	"长桌已经备好。最后三道宴席料理，将让所有人的故事在同一盏灯下相遇。"
]
const FAREWELL := "手记的最后一页已经写满。灯火还会亮着，往后的每一天，都属于你和这座小镇。"
const TOPICS := [
	{"chapter": 0, "name": "林间食材", "lines": ["林间的蘑菇和莓果会随日子重新生长。新鲜的收获，是厨房最初的储备。"]},
	{"chapter": 1, "name": "食堂灯火", "lines": ["食堂的晚餐时段是十八时到二十二时。菜单、食材和客人的口味，共同决定一晚的烟火气。", "一份完成的料理对应一位等待的客人。满意的晚餐会留下金币、声望与好感。"]},
	{"chapter": 2, "name": "农场四季", "lines": ["种子各有适合的季节，湿润的土壤让作物一天天长大。有些作物在收获后，还会结出新的果实。"]},
	{"chapter": 3, "name": "小镇建设", "lines": ["木材、矿石与铁锭支撑着小镇的修复。建设仓储保存着食堂和农场所需的材料。"]},
	{"chapter": 4, "name": "水边来信", "lines": ["鱼群随季节、时段和水域变化。每一种鱼获，都可能成为餐桌上的新味道。"]},
	{"chapter": 5, "name": "居民心事", "lines": ["居民会记得每天的第一次问候，也各有珍爱的礼物。熟悉之后，旧物背后的故事才会慢慢浮现。", "每个人的心事都有自己的节奏。小镇的主线与居民的故事，可以各自慢慢延续。"]}
]

static func current_lines(s) -> Array:
	var q := C.current_main(s)
	if q.is_empty(): return [FAREWELL]
	var progress := mini(q.goal, C.metric(s, q.metric))
	var result: Array = [CHAPTERS[s.campaign.chapter], {"source": "当前目标：%s · %d/%d", "args": [q.objective, progress, q.goal]}]
	if progress >= q.goal: result.append("这一页的心愿已经实现，今晚的月灯又亮了一些。")
	return result

static func ready(s) -> bool:
	var q := C.current_main(s)
	return not q.is_empty() and C.metric(s, q.metric) >= q.goal
