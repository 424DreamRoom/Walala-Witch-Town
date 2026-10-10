# Lantern Town / 灯火街区小镇

## 当前环境美术

当前场景使用 `Art/Environment/Hearthwood/` 中的原创逐像素 PNG，参考新增室内截屏的木纹、低饱和家具、织物和暖光特征。九间建筑、街道、树木、野外、餐厅已换用同一材质语言；绿屋顶第一间住宅是小女巫的家，可从门前“家 E”路标进入。完整素材、绘制源与说明见该目录 README。旧版图片与生成器保留；重建当前美术使用 `Art/Environment/Hearthwood/tools/build_art.py`。

室外新增57处花坛、路灯、长椅、信箱、水井、池塘与庭院物件，入口替换为图案木路牌；野外树木采用独立脚底Y排序与实体碰撞。室外单独重建使用 `Art/Environment/Hearthwood/tools/build_outdoors.py`，专用实机验证入口为 `Scenes/LanternLane/verify_outdoors.gd`。

以下为先前版本的布局与验证记录，道路及建筑碰撞仍沿用该布局。

LanternLane 现已重布局为正交 2D 斜俯视小镇：不是等距投影，也不是旧侧视街景的放大。1280×960 世界、640×360 原生视口，九间可见屋顶和正面的独立商铺，两条东西主街、两条南北街与外围环路。保留原创黄绿棋盘街区主题，不包含农场系统。

本轮没有修改 project.godot。开始时该文件已有用户设置的 LanternLane 主场景，原样保留；没有修改全局 InputMap。原验证截图和日志未覆盖。

## 启动

Godot 编辑器打开 `res://Scenes/LanternLane/lantern_lane.tscn`，F6 运行当前场景。场景在运行时组装，编辑器画布为空不代表游戏为空。

在项目根目录执行：

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --path . --resolution 1280x720 --scene res://Scenes/LanternLane/lantern_lane.tscn
```

- WASD / 方向键：严格四方向移动；同时按两轴时纵向优先。
- Shift：跑步。R：返回北侧十字路口。
- F3：开关建筑、道具和地图边界碰撞显示。
- 1：晴天；2：雨天；3：雪天。天气默认晴天，不占用 WASD、Shift、R、F3。
- Camera2D 跟随角色，地图边缘停止滚动；天气覆盖当前 640×360 可见区域并随镜头移动；UI 固定在屏幕上。
- nearest 过滤、整数倍缩放、像素对齐镜头；小于 640×360 的窗口会裁切。
- 建筑四边可绕行，地基不可穿越。建筑、树木、道具和角色按脚底 Y 排序，不再使用固定覆盖全屏的旧栏杆层。

## 文件与重建

- `lantern_lane.gd`：新小镇组装、四方向控制、跟随镜头、碰撞、Y 排序、天气接入及自动测试。
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

- 原有自动断言覆盖上下左右位移、双轴输入四方向化、建筑前后左右碰撞、纵横跨屏通路及镜头跟随、镜头边界限制、共用 Y 排序父节点；天气新增后应保持这些路径不变。
- 天气效果：雨线、落地水花、飘落雪花均为最近邻程序绘制；不做全屏变暗、音效、雷电、积雪或雾。
- 测试方向注入与真实操作共用 `_physics_process`、速度计算和 `move_and_slide`，不是单纯修改坐标模拟行走；仍不等同于真实键盘端到端测试。
- Forward+/D3D12 和 Compatibility/OpenGL 图形运行均退出 0；各成功保存六张截图。
- 已查看运行截图：十字街口与南侧市场布局不同；屋顶后角色被遮住、店面前正常显示；树冠后遮挡、树前正常显示。
- `runtime.png`、`south_market.png`、`behind_roof.png`、`front_shop.png`、`behind_tree.png`、`front_tree.png` 为游戏 SubViewport 原始截图，不是合成效果图。重复 capture 会更新本轮六张图，不影响旧版记录。

## 局限

这是可探索的俯视街区原型，不是《星露谷物语》完整美术或玩法复刻。建筑仍共用较规则的轮廓，主要通过屋顶颜色与店招区分，街区密度和手绘细节仍可提升。屋顶目前不自动透明，走到背面会暂时完全遮住角色。无店内场景、NPC、交互、农场、剧情或存档。未验证真实键盘持续操作、跨平台和导出包；JSON 布局在导出时需要包含在资源过滤中。
