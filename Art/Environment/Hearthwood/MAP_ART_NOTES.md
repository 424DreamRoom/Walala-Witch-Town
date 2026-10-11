# 地图场景美术学习与落地记录

2026-10-11。适用于 1600×1536 小镇 revision 4，景观层 landscape revision 1。

## 教学与经验来源

采用作者教程和开发者分享；以下是本项目的归纳与应用，没有复制教程图片或下载素材。

| 来源 | 适合学习的内容 | 本项目的应用 |
| --- | --- | --- |
| [SLYNYRD：Pixelblog 20 — Top Down Tiles](https://www.slynyrd.com/blog/2019/8/27/pixelblog-20-top-down-tiles) | 草地纹理、平整留白和植被密度的搭配，避免重复块过于明显 | 降低全图均匀散点，把较密草纹放在树丛和花园周边，让道路、角色和建筑更容易辨认 |
| [SLYNYRD：Pixelblog 43 — Top Down Tiles Part 2](https://www.slynyrd.com/blog/2023/3/26/pixelblog-43-top-down-tiles-part-2) | 地表分层、四边衔接、克制的投影与纹理对比 | 庭院按建筑脚印改变轮廓，以离散像素边缘过渡；减弱石路砖缝对比；修复农场入口砖缝露草 |
| [GDC 2018 Level Design Workshop：开发者圆桌](https://www.gamedeveloper.com/design/gdc-2018-level-design-workshop-an-expert-roundtable-q-a) | 用地标、节点、街区、边界和路径建立辨识度；俯视地图需要可读的地面路线 | 月泉喷泉周围增设铺地圆环；使用树丛、花草和河边芦苇形成局部特色；清出道路中央 |
| [Lisa Brown：将 3D 地编经验应用于 Hyper Light Drifter（GDC 原始讲义）](https://media.gdcvault.com/gdc2017/Presentations/Brown_Lisa_Applying_3D_Level.pdf) | 以角色通行尺度约束空间设计，再验证实际移动 | 按本作 10×6 脚底碰撞检查路面；用真实物理移动验证建筑、街区与跨场景入口。战斗节奏部分没有直接套用到本作 |

学习顺序：先看 Pixelblog 20 的草地与纹理平衡，再看 43 的地表连接；随后读圆桌中的地标和路径讨论，最后用尺度约束思路检查布局。评判时同时查看整镇和 640×360 实际镜头。

## 本轮地图优化

保留 16 栋建筑、30 条道路、9 片街区、出生点、7 个功能入口和河岸碰撞坐标。

- 草地均匀底纹从 29,000 次散点改成 6,500 次低对比短纹，额外草纹集中在安排好的景观区域；空地有疏密变化。
- 土坪按每栋建筑的地基宽度和深度绘制，使用不同折角和窄像素边缘；庭院多边形写入 `town_layout.json`，脚步材质读取同一数据。
- 复用现有树木、灌木、香草和花坛原图，新增 23 个景物，分成 9 组。新增景物的完整外接矩形避开路面、建筑外观和功能道具，树干保持实体碰撞和脚底 Y 排序。
- 月泉喷泉周围增加低对比铺地圆环；河岸增加小组芦苇，桥面区域留空。
- 将 8 处占到道路中央的木箱、栅栏、长椅和路灯移到路边。
- 农场入口铺石路补齐底色，砖缝不再露草；农场资源 ID、布局 JSON 和可耕地保持一致。

`MyArt/` 的 3 个 Aseprite 文件只读，前后 SHA-256 完全一致。100 个原稿及非目标环境素材哈希通过；本轮仅重建小镇和农场的地面及总览图，未重绘、缩放或调色现有建筑、人物和道具原图。已有未提交工作保留，本轮目标文件的编辑前副本位于 `output/map_art_pass/before/`。

## 源码与重建

`tools/build_town_layout.py` 仍是小镇布局入口，`tools/build_town_landscape.py` 负责草地、庭院、景物分组和地面细节。所有输出均在 `Art/`，不向 `MyArt/` 生成文件。

```powershell
python -B Art/Environment/Hearthwood/tools/build_town_layout.py
python -B Art/Environment/Hearthwood/tools/build_farm.py
python -B Art/Environment/Hearthwood/tools/validate_town_layout.py --rebuild
python -B Art/Environment/Hearthwood/tools/validate_town_landscape.py --baseline output/map_art_pass/protected_before.json
python -B Art/Environment/Hearthwood/tools/validate_road_connections.py
python -B Scenes/Gameplay/run_verification.py town --log-tag=map_art_pass
python -B Scenes/Gameplay/run_verification.py transitions --fast --log-tag=map_art_pass
python -B Scenes/Gameplay/run_verification.py map --fast --log-tag=map_art_pass
```

需要带 Pillow 的 Python。本机本轮使用 Codex 工作区依赖中的 Python，系统默认 Python 3.8 没有安装 Pillow。

## 验证结果与对比

- 33 处目标静态连通，30 条道路共 11,387 个中心采样点可容纳角色脚底；喷泉所在的大广场保留中央地标。
- 小镇运行检查 117 项、场景切换 216 项、地图面板 41 项，全部通过，没有运行错误。
- 小镇确定性重建通过；农场布局 JSON 与编辑前逐字节一致。
- 7 个相同镜头各保存编辑前、编辑后的实机截图；共 14 组 640×360 原生视口与 1280×720 窗口图逐像素匹配。
- 仅四张生成地图通过独立微型项目刷新纹理缓存；原项目纹理 UID 和导入参数保留。截图脚本验证运行纹理与当前 PNG 相同。

对比图：`output/map_art_pass/comparison.png`，左列为编辑前，右列为编辑后；三行为西侧入口、月泉广场、风车草甸。完整前后截图位于该目录的 `before/captures/` 和 `after/captures/`。

验证使用隔离设置和存档，没有使用正式玩家进度。旧小镇验证器缺少淡入淡出等待，本轮在测试按键及测试导航中补齐等待；运行时输入和场景切换逻辑未修改。玩家可见文案没有变动。

整体效果沿用现有环境素材风格；这轮集中改善地面层次、景物编排和通行，没有重新制作完整的环境素材库。
