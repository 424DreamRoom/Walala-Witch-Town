# 按键映射

主菜单与局内暂停菜单共用「设置 → 按键」。滚动列表包含上下左右移动、跑步 / 步行、互动、背包、手记、指南、暂停 / 返回、对话继续、对话回看和区域地图，共 13 项。每项可设置一个主按键和一个备用按键。点击键位后按新键即可生效；备用键可在捕获窗口中清除，Esc 或「取消」保留原绑定。

重复键先显示冲突，可交换两项绑定或重新选择。交换作为一次配置保存提交；若从空备用栏交换会使另一项完全没有按键，则保留原绑定并提示。主键与同一项备用键重复时交换两者。界面使用项目木框与像素主题，支持四种语言。

## 输入与保存

`input_bindings.gd` 是 `InputBindings` Autoload，通过 Godot `InputMap` 管理键盘物理键。默认移动主键为 WASD，备用键为方向键；默认互动 F、背包 B、手记 J、指南 H、跑步 Shift、暂停 Esc、对话继续 Space、回看 L、地图 M。互动键也可继续对话。

菜单方向跟随四个移动主键。Enter 确认、Tab 焦点导航和 Esc 取消 / 返回保留为界面入口；暂停键可以另设，Esc 始终可返回。已有手柄菜单事件继续保留。当前编辑器配置键盘单键及修饰键，不配置按键组合或手柄按钮。

## PlayStation、Xbox 与 Switch 手柄

`controller_input.gd` 是 `ControllerInput` Autoload，使用 Godot 4.7 的 SDL 标准化手柄事件，覆盖 Xbox、DualShock / DualSense、Switch Pro 和由系统合并识别的 Joy-Con。此功能为当前桌面游戏增加手柄输入，不包含主机平台移植。设备接入及拔出会重建手柄映射，不改动键盘自定义绑定。断开当前设备或窗口失焦时释放移动、导航和虚拟鼠标状态，防止持续移动或拖拽；后台窗口忽略手柄输入。

主菜单与暂停设置新增「手柄」页，包含自动 / Xbox / PlayStation / Switch 布局、摇杆死区以及只读键位表。自动模式按设备名称和厂商 ID 识别；Steam Input 或驱动将设备伪装成 XInput 时可手动指定布局。配置写入 `preferences.cfg` 的 `[controller]` 段，独立于键盘 `[input]` 和游戏存档。「恢复本页」只重置手柄设置。

| 操作 | Xbox | PlayStation | Switch |
| --- | --- | --- | --- |
| 移动 / 菜单导航 | 左摇杆、方向键 | 左摇杆、方向键 | 左摇杆、方向键 |
| 互动 / 对话 / 界面确认 | A | × | A |
| 暂停 / 返回 | B、Menu | ○、Options | B、+ |
| 背包 | X | □ | Y |
| 对话回看 / 拆分物品 | Y | △ | X |
| 手记 / 前一焦点 | LB | L1 | L |
| 指南 / 后一焦点 / 物品快速转移 | RB | R1 | R |
| 地图 | View | Share / Create | − |
| 跑步 / 步行 | LS | L3 | LS |
| 虚拟光标 | 右摇杆 | 右摇杆 | 右摇杆 |
| 鼠标主操作 | RT | R2 | ZR |
| 鼠标次操作 | LT | L2 | ZL |

Switch 使用物理右侧 A 确认、下侧 B 返回；Godot 的标准按钮编号按物理位置转换，不能直接把 Godot `JOY_BUTTON_A` 当作 Nintendo 的 A。

移动保留摇杆力度并限制斜向速度；默认圆形死区 24%，可设为 10–50%。菜单使用独立 55% 导航阈值，长按 0.38 秒后每 0.1 秒重复。建造模式方向输入每次移动一格。右摇杆与扳机驱动现有鼠标交互，可用于地图、餐厅菜单、滑块和家具摆放。背包确认、拆分和快速转移使用当前焦点；手持物品图像随焦点或虚拟光标移动。

所有键位文字仅出现在设置中的实际键位表。HUD、按钮后缀、对话和任务不增加操作教学或提示。

实现依据：[Godot 手柄与摇杆文档](https://docs.godotengine.org/en/4.7/tutorials/inputs/controllers_gamepads_joysticks.html)。

```powershell
python Scenes/Input/run_controller_verification.py headless
python Scenes/Input/run_controller_verification.py capture
python Scenes/Input/run_controller_verification.py restart
python Scenes/Input/run_controller_verification.py regression
```

手柄验证在 SceneTree 初始化阶段设置独立配置及存档路径，早于 Autoload 读取设置，日志及截图写入 `output/controller/`。覆盖三个布局的菜单、世界互动、模态界面、摇杆力度与死区、导航重复、物品交易、建造、开场、虚拟鼠标、断连释放、键鼠切换、配置重启和键盘回归。注入事件验证不能替代 USB / 蓝牙实体设备测试；还需分别检查 DualShock、DualSense、Xbox、Switch Pro 及成对 Joy-Con 的驱动映射。

绑定即时写入 `user://preferences.cfg` 的 `[input]` 段，跨场景和重启载入，独立于六个进度存档。恢复按键页只重置键位，不修改音量、语言或游戏进度。非法或重复的配置恢复安全默认值。保存失败保留原映射。

旧配置缺少地图键时自动补充 M；若 M 已绑定其他操作，则选择未使用的 F4–F35 键，保留原有自定义键位。实际键位在按键设置中查看。

捕获期间阻止底层快捷键、菜单导航及世界操作；用于改键的按下和松开事件均被消耗，避免新绑定立即触发。失去窗口焦点或关闭设置取消捕获。被绑定的 R、数字键和 F3 不再触发同键调试快捷键。

## 文案与验证

玩家界面不显示操作提示，主键和备用键只在按键设置中查看。`InputBindings.prompt(source)` 与 `track_prompt(control, source)` 暂时保留兼容接口，不作为添加操作教学文案的入口。翻译生成器检查词库和运行时中文字符串中的按键、鼠标提示，规范见根目录 `AGENTS.md`。

```powershell
python Scenes/Input/run_verification.py headless
python Scenes/Input/run_verification.py capture
python Scenes/Input/run_verification.py restart
```

验证使用独立设置及存档路径，覆盖真实鼠标捕获、键盘确认交换、取消、清除、保留键、焦点滚动、恢复默认、四语言截图、实际斜走与跑步、互动与各模态快捷键、暂停期间状态冻结、存档独立及两个新进程间的持久化。截图和日志写入 `Verification/`。
