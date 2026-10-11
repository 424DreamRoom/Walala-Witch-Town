# Framewright Lite / Walala UI

本项目采用 Cabin Circuit 的 **Framewright Lite — Oakhold** 木质、羊皮纸像素 UI。

- 官方来源：<https://cabincircuit.itch.io/framewright-lite>
- 导入日期：2026-10-10；使用用户上传的 `Framewright-Lite.zip`。
- 完整许可见 [LICENSE.txt](LICENSE.txt)：可用于免费或商业游戏，可修改，无需署名；不能作为独立素材或素材包、模板、UI 套件再分发。
- 作者在原始 [README.txt](README.txt) 中披露素材使用了程序化、AI 辅助制作。
- [manifest.json](manifest.json) 保留原包 SHA-256、导入文件列表及来源路径。88 张原生 1x PNG 均保持原样。

## 接入方式

`project.godot` 的全局主题指向 `themes/walala_theme.tres`。`themes/oakhold_1x.tres` 保留官方主题，仅将资源路径改为本项目位置。

项目主题在官方主题基础上使用现有 Fusion Pixel 12px 中文字体，补充 `RichTextLabel` 字体和按住悬停状态。纹理与九宫格边距遵循原包 [NINE-SLICE-MARGINS.txt](NINE-SLICE-MARGINS.txt)。640×360 原生界面继续使用最近邻整数缩放。

`Scenes/Gameplay/ui_skin.gd` 提供纸色面板、深棕文字色和紧凑按钮边距。主菜单、设置、鸣谢、游戏 HUD、餐厅菜单与料理按钮、营业结算、铁匠铺和杂货店柜台均接入此主题；世界中的交互提示继续使用浅色字体。

## 验证

Godot 导入检查通过。以下实际运行检查均为零失败：

| 检查 | 通过项 | 范围 |
| --- | ---: | --- |
| `menu` | 41 | 鼠标、键盘、设置、720p/1080p 整数缩放及进入小镇 |
| `loop` | 121 | 现有两天经营流程及场景交互回归 |
| `preview` | 67 | 原包纹理、中文字体、按钮文字边界及实际渲染截图 |

运行 `python Art/UI/FramewrightLite/tools/run_checks.py menu`，将末尾参数替换为 `loop` 或 `preview` 可运行其余检查。可通过 `GODOT_BIN` 指定 Godot 可执行文件。检查使用 Dummy 音频驱动；截图保存在 `Verification/`，其中 `_2x.png` 为最近邻放大预览。预览脚本直接设置场景状态用于检查布局，完整交互由前两套检查覆盖。

没有选入原包的 2x/4x 重复纹理和其他引擎示例。上传的压缩包保留在项目根目录。
