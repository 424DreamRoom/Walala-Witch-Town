# Lantern Town / 灯火街区小镇

2026-10-11 景观层已优化：草地疏密、庭院轮廓、喷泉铺地、河岸芦苇和 9 组景物；道路中央 8 处障碍移到路边。建筑、入口和地图尺寸保持一致。教学来源、重建方式及实机对比见 [地图场景美术记录](../../Art/Environment/Hearthwood/MAP_ART_NOTES.md)。

当前运行布局为 `Art/Environment/Hearthwood/town_layout.json` revision 4：1600×1536，面积为原来的两倍；16栋建筑、30条道路、9片街区。原有商业入口保留，东侧码头入口为 `(1592,652)`；新增街区包括东园花径、南坡书街、风车草甸和芦苇河畔。房屋通过不同屋顶轮廓、材质、门窗与门廊区分。重建与隔离验证见 `Art/Environment/Hearthwood/README.md`。下方早期原型记录保留作开发历史。

## revision 3 街区记录（2026-10-11）

小镇已从九宫格街道改为五片相连的街区：西郊农场道、中央月泉广场、东侧余烬工坊、南巷花园与河岸渡口。参考《星露谷物语》鹈鹕镇的分区与自然地形、以及《Fields of Mistria》的公共广场组织方式，重新设计原创坐标与道路，没有复制游戏地图或素材。

小女巫之家已搬到独立的月芽农场，小镇保留8栋建筑、16条道路及原出生点。沿西侧石路走到左边缘 `(8,364)` 自动进入农场，农场东侧出口回镇；家位于农场北侧，南侧有96格可耕地、水井和池塘。农场场景、种植操作及存档说明见 `Scenes/Farm/README.md`。杂货店仍在广场北面，铁匠铺在东侧河边，餐厅在南边庭院，码头入口在河岸木栈道。

区域之间采用道路连续延伸、边界切换的方式：西侧52像素石路接农场东侧，北侧34像素土路接野外南侧，东侧42像素木栈道接码头西侧。道路绘制超出画布，取消出口圆形收尾；触发区贴近边缘，出生点和返回点在路中央，地图总览也按对应边对齐。源码和像素检查见 `Art/Environment/Hearthwood/tools/validate_road_connections.py`，实机专项验证与截图见 `Scenes/Gameplay/run_verification.py` 的 `transitions` / `roads_capture` 模式。

唯一布局源为 `Art/Environment/Hearthwood/tools/build_town_layout.py`，结果写入 `town_layout.json`，包括建筑、装饰、道路、广场、河岸和6个功能入口。游戏入口及脚步材质读取同一份数据。旧存档若落进移动后的建筑或水面，会回到安全出生点；有效位置照常保留。

```powershell
python Art/Environment/Hearthwood/tools/build_town_layout.py
python Art/Environment/Hearthwood/tools/validate_town_layout.py --rebuild --screens
python Scenes/Businesses/run_verification.py town_capture
```

