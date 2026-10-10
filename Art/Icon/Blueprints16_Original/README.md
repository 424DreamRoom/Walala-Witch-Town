# 家具蓝图与食谱蓝图

两款原创原生 16×16 像素图标，与 Resources16_Original、Food16_Original 的低饱和配色、左上光源和像素尺寸保持一致。逐像素绘制，没有缩小大图或提取参考素材。

| 图标 | PNG | Aseprite 源文件 |
|---|---|---|
| 家具蓝图 | furniture_blueprint.png | furniture_blueprint.aseprite |
| 食谱蓝图 | recipe_blueprint.png | recipe_blueprint.aseprite |

家具蓝图使用青蓝纸张、折角与奶油色椅子图样；食谱蓝图使用羊皮纸、热汤碗、汤勺和带缺口的红色书签。PNG 背景透明，外围保留透明边距；棋盘格仅存在于 preview_nearest_16x.png 预览中。

每个 `.aseprite` 都是单帧 32-bit RGBA 源文件，包含四个非空、可独立编辑的普通像素图层：Outline（轮廓）、Base color（底色）、Light and shadow（明暗）、Details（图样与装饰）。四层均使用可见与可编辑标记（1 + 2），对应 [Aseprite 官方文件格式](https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md)。PNG 是四层合成的原生导出。

Godot 纹理路径列在 manifest.json 中，可直接引用两个 PNG；按整数倍缩放并使用最近邻过滤。此资源包提供蓝图类别图标，解锁家具或菜谱的逻辑由使用它的系统决定。

## 校验与重建

```powershell
python -B Art/Icon/Blueprints16_Original/tools/build_blueprints.py --overwrite
python -B Art/Icon/Blueprints16_Original/tools/validate_blueprints.py
```

制作与校验复用项目现有 Aseprite 写入器和独立解析器。validation_report.json 记录文件头、图层块、压缩 cel、四个非空图层、透明边距及源文件合成与 PNG 逐像素一致的实际校验结果。本机 PATH 未发现 Aseprite CLI，因此未进行 Aseprite 应用打开验证。
