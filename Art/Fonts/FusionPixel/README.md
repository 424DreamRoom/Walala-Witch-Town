# 缝合像素字体 / Fusion Pixel Font

当前游戏 UI 使用 **Fusion Pixel 12px proportional / zh-Hans**，适合 640×360 像素画布的简体中文、英文、数字与标点混排。该字体以方舟像素字体为基础并补充缺失字形，是作者推荐的补字方案。

- 作者：TakWolf（狼人小林）。
- 版本：2026.09.25。
- 官方仓库：https://github.com/TakWolf/fusion-pixel-font
- 官方发布：https://github.com/TakWolf/fusion-pixel-font/releases/tag/2026.09.25
- 下载包：https://github.com/TakWolf/fusion-pixel-font/releases/download/2026.09.25/fusion-pixel-font-12px-proportional-ttf-v2026.09.25.zip
- 原始文件：`fusion-pixel-12px-proportional-zh_hans.ttf`，项目内重命名为 `FusionPixel12Proportional.ttf`，未修改字体内容。
- 发布包 SHA-256：`47585b9c4b6d8d57380e9dec75bc7e8043fdbfa77d1843c3aaa19a1e7bd15d50`。
- 本地字体 SHA-256：`b2ee68647dc257fa697e4d0c78f9b59461bc504a023b9a3b5ad66f358bbb1613`。

## 授权

字体采用 SIL Open Font License 1.1，完整版权与许可证见同目录 `LICENSE-OFL.txt`，官方包附带的方舟字体、Cubic 11 和 Galmuri 上游许可证保存在 `LICENSES/`。可随游戏嵌入、再分发及商用；不得将字体单独出售，发布时保留版权和许可证。字体修改和衍生版本须遵守 OFL 的命名与再分发条款。

## Godot 应用

`pixel_theme.tres` 已设为项目全局主题，默认字号 12，并为 RichTextLabel 的各文本样式提供同一像素字体。`Scenes/Gameplay/ui_font.gd` 让小镇提示、HUD、菜单、场景文字、声音面板和鸣谢共用该资源；新控件和悬浮提示继承全局主题。

导入关闭抗锯齿、MSDF、hinting、subpixel positioning、系统字体回退，oversampling 为 1。画布以最近邻整数倍放大，字号优先使用 12 的整数倍。

验证入口：`Art/Fonts/ArkPixel/run_checks.py font` 检查当前运行字体、中文覆盖和文本边界；`capture` 保存 1280×720 与 1920×1080 真实引擎截图至 `Art/Fonts/FusionPixel/Verification/`，运行日志保存在 `Art/Fonts/ArkPixel/Verification/`。

Godot 4.7.2 本机验证：无头字体检查 154 项通过，窗口渲染检查 168 项通过（含 14 项真实截图保存）；当前游戏中文字符无缺字，普通控件、RichTextLabel 和悬浮提示均使用内置字体。未验证导出包和其他操作系统。
