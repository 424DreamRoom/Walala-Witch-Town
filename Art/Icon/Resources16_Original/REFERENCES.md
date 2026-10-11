# 16×16 资源图标参考与绘画笔记

检索日期：2026-10-11。以下为造型、材质和像素组织参考；本项目成品在原生网格上重新绘制。

## 参考图

| 来源 | 参考图 | 本次观察重点 |
|---|---|---|
| [Kyrise's Free 16×16 RPG Icon Pack](https://kyrise.itch.io/kyrises-free-16x16-rpg-icon-pack) | [作者展示图](https://img.itch.zone/aW1nLzY3NzUzNjEucG5n/original/WxGyvI.png) | 木段、金属锭、金币的轮廓识别与统一描边。作者提供原生图及整数倍版本，标注 CC BY 4.0。 |
| [Beast Pixels — Crafting Materials](https://beast-pixels.itch.io/crafting-materials) | [作者材质合集](https://img.itch.zone/aW1nLzMwMTMwMzEucG5n/original/R0KdPT.png) | 对比原矿、金属块、金属锭的形状与亮面分配。用于材质研究，不当作本项目的尺寸模板；作者页面标注 CC0。 |
| [Kenmi — Cute Fantasy 图标系列](https://kenmi-art.itch.io/) | [Resources 16×16 产品页](https://kenmi-art.itch.io/cute-fantasy-resources-icons-16x16) | 同类资源的视觉重量、暖冷色区分；作者目录列出木材、石头和矿石。 |

## 绘制要点与应用

1. **从原生 16×16 开始。** 使用 1 像素笔刷决定轮廓；只画能够在原尺寸读懂的特征，先减少形状，再补细节。[Saint11：入门](https://saint11.art/pixel_art_articles/article1/)
2. **先组织大色块，再处理细节。** 连续同色色块表达体积；零散单像素容易产生噪声。鱼眼等识别特征可以保留单像素，木纹和矿粒则组成短线或小块。[Saint11：Cluster Sketching](https://saint11.art/pixel_art_articles/article2/)
3. **轮廓阶梯有规律。** 检查曲线和斜边相邻步长，清理突然凹入或凸出的像素。本项目保留一圈透明边距，避免相邻格子的内容粘连。[Saint11：锯齿整理](https://saint11.art/pixel_art_articles/article2/)
4. **统一光源，按形体分面。** 所有图标使用左上亮、右下暗；金属上表面为连续亮面，原石为不规则大切面。避免围着轮廓均匀加一圈暗色的枕头阴影。[Saint11：Basic Shading](https://saint11.art/pixel_art_articles/article4/)
5. **用高光形状区分材质。** 金属高光集中而明亮；木段以切面年轮和两条树皮纹辨认；矿石采用暖色矿粒簇与冷色基岩对比。低分辨率时删掉不必要的反光与纹理。[Saint11：材质与高光](https://saint11.art/pixel_art_articles/article4/)
6. **检查整套一致性。** 本项目将每图不透明颜色限制在 7 种以内，以原尺寸及 3 倍整数缩放同时检查浅色和深色 UI 底。成品不烘焙背景、不生成半透明边缘；预览使用最近邻，游戏通过最近邻纹理过滤显示。

这些是开发美术记录，不作为玩家界面教学文案。
