# Ark Pixel Font 12px（项目内置）

本项目保留 **Ark Pixel Font 12px proportional / zh-Hans** 作为字体资源。当前游戏 UI 使用补字更完整的缝合像素字体，配置与说明见 `../FusionPixel/README.md`。

- 作者：TakWolf（狼人小林）
- 字体：Ark Pixel Font 12px proportional，简体中文变体 `zh_hans`
- 版本：2026.09.25
- 字体文件：`ArkPixel12Proportional.ttf`
- 授权：SIL Open Font License 1.1（完整原文见同目录 `LICENSE-OFL.txt`）
- 许可证要求：字体可随软件嵌入、再分发和商业使用，但不可单独出售；不得移除许可与版权声明；衍生字体不得继续使用保留名称 “Ark Pixel”。本项目未修改字体文件，仅随游戏嵌入使用。
- 版权：Copyright (c) 2021, TakWolf (https://takwolf.com)

## 官方来源

- 官方仓库：https://github.com/TakWolf/ark-pixel-font
- 官方网站：https://ark-pixel-font.takwolf.com/
- 本次下载的官方 Release：https://github.com/TakWolf/ark-pixel-font/releases/tag/2026.09.25
- 本次字体包直链：https://github.com/TakWolf/ark-pixel-font/releases/download/2026.09.25/ark-pixel-font-12px-proportional-ttf-v2026.09.25.zip
- 官方字体许可证原文：https://raw.githubusercontent.com/TakWolf/ark-pixel-font/master/LICENSE-OFL

## 导入与应用

- 已从官方发布包提取 `ark-pixel-12px-proportional-zh_hans.ttf`，保留原始字体内容，仅重命名项目文件。不要用 `ja` 版本替代简体中文版本。
- 发布包 SHA-256：`0baa839fee52787dcea47363641102eab98cd1e12843b072ea91ba6c7de4cf4b`。
- 本地字体 SHA-256：`e10ee2fc734504ef679bd90d0481fc48ae272426f85eae16859828cc23015138`。
- 当前全局主题是 `../FusionPixel/pixel_theme.tres`，默认字号 12，覆盖普通控件、悬浮提示及新增 UI。
- `Scenes/Gameplay/ui_font.gd` 共享缝合像素字体；小镇提示、中文 HUD、菜单、场景文字、音量设置和鸣谢均使用内置字体。
- 导入关闭抗锯齿、MSDF、hinting、subpixel positioning 和系统字体回退，oversampling 为 1；像素画布以整数倍最近邻放大。字体字号优先使用 12 的整数倍。
- `verify_font.gd` 检查中文字符覆盖、运行中控件字体、按钮文本边界，并可保存真实引擎截图。

## 字体鸣谢

本字体由 TakWolf 制作，采用 SIL Open Font License 1.1 发布。感谢作者及贡献者提供适合像素游戏 UI 的泛中日韩点阵字体。
