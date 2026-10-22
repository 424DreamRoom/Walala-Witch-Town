# 小女巫可爱版（原生 32×32）

2026-10-22：这是已经接入游戏的主角优化版。直接修改既有 Aseprite Lua 像素绘图源，由本机 Aseprite 保存分层源文件；未使用图像生成工具。参考项目内《东方夜雀食堂》《多洛可小镇》的截图，保留紫帽、银白短发、月牙帽饰与小挎包，调整为更大的圆脸、2×3 像素眼睛、柔和腮红、上提帽檐和玫瑰色领口点缀。分析记录见 `STYLE.md`。

- 画布：32×32，脚底锚点 `(16,32)`，二值透明度，最近邻显示。
- 动画：四方向 `idle / walk / run / cast / fish-*`，共 152 帧、28 标签、9 图层。
- 方向顺序：`down / up / right / left`；导出与当前主角保持 8 列 × 19 行精灵表。
- 可编辑源：`walala-witch.aseprite`；绘制脚本：`tools/draw_witch.lua`。
- 23 个不透明颜色，Alpha 仅 0/255，未进行缩小、抗锯齿或调色处理原稿。
- `before-after.png`：新旧对照、四方向与现有 NPC 比例；`animations-preview.gif`：动画预览。
- `loop-review.png`：行走与奔跑的各方向循环；每行最后一格重放首帧以核对衔接。
- 只导出并保留 Aseprite 中的手动编辑：`python Art/Character/Storybook/WalalaWitchCuteAseprite32/tools/build.py`。
- 显式重绘本版：上述命令添加 `--redraw`。可用 `ASEPRITE_BIN` 指定程序。
- 隔离验证：`python Art/Character/Storybook/WalalaWitchCuteAseprite32/tools/verify.py lane` 与 `render`。

共享入口仍为 `../WalalaWitchAseprite32/witch_animation.gd`，其 `SHEET` 和 `MANIFEST` 指向本版；Godot Aseprite 源加载器的 8×19 排列登记在 `Art/Source/sheets.json`。主场景、开场、菜单、采集与钓鱼共用此入口，剧情头像同步引用同一个 `SHEET`。原版 `.aseprite`、PNG 和清单保留。

生成器只写本版目录与 `output/witch-cute-aseprite32/`，仅为 SHA256 校验读取 `MyArt/`；导出前后原稿哈希一致。测试使用独立 `profile/`，不读写正式存档。
