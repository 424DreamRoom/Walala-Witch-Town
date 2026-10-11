# 木箱像素素材

来源：[karsiori — FREE Pixel Art Chest Pack - Animated](https://karsiori.itch.io/pixel-art-chest-pack-animated)，CC0-1.0。选用 Wooden Chest 1：48×36 原生 RGBA，暖木色、深色箍带、斜俯视，与 Hearthwood 木制家具相配。

所有 PNG 直接复制作者文件，未缩放、重绘、调色或裁切；五帧画布和透明度完整保留。`Source/` 保留原压缩包并以 `.gdignore` 排除导入。`manifest.json` 记录原文件名、尺寸与 SHA-256。

`closed.png` 是未上锁闭合帧；`opening_1.png`、`opening_2.png`、`open.png` 是开盖帧。`locked.png` 仅保留原包资源，当前玩法没有锁箱机制。

`Scenes/Building/furniture_catalog.gd` 为房间摆放、家具预览和地图统一提供闭合贴图；`Scenes/Storage/chest_sprite.gd` 在储物界面打开/关闭时播放 10 fps 非循环开合动画，并在世界暂停期间保持更新。每个实例只响应对应箱子的界面；碰撞仍为 40×20，配方、存档格式与储物容量沿用现有逻辑。

`Art/Environment/Hearthwood/home_chest.svg` 保留为旧占位资源，运行时已使用本目录 PNG。`MyArt/` 未修改。

2026-10-11，Godot 4.7.2 验证：23项宝箱实机检查、63项储物回归通过，无脚本错误。检查包括暂停期间开合、两个箱子独立显示、碰撞、地图贴图、物品存取、存档和场景重入。储物回归采用扩建房间的隔离测试数据，以容纳旧测试中的固定坐标；正式玩法与存档未改。截图、验证脚本、日志及验收清单位于 `output/chest_art/`，测试设置与存档也在隔离目录。6张PNG与原压缩包逐字节一致，`MyArt/` 全部3份原稿的SHA-256保持一致。
