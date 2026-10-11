# 潮汐码头

白天沿主街去小镇东南侧，沿木栈道向右走到地图边缘 (1272,652) 自动进入。入口位置读取 `town_layout.json` 的 `gates.dock` 配置。码头西侧 (8,238) 向左走回镇；两端都是42像素宽的木栈道，延伸到图像之外，进入码头落在路中央 (42,238)。**R** 回到同一出生点。进出场景不需要 E。

独立地图为 640×360 原生像素，包含岸边小屋、木栈桥、系船桩、摇晃的小船和动态水纹。栈桥与岸边的水域有实体碰撞，人物与道具共用脚底 Y 排序；雨雪沿用小镇天气系统。

栈桥北、东、南三块鱼牌各对应一个钓点。走近鱼牌后按 **E** 抛竿，等待 2–4 秒；出现感叹号和“咬钩！”时，在 1.5 秒内按 **E** 收竿。界面只显示鱼群数量和钓鱼状态，不显示键位或操作教学。过早收竿或错过咬钩不会消耗鱼数。移动、Esc、R、离开场景或白天结束都会取消未完成的钓鱼。

每个钓点每天最多获得 3 条鱼，三个钓点合计 9 条，与野外池塘独立计算。鱼获进入现有资源背包，不占 12 格食材容量，跨区域、跨天保留；消耗的钓点鱼数次日刷新。沿用当前游戏规则，白天结束自动进入餐厅，码头夜间关闭。鱼获遵循游戏现有的资源和存档规则。

- `dock.tscn` / `dock.gd`：区域组装、出口、钓点提示、水面与小船动画。
- `Art/Environment/Hearthwood/tools/build_dock.py`：基于现有 Hearthwood 色板和木纹函数的可重建像素素材，只生成码头新增文件。
- `Art/Environment/Hearthwood/dock_layout.json`：出口、出生点、水域碰撞、装饰、三个钓点的站位及浮漂坐标。
- `Scenes/Gameplay/harvest_actions.gd`：与野外共用抛竿、等待、咬钩、收竿和取消状态机。

重建素材需要 Pillow：

```powershell
python Art/Environment/Hearthwood/tools/build_dock.py
```

运行验证（Godot 不在已知安装路径时，可设置 `GODOT_BIN`）：

```powershell
python Scenes/Gameplay/run_verification.py dock
python Scenes/Gameplay/run_verification.py dock_capture
```

验证脚本通过真实 `move_and_slide` 行走与 `Input.parse_input_event` 按键，覆盖入口往返、桥边/栈桥边水域碰撞、三个方向钓鱼、重复交互、失败/取消不发奖励、每日鱼数与跨区域保留、昼夜计时和次日刷新。边界测试用定点站位隔离复位和昼夜转换。截图模式保存 Godot 实际 SubViewport 和窗口画面至本目录 `Verification/`，日志保存至项目 `output/loop_dock*.log`。

导出时需将 `dock_layout.json` 与现有地图布局 JSON 一起纳入资源过滤。
