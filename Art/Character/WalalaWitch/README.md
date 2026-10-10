# Walala 原创小女巫主角

此目录保留旧版16×24人物与历史验证记录。当前游戏已接入 `Art/Character/Storybook/` 的原生32×48参考画风重绘，详情见该目录README。

每帧原生 16×24 像素，紫色弯尖帽、银白短发、深色紫边斗篷。参考图由 media-generation 实际生成；最终资源由整数像素笔划原创绘制，生成脚本不读取参考图，不缩小大图。

旧版曾以最近邻2倍显示为32×48像素；以下为当时的接入和验证记录。

2026-10-10 显示尺寸调整验证：51 项动画/移动/碰撞检查、88 项场景与窗口检查通过。实机截图在 `Art/Environment/Hearthwood/Verification/`，`home_size_720_window.png` 与 `home_1920_window.png` 展示当前房间比例；同时检查了采集提示、客人订单与手持餐盘。

## 资源

- `walala_witch.aseprite`：20 帧 RGBA，5 个可编辑图层（Boots / Cloak / Hair and face / Purple pointed hat / Details）。8 个 forward-loop tags：`idle_down/up/right/left`、`walk_down/up/right/left`。
- `walala_witch.png`：透明 80×96 精灵表，5 列×4 行，每格 16×24；行顺序 down/up/right/left。每行第 0 列为 1 帧待机，第 1–4 列为 4 个互不相同的行走帧。
- `animations.json`：原生帧、方向、tags 和锚点说明。原生脚底锚点 (8,24)，当前 2 倍显示的 Sprite2D 中心偏移为 (0,-24)。待机单帧，行走 9fps、跑步 13fps，移动速度保留 90/140。
- `preview_nearest_12x.png`：仅用于审阅的最近邻放大图，格子底不在透明 PNG 中。
- `validation_report.json`：独立二进制解析结果。
- `Verification/`：本轮独立日志、26 张 Godot 实际 SubViewport 截图和实际渲染帧的最近邻裁切拼图；旧小镇验证文件未覆盖。

造型参考本地文件：`res://output/media/xai-tmp-imgen-debf5f5a-9c3d-929a-8e48-c7d950180427-34a29249.jpeg`
生成工具下载链接：https://zxty.tuyoo.com/aichat/xai-imgen/xai-tmp-imgen-debf5f5a-9c3d-929a-8e48-c7d950180427-34a29249.jpeg

## 接入与启动

仅修改 `res://Scenes/LanternLane/lantern_lane.gd` 的玩家纹理、5×4 切帧、脚底偏移、动画逻辑和针对角色的验证入口。保留旧 courier PNG、用户现有 project.godot、碰撞 10×6/偏移 (0,-3)、相机、Y-sort、地图和控制键；未编辑资源图标 agent 文件。Godot 导入会自动生成 .import 和 .godot 缓存。

Godot 打开 `res://Scenes/LanternLane/lantern_lane.tscn`，F6 运行；用户原有主场景设置仍在，因此也可 F5。WASD/方向键移动，Shift 跑步，R 复位，F3 碰撞显示。

项目根目录 PowerShell：

```powershell
$godot = 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $godot --path . --resolution 1280x720 --scene res://Scenes/LanternLane/lantern_lane.tscn
& $godot --headless --path . --scene res://Scenes/LanternLane/lantern_lane.tscn -- --lane-test
& $godot --path . --resolution 1280x720 --scene res://Scenes/LanternLane/lantern_lane.tscn -- --witch-capture
python Art/Character/WalalaWitch/tools/validate_witch.py
```

`tools/build_witch.py` 默认拒绝覆盖输出；`--replace-generated` 仅用于明确重新生成这些资源，会覆盖本目录四个生成文件，编辑过 Aseprite 后不要使用该参数。

## 验证与局限

- 独立解析 Aseprite 文件头、20 帧、100 个压缩 cel、5 图层、8 tags、帧时长；逐帧 RGBA 合成与精灵表逐字节一致。Alpha 仅 0/255，每方向四个不同的行走帧，所有脚底保持接地。
- Godot 4.7.2 导入成功；46 项测试 PASS（帧选择、跑步帧率/速度、停止保留朝向、四方向移动、建筑碰撞、镜头与 Y-sort）。图形 Forward+/D3D12 与 Compatibility/OpenGL 均退出 0，无脚本错误。
- 已查看资源预览、运行截图及全部实际渲染帧拼图：下向有脸与银白两侧短发，上向为银白后脑，左右为相反侧脸；帽尖与斗篷随步伐变化。屋后和树后角色完全被挡住，店前和树前正常显示；保持现有遮挡规则，未新增屋顶透明功能。
- Aseprite 应用/CLI 不在 PATH，本轮没有安装或搜索无关目录；已完成独立源文件校验，但未完成 Aseprite 应用内打开验证。
- 运行截图直接选择帧用于静态视觉检查；实际位移、跑步及方向测试走共同 physics 控制路径，但未做真实键盘端到端操作、导出包或跨平台测试。
