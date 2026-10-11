# Aseprite 原文件与 TileMap 工作流

游戏中的角色、建筑、物品、图标、界面纹理、光标和地图图集现在读取 `.aseprite` 文件。`aseprite_source.gd` 注册 Godot 的 `ResourceFormatLoader`，直接解码文件中的 RGBA 图层、帧、标签和时长，不读取同名 PNG，也不依赖玩家电脑安装 Aseprite。编辑器插件 `addons/walala_aseprite` 提供同样的读取方式。

`assets.json` 对应 3,076 张现有图片，包括开发用预览和历史帧图；验证截图不属于游戏美术。`sheets.json` 保存动画帧在贴图中的排列方式。已有的 247 份源文件（含 MyArt 的 3 份）均未被迁移工具覆盖；迁移期间并发更新的女巫原稿也保留了最新版。缺失原稿的 PNG 以完整画布和原始 RGBA 像素创建单图层源文件；这不恢复已经丢失的作者图层。SVG 保留原矢量文件，同时以原生尺寸建立 `.svg.aseprite`；GIF 使用 `.gif.aseprite`，保留帧和时长。字体仍使用字体资源。

MyArt 的食品直接从 `MyArt/Icon/Food/*.aseprite` 读取。加载器声明自定义 UID 支持，因此编辑器不会往原稿目录生成 `.uid` 或 `.import`。所有工具和对照图都在 MyArt 外。

## 编辑美术

用 Aseprite 编辑对应源文件，保存后重新运行游戏即可。角色现有图层、标签和动画均保留；女巫动画时长从源文件读取。旧 PNG/SVG/GIF 是历史对照或预览，不再作为游戏纹理的来源。现有素材均为普通混合模式，加载器支持压缩/原始/关联 cel 和普通透明度合成；新增特殊混合模式或 Aseprite 原生 tilemap cel 前需要扩展解码器。

`build_sources.py` 只补充缺失的源文件，从不覆盖已存在的 Aseprite 文件。旧绘图脚本生成的 PNG 也不会自动覆盖已编辑的源文件；新素材可先生成 PNG，再运行补齐工具。

## 编辑地图

在 Godot 中打开 `Art/Environment/Hearthwood/*.tilemap.tscn`，通过 TileMapLayer 的绘制工具拼接地块。游戏实际实例化这些场景。

- `town_ground.tilemap.tscn`：城镇；`farm_ground.tilemap.tscn`：农场。
- `dock_ground`、`field_background`、`restaurant_ground`、`blacksmith_ground`、`store_ground`：对应区域。
- `home_ground` 和 `home_empty_0/1/2`：原房屋及三个扩建阶段。
- 每个场景引用 `Tiles/<名称>.tres` TileSet，TileSet 读取同目录的 `<名称>.aseprite` 图集；地块为 16×16，重复像素块共用同一 tile。
- 农田的干土/湿土使用独立 32×32 TileMapLayer 和 `Tiles/farm_soil.aseprite`；地块编号、浇水与存档保持一致。香草生长图为 `Tiles/herb_lifecycle.aseprite`。
- Campaign 的 6 个探索区域继续使用原有 TileMapLayer，`terrain.tres` 已改读 `terrain_atlas.aseprite`。

地图概览从当前 TileMap 场景重组地面，因此地图绘制和图集修改也会反映到概览。建筑、角色、资源和碰撞仍按原布局与玩法数据管理；修改道路/房屋位置时同步维护对应 layout JSON。地面切换不改变碰撞、存档或脚步材质规则。

`*.tiles.json` 是首次迁移的单元记录和画布信息。现有 `.tilemap.tscn` 是后续地图绘制的依据；补齐工具不会重建这些场景。不要运行 `--refresh-generated` 覆盖已经编辑的地图。

## 工具与验证

使用带 Pillow 的 Python 运行：

```powershell
python -B Art/Source/build_sources.py
python -B Art/Source/verify_export.py
python -B Scenes/Gameplay/run_verification.py town --log-tag=aseprite_tiles
python -B Scenes/Gameplay/run_verification.py farm --fast --log-tag=aseprite_tiles
python -B Scenes/Gameplay/run_verification.py map --fast --log-tag=aseprite_tiles
python -B Scenes/Gameplay/run_verification.py transitions --fast --log-tag=aseprite_tiles
```

Godot 开发验证入口为 `verify_sources.gd`（像素及 TileMap 重组）与 `verify_render.gd`（实际 GPU 渲染）。Aseprite 批处理可运行 `verify_aseprite.lua`，参数 `root` 为项目路径。`build_tile_scenes.gd` 仅补充尚不存在的地图场景。两个 `capture_*_sources.gd` 是迁移时的历史提取工具，源文件存在后不会再次生成。

迁移报告和截图在 `output/aseprite_migration/`，使用隔离设置与存档。迁移时全部 PNG 对应源文件像素一致，11 份地面实际 GPU 渲染逐像素一致；MyArt 的全部内容和哈希不变。其他并发原稿更新记录在 `concurrent_updates.json`。后续修改源文件或地图后，对照旧 PNG 的一致性检查会正常报告差异。

项目的 Windows Desktop 导出预设已包含 `*.aseprite,*.ase,*.json,*.tsv,*.bank`。自建导出预设时保留这些运行时数据过滤器，并启用编辑器插件。`verify_export.py` 已验证不含任何 PNG 的 PCK 可以读取角色、MyArt 原稿和可编辑 TileMap。正式游戏不需要 Python、Pillow 或 Aseprite 应用。

实现依据：[Aseprite 文件规范](https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md)、[Godot ResourceFormatLoader](https://docs.godotengine.org/en/stable/classes/class_resourceformatloader.html)。