完整环境及室外重建最后都会重新应用新版街区。实机检查与截图位于 `Art/Environment/Hearthwood/Verification/TownPlan/`，日志为 `Verification/Businesses/town_capture.log`。参考：[Pelican Town](https://wiki.stardewvalley.net/Pelican_Town)、[Mistria 地图](https://fieldsofmistria.grandwiki.com/map/)。下面的九宫格道路及历史验证坐标属于旧版记录。

迁移农场前的验证记录（2026-10-10）：整镇窗口检查94项、经营流程93项、铁匠铺和商店63项、住宅56项、街区控制51项、存档87项均通过。21个静态目标可达，9栋房屋门前均能用真实移动物理走到，6个功能入口可进出并正确返回；河岸碰撞、道路脚步材质、雨雪及旧存档安全位置均已检查。11组原生640×360截图与1280×720窗口截图逐像素吻合；布局重建结果稳定，30项室内和野外原图保持一致。

## 当前环境美术

当前场景使用 `Art/Environment/Hearthwood/` 中的原创逐像素 PNG，街道、树木、野外、餐厅和农场沿用同一材质语言；绿屋顶的玩家住宅位于农场北侧，进出住宅和镇内功能建筑均需在门口按交互键（默认 F）。完整素材、绘制源与说明见该目录 README。旧版图片与生成器保留；重建当前美术使用 `Art/Environment/Hearthwood/tools/build_art.py`，农场使用 `tools/build_farm.py`。

当前小镇有84处独立布置的喷泉、花坛、路灯、长椅、信箱、池塘与庭院物件，入口使用图案木路牌；野外树木采用独立脚底Y排序与实体碰撞。室外单独重建使用 `Art/Environment/Hearthwood/tools/build_outdoors.py`，街区专用实机验证入口为 `Scenes/LanternLane/verify_town_plan.gd`。

以下为先前版本的布局与验证记录；当前道路、建筑坐标和碰撞以本页开头的新版布局为准。

LanternLane 现已重布局为正交 2D 斜俯视小镇：不是等距投影，也不是旧侧视街景的放大。1280×960 世界、640×360 原生视口，九间可见屋顶和正面的独立商铺，两条东西主街、两条南北街与外围环路。保留原创黄绿棋盘街区主题，不包含农场系统。

本轮没有修改 project.godot。开始时该文件已有用户设置的 LanternLane 主场景，原样保留；没有修改全局 InputMap。原验证截图和日志未覆盖。

## 启动

Godot 编辑器打开 `res://Scenes/LanternLane/lantern_lane.tscn`，F6 运行当前场景。场景在运行时组装，编辑器画布为空不代表游戏为空。

在项目根目录执行：

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --path . --resolution 1280x720 --scene res://Scenes/LanternLane/lantern_lane.tscn
```

- WASD / 方向键：支持八方向移动，同时按上下与左右键可斜走；斜向位移归一化，走路和跑步均与直走等速。
- Shift：跑步。R：返回北侧十字路口。
- F3：开关建筑、道具和地图边界碰撞显示。
- 1：晴天；2：雨天；3：雪天。天气默认晴天，不占用 WASD、Shift、R、F3。
- Camera2D 跟随角色，地图边缘停止滚动；天气覆盖当前 640×360 可见区域并随镜头移动；UI 固定在屏幕上。
- nearest 过滤、整数倍缩放、像素对齐镜头；小于 640×360 的窗口会裁切。
- 建筑四边可绕行，地基不可穿越。建筑、树木、道具和角色按脚底 Y 排序，不再使用固定覆盖全屏的旧栏杆层。

## 文件与重建

- `lantern_lane.gd`：新小镇组装、八方向移动及四向角色动画、跟随镜头、碰撞、Y 排序、天气接入及自动测试。
- `Effect/Weather/weather.tscn` / `weather.gd`：可复用纯程序像素天气。API 为 `set_weather("clear"|"rain"|"snow")`、`clear_weather()`、`get_weather()`；详情见同目录 README。
- `generate_town.py`：新原创程序像素绘图和布局生成器。运行 `python Scenes/LanternLane/generate_town.py`，需要 Pillow；游戏本身不依赖 Python。
- `Art/town_ground.png`：新地面与纵横街道，不含建筑屋顶。
- `Art/shop_0.png` 至 `shop_8.png`：九间独立建筑，屋顶大平面、檐口、正面门窗与店招。
- `Art/town_tree.png`、`Art/town_layout.json`：新树木及统一可视对象/碰撞布局数据。
- 复用已有 `courier.png`、`planter.png`、`menu.png`。旧 `generate_art.py`、旧街景图片及 `steam.gd` 保留，但旧背景/栏杆/蒸汽不再加载；不要用旧生成器重建新地图。

## 本轮验证

实际使用本机 Godot 4.7.2 运行。测试与截图位于 `Verification/topdown/`；之前根目录及 `reference_review/` 的记录保留。

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://Scenes/LanternLane/lantern_lane.tscn -- --lane-test
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --path . --resolution 1280x720 --scene res://Scenes/LanternLane/lantern_lane.tscn -- --lane-capture
```

- 自动断言覆盖上下左右与斜向位移、建筑前后左右碰撞、纵横跨屏通路及镜头跟随、镜头边界限制、共用 Y 排序父节点；当前街区验证另检查四种斜向走路和跑步的等速位移。
- 天气效果：雨线、落地水花、飘落雪花均为最近邻程序绘制；不做全屏变暗、音效、雷电、积雪或雾。
- 测试方向注入与真实操作共用 `_physics_process`、速度计算和 `move_and_slide`，不是单纯修改坐标模拟行走；仍不等同于真实键盘端到端测试。
- Forward+/D3D12 和 Compatibility/OpenGL 图形运行均退出 0；各成功保存六张截图。
- 已查看运行截图：十字街口与南侧市场布局不同；屋顶后角色被遮住、店面前正常显示；树冠后遮挡、树前正常显示。
- `runtime.png`、`south_market.png`、`behind_roof.png`、`front_shop.png`、`behind_tree.png`、`front_tree.png` 为游戏 SubViewport 原始截图，不是合成效果图。重复 capture 会更新本轮六张图，不影响旧版记录。

## 局限

这是可探索的俯视街区原型，不是《星露谷物语》完整美术或玩法复刻。建筑仍共用较规则的轮廓，主要通过屋顶颜色与店招区分，街区密度和手绘细节仍可提升。屋顶目前不自动透明，走到背面会暂时完全遮住角色。无店内场景、NPC、交互、农场、剧情或存档。未验证真实键盘持续操作、跨平台和导出包；JSON 布局在导出时需要包含在资源过滤中。
