# 游戏食物占位图标

运行时统一使用 `Scenes/UI/food_icons.gd`，接入食谱、四季手记仓储、探索采集物、背包/木箱/道具栏及角色端菜。现有菜谱、物品 ID、库存、价格、输入和存档结构保持原样。原来的素材目录保留。

`MyArt/Icon/Food/` 始终只读。现有 `bread.aseprite`、`egg.aseprite`、`tomato.aseprite` 原生 16×16 原稿分别用于面包/风铃面包、鸡蛋、番茄；导出保留完整画布、像素和透明度，存入本目录的 `icons/`。生成前后比较原稿 SHA-256，清单保留原稿哈希。不会在 MyArt 中生成文件。

其余食物使用下载的 CC0 像素图标；详细的每项 PNG、来源 ZIP/文件、裁切区域、尺寸和哈希见 `manifest.json`，合集见 `preview.png`。素材保持原生 16、24 或 32 像素，不重绘或调色；端菜和探索物采用整数倍最近邻显示。

## 来源与许可

- [16x16 Food — ARoachIFoundOnMyPillow](https://opengameart.org/content/16x16-food)：188 个 16×16 食物，CC0。原始下载 `https://opengameart.org/sites/default/files/food_0.zip`。
- [CC0 Food Icons — AntumDeluge 汇编](https://opengameart.org/content/cc0-food-icons)：只使用 bluecarrot16 的鱼、7Soul1 的熟鱼、Fleurman 的茶。各自 ZIP 内附来源说明。bluecarrot16 原作：[LPC Food](https://opengameart.org/node/98209)；Fleurman 茶：[Tea](https://opengameart.org/node/77729)。该汇编明确以 CC0 发布所选文件。
- [Free Pixel Food! — Henry Software](https://henrysoftware.itch.io/pixel-food)：CC0，原生 16×16 食物表。从 [OpenGameArt 镜像](https://opengameart.org/content/64-16x16-food-sprites) 下载原始 `Food.png`，保存为 `sources/HenryFood.png`。只裁出完整的 16×16 单元格，用于牛奶、莓果牛乳、油及干料罐。

来源页面副本与未修改的原始下载位于 `sources/`，此目录包含 `.gdignore`，不会导入游戏。CC0 允许商用、修改及再分发，无强制署名；此处仍保留作者和来源以便追溯。手绘原稿不适用第三方 CC0 声明。

## 占位对应

网络包没有完全对应的幻想食物时，暂用同类外观：小麦用谷物（玉米），月光花用香草（香草荚），春笋用芦笋，莲藕用根茎，面粉/盐用干料罐。汤、饭、沙拉、烤鱼和甜点按类别对应，多个菜品可以共用一个图标。该对应只影响图像，名称、配方和效果仍属于游戏中的原食物。清单标记 `placeholder: true`；MyArt 导出为 `false`。

新增同名手绘原稿后重新生成即可覆盖对应占位图；菜品可使用 `dish_<菜谱ID>` 或菜谱 ID 命名，`bread` 同时对应 `dish_wheat_bread`。

## 生成与验证

需要 Python 3.9+ 和 Pillow；Aseprite 导出器支持本项目现有的单帧 RGBA、普通图层原稿，遇到不支持的结构会停止，不会静默改图。

```powershell
python Art/Icon/FoodPlaceholders/acquire_sources.py
python Art/Icon/FoodPlaceholders/build_food_icons.py
python Art/Icon/FoodPlaceholders/validate_food_icons.py
python Art/Icon/FoodPlaceholders/run_verification.py import
python Art/Icon/FoodPlaceholders/run_verification.py headless
python Art/Icon/FoodPlaceholders/run_verification.py capture
```

测试设置和存档仅位于 `output/food_icons/`，真实界面截图也保存在该目录。`sources/source-contact-sheet.png` 是选图时使用的最近邻放大参考，可由 `inspect_sources.py` 重建。

本次验证：86 个 PNG 的来源像素、原生画布及 MyArt 哈希核对通过；40 种食材和 36 道菜全部覆盖。Godot 导入通过，真实界面与截图检查 95 项通过，现有餐厅回归复跑 54 项通过，多语言词库 881 项检查通过。已查看食谱、仓储、背包、手绘番茄/鸡蛋、面包食谱及角色端面包截图。像素检查使用工作区附带的 Python 3.12 与 Pillow 12.3，游戏检查使用 Godot 4.7.2。

## 烹饪扩充

当前运行内容扩展为120种食材与360道菜谱，图标共485个。新增映射由 `Scenes/Campaign/cooking_expansion.py` 编入 `content.json` 的 `food_icons` 字段；`build_food_icons.py` 合并这些映射并沿用MyArt优先级与像素、画布、透明度、哈希保护。新增食材和菜品复用现有CC0原图作为占位，同类料理可共用图标；新增原稿后使用同名ID即可覆盖。此前86图标的验证记录为扩充前基线。

扩充验证入口为 `python Scenes/Campaign/run_cooking_verification.py headless`，界面截图用 `capture` 模式，结果位于 `output/cooking_expansion/`。
