# 哗啦啦魔女镇主菜单

F5 运行项目先进入 `startup_notice.tscn` 的存档提示画面，再进入主菜单。F6 可以单独运行 `main_menu.tscn`，跳过启动提示。

标题位于上方正中；开始游戏、设置、鸣谢、退出游戏四个按钮居中竖排，单个按钮为原生 144×24 像素，间距 8 像素，文字保留 12px。采用原生 640×360 像素画布、现有小镇屋舍与魔女素材、黄昏天空、星光和萤火。720p、1080p 分别以 2 倍、3 倍显示，其他比例居中留边。

标题与按钮在 0.8 秒内错落淡入；输入可立即完成入场。选中按钮渐亮，两侧星芒轻轻浮动，按下时下沉 1 像素。弹窗淡入并上浮 6 像素。标题轻微呼吸，云朵缓慢漂移，树木花草与路灯复用小镇的环境动画；魔女每 18 秒散步一小段再返回。位移均取整到原生像素，菜单不启用游戏循环。

- 鼠标点击或 W / S、Tab 选择，Enter 确认。
- 开始游戏：打开三行两列的 6 栏位存档选择；选择空栏位开始新游戏，选择已有栏位读取进度，再淡出进入游戏。
- 设置：全局音量、音乐、角色音效、环境音效、UI音效五条滑杆，以及画面、游戏、按键选项；自动保存至 `user://preferences.cfg`，进入游戏后各分类音量继续生效。
- 鸣谢：仅展示引擎、界面、字体及音频素材的名称与作者署名；Tab 可聚焦正文，W / S 滚动。
- 退出游戏：二次确认，先停止菜单声音再退出。
- Esc 关闭当前弹窗并恢复原按钮焦点。

菜单只加载自己的背景音乐和点击声。游戏里的音频管理器读取相同设置；菜单不运行经营循环。原 `--lane-test`、`--lane-capture`、`--witch-capture`、`--no-loop` 参数仍可直接进入原场景。

游戏内的自动保存、手动保存和返回主菜单操作见 `Scenes/Save/README.md`。

## 验证

在项目根目录运行：

```powershell
python Scenes/MainMenu/run_verification.py import
python Scenes/MainMenu/run_verification.py headless
python Scenes/MainMenu/run_verification.py capture
python Scenes/MainMenu/run_verification.py motion
python Scenes/MainMenu/run_verification.py exit
```

可用 `--godot "引擎绝对路径"` 或环境变量 `GODOT_BIN` 指定引擎。`headless`、`capture` 添加 `--menu-only` 可单独验证菜单，不加载正在开发的游戏模块。截图和日志保存在 `Verification/`；测试使用独立配置文件，不覆盖玩家设置。

`motion` 以每秒 12 帧录制 9 秒实际菜单画面，包含入场、悬停、按下、设置弹窗与魔女散步，原始帧保存在 `output/menu_motion/frames/`。

Godot 4.7.2 本机验证：动效更新后菜单独立无头检查 29 项、真实窗口检查 57 项通过；退出确认检查通过。覆盖居中竖排、键盘与鼠标、弹窗焦点、音量保存和 720p/1080p 像素缩放。此次动效验证未加载游戏模块；未验证导出包和其他操作系统。

## 启动存档说明

游戏启动先显示独立的深紫色提示画面，演示与游戏右下角相同的魔女帽保存动画。该演示不读取或写入存档，也不显示实际“保存中”状态。

文案为“游戏支持自动保存”“当屏幕右下角出现该图标时，表示正在保存进度”“保存中断可能导致进度丢失。”支持简体中文、繁体中文、英语和日语，只描述保存状态与中断后果。说明参考 [Capcom 官方手册的自动保存提示](https://game.capcom.com/manual/resistance/en/ps4/page/1/4)，结合本项目的魔女帽图标重新编写。

启动页沿用 Fusion Pixel 12 字体：游戏名、正文、按钮与错误消息使用原生 12px，标题使用 24px，避免 10px 缩小或 18px 非整数倍缩放导致笔画变形。正文区域为 480px 宽，以容纳各语言译文；画布继续使用最近邻整数倍放大。

画面淡入后保留阅读时间，约 6.5 秒后自动淡出进入主菜单；1.2 秒后也可以使用“继续”按钮提前进入。主菜单不在提示画面后台运行。游戏中返回主菜单时直接进入原主菜单场景，不重复显示启动提示。命令行的原有直接进入游戏的验证参数继续跳过提示。

验证命令：

```powershell
python Scenes/MainMenu/run_verification.py startup
python Scenes/MainMenu/run_verification.py startup_capture
```

使用进程专属的测试设置和存档路径；截图保存在 `output/startup_notice/`。覆盖启动顺序、最短阅读时间、手动与自动继续、四种语言的文字边界、720p/1080p 像素缩放，以及提示演示不创建存档。
