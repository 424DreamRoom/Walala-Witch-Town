# 紧凑室内布局

杂货店、铁匠铺、家具店的可活动地板为 328×202（原 520×298），家具保持原生像素尺寸。后墙集中摆放货架和工作设施，柜台两侧留通路，床、粮袋和食材陈列靠南侧。餐厅地板为 328×198（原 424×230），保留三列两排、六个座位，备料台和料理台之间收紧到 20 像素。

主角房间是紧凑布局的参照；已有房屋升级、玩家摆放的家具、箱内物品和旧版住宅保持原有数据。公共室内的存档位置若落入缩减掉的地板或家具碰撞范围，读档时回到该室内安全出生点；有效位置保留。

运行时店铺家具、碰撞、店员、服务点和出口以 `Art/Environment/Hearthwood/*_layout.json` 为准。`ground_scene` 指向紧凑 TileMap。餐厅几何在 `Scenes/Gameplay/play_area.gd`，地图预览同步使用相同 TileMap 和更新后的地点坐标。

紧凑地板直接重排已有 TileMap 的 16×16 图块，复用现有 TileSet 和 Aseprite 图集，不重绘、缩放或调色。原始地板 TileMap 保留。调整原始地图后可重新生成紧凑版本：

```powershell
& $env:GODOT_BIN --headless --path . --script res://Art/Environment/Hearthwood/tools/build_compact_interiors.gd
```

`build_businesses.py` 仍生成原尺寸的素材预览；它会保留带 `ground_scene` 的运行时布局，避免把公共室内恢复为旧尺寸。任何工具均不以 `MyArt/` 为输出或清理目标。

隔离验证：

```powershell
& $env:GODOT_BIN --headless --fixed-fps 60 --path . --script res://Scenes/Gameplay/verify_compact_interiors.gd
```

该脚本使用 `output/compact_interiors/` 下的独立设置与存档，检查真实行走、每件家具的接近点、店员碰撞、服务开关、出入门、满座送餐和旧坐标恢复。附加 `-- --compact-capture` 可在图形模式下生成实机截图。
