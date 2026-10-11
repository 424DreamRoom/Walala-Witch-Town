import json,pathlib,re
BASE=pathlib.Path(__file__).parent
META=[
('luo','洛桑','山间货车司机','用机械坏脾气掩饰花费，正事报实际重量。','建立不靠欠情的运输合伙。','把能撑一趟当成节省。','fu'),
('fu','芙蓉','山口茶棚老板','困时短句，账目细，说感谢不用客套承诺。','有固定的休息上午。','会连合理互助也推开。','luo'),
('chen','陈漪','湿地测水员','报日期位置，认错逐项更正。','留下可被质疑和使用的水源记录。','以为数字正确解释就充分。','mo'),
('mo','墨池','渔网修补人','手艺词具体，不爱被称匠心。','获得稳定报酬。','把机器都当成否定。','chen'),
('jiang','姜禾','流动药草商','讲疗效先讲不能治什么，讲价嘴利。','诚实也能挣钱。','羞于承认需要利润。','hu'),
('hu','胡岑','巡山员','方向距离准确，身体状况含糊。','建立巡山轮班。','将求助当成年老判词。','song'),
('song','松果','十二岁山民孩子','想到就说，谈姐姐偷偷改口。','做一件姐姐用得上的礼物。','觉得罕见才贵重。','jiang'),
('niao','鸟笛','成年候鸟记录员','鸟名准确，谈漏记先绕两句。','留下含局限的可靠记录。','怕遗漏损害一切。','luye'),
('xia','夏满','季节旅居画师','爱谈构图价钱，拒绝悲情想象。','画出能被认领的肖像。','把画不好当审美。','qiu'),
('zhao','赵汐','码头货票员','数字越乱语速越快，计较半勺糖。','分清工作和婚后责任。','把复核当能力否定。','wenchao'),
('hai','海葵','旧灯罩清洁师','品相兴致高，安全干脆。','旧灯罩继续使用。','高估收藏空间。','ji'),
('wenchao','闻潮','船上厨师','用饭菜班次说事，玩笑后补真要求。','有自己的工作并分担家务。','把会做饭当包办照料。','zhao'),
('bo','柏安','石谷矿工','工时列事实，厌恶悲壮讲法。','争取明确停工条件。','证据齐才说不适。','tie'),
('tie','铁桃','矿工合作社理事','争吵仍记诉求，账边夹菜种。','算清账也有菜圃。','空闲都给公事。','bo'),
('cen','岑月','观星台档案修补员','严格区分原文推测，私下嫌旧纸味。','保留可核对的无结尾史料。','把困惑当读者不认真。','xun'),
('xun','荀叶','气象站见习','预报过于肯定，更正逐字斟酌。','发布有范围的预报。','把不知道当不配任职。','cen'),
('pao','泡桐','旧械仓库守门人','用往事定位物件，找不到先嫌人急。','按期退休。','把需要与无法离开混淆。','ji'),
('luye','鹿野','测绘员','先算最短，反问时摸尺。','画实际走得通的地图。','忽略绕路理由。','niao'),
('qiu','秋水','成年裁衣模特','谈衣料边界直接，亲近有坏笑话。','带回经验也保留自己的去处。','受评判就急着证明离开正确。','xia'),
('ji','季平','外来餐具采购员','拆项报价，承诺具体日期。','长期采购手工餐具。','将可量化当全部成本。','hai')]
def build():
 notes={
 'luo':'与芙蓉以分趟运输、仓租和明确合同合伙，不再靠展示劳累获得运费。',
 'fu':'与洛桑互相计较成本，也约定茶棚休息时不由货车司机擅自开门营业。',
 'chen':'起初公告影响墨池卖鱼；接受他的在地观察，同时区分实测与居民记录。',
 'mo':'陈漪购买机器网做试验，与墨池约定改边绳的实际用途和付费，仍会争水尺位置。',
 'jiang':'识破胡岑隐瞒腿痛，不替他诊断或夸大药草作用；巡山员也尊重她自己谈退货。',
 'hu':'松果会指出他缩减路线遗漏的居民；胡岑不把孩子当免费巡山帮手。',
 'song':'姜禾不收误认的药草，按折纸袋的劳动付钱，帮助他分清礼物与夸大的付出。',
 'niao':'与鹿野互相核对记录缺口和地图权限，公开图不把借用土地变成公共通路。',
 'xia':'向秋水付模特费，按约定用途画衣样，拒绝将她返乡编成悲情推销。',
 'zhao':'与配偶闻潮从错票争执走到明确家务、工作材料和小额自由支出的试行规则。',
 'hai':'与季平试卖磨边装饰片，接受绿褐色滞销，保留喜欢也承担占用空间的成本。',
 'wenchao':'与配偶赵汐学习询问需要，不以包办饭菜换取赞赏，短航线工作提前分配家事。',
 'bo':'与铁桃公开工时证据和反对意见，争取最低收入与停工规则，也接受真实收入差额。',
 'tie':'柏安支持她设定菜圃时间，不将自己的私地变成另一个合作社项目。',
 'cen':'与荀叶互读说明和预报，指出术语不清与不确定范围，约定各自工作的边界。',
 'xun':'岑月陪他面对更正，但不替他张贴或承担预报；荀叶也指出档案说明的长句。',
 'pao':'季平要求盘点按工时付费、找不到给明确答复，不把退休交接叫无偿贡献。',
 'luye':'鸟笛用绕路、田地借用和观测缺口纠正最短路线思维，鹿野也核对公开信息范围。',
 'qiu':'与夏满按合同合作衣样，允许朋友来往而拒绝免费充当人物素材或返乡象征。',
 'ji':'海葵指出报价、颜色与物件安全的具体问题，季平承担库存与包装试错的采购风险。'}
 npcs=[dict(id=i,name=n,role=r,voice=v,desire=d,blind_spot=b,relationships=[dict(npc_id=p,note=notes[i])]) for i,n,r,v,d,b,p in META]
 scenes=[]
 for path in sorted(BASE.glob('valley_residents_part*.py')):
  for section in path.read_text(encoding='utf-8').split('\n@@')[1:]:
   header,body=section.strip().split('\n',1)
   sid,title,season,location,kind,previous=header.split('|')
   lines=[dict(zip(('speaker','text'),line.split('：',1))) for line in body.splitlines() if line.strip()]
   participants=list(dict.fromkeys(x['speaker'] for x in lines if x['speaker']!='stage'))
   chapter=10 if '观星台' in location or '气象站' in location else 8 if '山道' in location or '山间' in location or '巡山' in location else 6 if '旧械' in location else 4 if '湿地' in location else 2 if '石谷' in location or '矿' in location else 0
   requires=[previous] if previous else []
   if sid.endswith('_05'):
    chapter=12
    requires.append('main_12_after')
   scenes.append(dict(id=sid,title=title,kind=kind,chapter_min=chapter,season=season,location=location,participants=participants,requires=requires,sets=[sid],lines=lines))
 index={s['id']:s for s in scenes}
 for _ in range(len(scenes)):
  changed=False
  for s in scenes:
   minimum=max([s['chapter_min']]+[index[r]['chapter_min'] for r in s['requires'] if r in index])
   if minimum!=s['chapter_min']:s['chapter_min']=minimum;changed=True
  if not changed:break
 payload=dict(group='valley',npcs=npcs,scenes=scenes)
 (BASE/'valley_residents.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print('scenes',len(scenes),'lines',sum(len(s['lines']) for s in scenes),'han',sum(len(re.findall(r'[\u4e00-\u9fff]',x['text'])) for s in scenes for x in s['lines']))
if __name__=='__main__':build()
