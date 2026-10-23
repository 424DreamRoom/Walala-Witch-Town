from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

root=Path(__file__).resolve().parents[2]
out=root/'output/project_polish'
reports=[json.loads(p.read_text(encoding='utf-8')) for p in sorted((out/'regressions').glob('*/report.json'))]
assert len(reports)==12 and all(r['passed'] for r in reports)
headless=json.loads((out/'headless.json').read_text())
capture=json.loads((out/'capture.json').read_text())
assert headless['failures']==capture['failures']==0
assets=json.loads((out/'asset_check.json').read_text())
assert assets['protected_hashes_unchanged']
(out/'regressions/report.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

board=Image.new('RGB',(1280,768),'#2c2927')
draw=ImageDraw.Draw(board)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)
for i,(file,title) in enumerate([
    ('grove.png','01 / Forest gathering'),
    ('observatory_map.png','02 / Region atlas'),
    ('recipes_en.png','03 / Menu and available stock'),
    ('dialogue_zh_CN.png','04 / Residents and daily conversation')]):
    x,y=i%2*640,i//2*384
    draw.text((12+x,5+y),title,font=font,fill='#e6d5b7')
    board.paste(Image.open(out/file).convert('RGB'),(x,y+24))
board.save(out/'review_board.png')
names={'story':'十章主线与完整开场','service':'餐厅营业','farm':'农场与资源清理','save':'存档与跨日边界','map':'地图与输入','hotbar':'快捷栏','equipment':'法杖与背包升级','ambient':'场景及家具动画','residents':'居民路线与避雨','seasonal':'季节与品质','cooking':'360 道料理及仓储','ui':'HUD、对话和设置'}
table='\n'.join(f"| {names[r['suite']]} | {r['checks']} | 通过 |" for r in reports)
report=f'''# 项目整合优化验收

2026-10-22。修改已接入当前 Godot 工程，使用隔离的设置和存档完成验证。

## 完成内容

- 人物呈现：沿用工作区现有魔女和十位居民素材，头像整数倍显示；居民活动覆盖扩建后的完整城镇。
- 剧情：十位居民各新增一组双人日常交流，共二十句，四种语言；当天重复交谈不重复发放关系数值，抵达日保留原开场。
- 场景与地图：六个探索区域的独立路线、水域、地标和资源位置；实际场景、碰撞、脚步与地图预览共用布局，旧位置自动恢复到安全地面。
- UI：真实可制作份数、材料持有量/需求量、可制作筛选、今日偏好、居民口味和探索目的地浏览；预览不改变进度。
- 流程与玩法：偏好实际参与点单和奖励，避开忌口，照料产生品质收益，售罄且无未完成事务时可结束营业，真实跨日更新天气。
- 交互修复：柜台按钮不会同时触发世界交互；可摆放书桌恢复既有烛火动画。

## 验证结果

专项无界面集成：{headless['checks']} 项，0 失败。包含真实跨日晴雨雪切换、全年预报、六区可达性、所有新增对白的四语言排版、地图只读浏览、实际结束营业点击和隔离存档。

实际渲染与截图：{capture['checks']} 项，0 失败。检查中文、英文、日文、繁体中文，并逐项查看区域、地图、食谱、居民及对话画面。

现有系统回归共 {sum(r['checks'] for r in reports)} 项，12 组全部通过：

| 系统 | 检查数 | 结果 |
| --- | ---: | --- |
{table}

翻译：2400 条、3 个表，生成内容一致；占位符、BBCode 和源码覆盖检查通过。

素材：连续两次重建的 {assets['generated_files']} 个生成文件哈希一致；`MyArt/` 的 {assets['protected_files']} 份原稿与改动前 SHA-256 完全一致。生成目录始终位于 `MyArt/` 外。

Godot 4.7.2 日志包含环境中的系统根证书读取提示；最终专项及回归均无脚本错误。测试中的旧版租约、开场、菜单、法杖颜色和首章目标前提已同步当前流程。

## 文件

- 项目维护说明：`Scenes/Gameplay/PROJECT_POLISH.md`
- 场景布局与导出：`Art/WorldPolish/`；原稿保护规则及构建说明见该目录 README。
- 效果拼图：`output/project_polish/review_board.png`
- 六区概览：`Art/WorldPolish/regions_overview.png`
- 集成结果：`output/project_polish/headless.json`、`capture.json` 与对应日志。
- 回归明细：`output/project_polish/regressions/report.json` 与各系统日志。
- 原稿核对：`output/project_polish/myart_before.json`、`myart_after.json`。

工作区已有的未提交主线、角色和素材修改保留。此次没有改写 `MyArt/`、输入映射或玩家正式存档。
'''
(out/'REPORT.md').write_text(report,encoding='utf-8')
print('FINAL REVIEW',headless['checks'],capture['checks'],sum(r['checks'] for r in reports),'checks; all passed')
