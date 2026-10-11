# Weather Effect / 天气特效

路径：`Scenes/LanternLane/Effect/Weather/`

- `weather.tscn`：可复用天气场景。
- `weather.gd`：纯程序像素绘制，无额外纹理、音效或全局配置。

## LanternLane 操作

天气默认是晴天（无粒子）。运行场景后使用不与现有控制冲突的快捷键：

- `F6`：晴天，立即停止并清除天气绘制。
- `F7`：雨天，雨线 + 稀疏落地水花。
- `F8`：雪天，不同速度/大小/水平漂移的雪花。

已有 WASD/方向键、Shift、R、F3 均保持不变。

## API

```gdscript
var weather := preload("res://Scenes/LanternLane/Effect/Weather/weather.tscn").instantiate()
viewport.add_child(weather) # 640×360 SubViewport，与 Camera2D 同一视口
weather.configure(camera, player, roof_rects)
weather.set_weather("rain") # "clear", "rain", "snow"
weather.clear_weather()
print(weather.get_weather())
```

天气采用 640×360 原生视口坐标、整数像素矩形绘制，并抵消 Camera2D 的画布变换，地图边缘也覆盖当前可见区域。雨线和雪花绘制在建筑前方；LanternLane 传入建筑完整贴图包围矩形（不是碰撞地基），仅用于排除建筑区域的地面水花，不裁剪前景雨线。雨线与水花保留角色全身小范围避让。水花在雨点落地后出现，世界坐标锚定，寿命 0.16 秒，不随雨线飞行。无全屏调色、音效、积雪、雷电或雾。

## 前景雨线修复复核（2026-10-11）

`output/rain_foreground_20261011/run.py` 使用独立设置和存档，在 Compatibility/OpenGL 与 Forward+/D3D12 下各通过 44 项检查。实际农场与小镇建筑区域的雨线像素、移动相机后的覆盖、角色避让、建筑地面水花排除、室内隐藏及返回室外恢复均通过；自然雨景截图和日志保存在同目录。像素探测期间隐藏 HUD，截图前恢复。旧 `verify_weather.gd` 的数字键和建筑碰撞坐标已过时，本次运行有 6 项失败，因此此处使用当前场景的定向验证。

## 实际运行验证（2026-10-09）

新增 `verify_weather.gd`，实例化真实 LanternLane 而非替代地图。采用有界 Python subprocess 等待 Godot 子进程（超时须终止并等待该子进程）；直接 shell 调用 Windows 图形 Godot 时，本机工具曾过早返回，故此前只有启动信息不算测试通过。

- Godot 4.7.2 headless：16 项天气集成断言 PASS，退出 0。
- Compatibility/OpenGL 与 Forward+/D3D12 窗口运行：各 28 项断言 PASS，退出 0，无脚本错误；各保存 10 张实际 640×360 SubViewport 截图。
- 输入事件注入经过 `Input.parse_input_event` 验证 2→雨、3→雪、1→晴；雨雪 process 实际更新；晴天恢复图与初始晴天逐字节一致。
- 雨雪模式均通过实际 move_and_slide 位移与建筑碰撞；左上、右下边界及南侧市场的天气屏幕变换均正确。
- 原 `--lane-test` 全部 50 项 PASS（含原角色/移动/碰撞/相机/Y-sort 46 项与新增天气 API 4 项），退出 0。
- 已查看两渲染器雨雪截图，包括右下地图边界；旧 topdown 与女巫验证截图未在本次验证覆盖。

截图：`Verification/gl_compatibility/`、`Verification/forward_plus/`。
日志：项目根目录 `output/weather_headless_verified.log`、`weather_compatibility_verified.log`、`weather_forward_verified.log`、`weather_lane_regression.log`。

复测入口（项目根目录；图形测试不要使用 headless）：

```powershell
$godot = 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $godot --headless --path . --quit-after 1500 --script res://Scenes/LanternLane/Effect/Weather/verify_weather.gd
& $godot --windowed --resolution 1280x720 --rendering-method gl_compatibility --rendering-driver opengl3 --path . --quit-after 1500 --script res://Scenes/LanternLane/Effect/Weather/verify_weather.gd -- --weather-render
# Forward+：将上行渲染方法/驱动改成 forward_plus / d3d12。
```

局限：这是固定 640×360、默认相机 zoom=1 的天气组件；复用到其他视口/缩放需适配。地面水花避让建筑时使用保守矩形，未做贴图 alpha 精确遮挡。测试使用引擎输入事件注入，不等同于人工实体键盘端到端操作；未测试导出包或跨平台。
