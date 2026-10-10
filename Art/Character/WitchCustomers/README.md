# 六款原创女巫餐厅顾客

此目录为旧版16×24客人素材和历史记录。当前游戏加载 `Art/Character/Storybook/WitchCustomers/` 中的原生32×48重绘。

本目录是餐厅顾客的原生像素资源，不覆盖 `Art/Character/WalalaWitch` 主角素材。

## 资源

- 六款独立 `*.aseprite`：每款 6 个 16×24 RGBA 帧、5 个可编辑图层（Shoes / Outfit / Hair / Hat / Details）。Aseprite 标签：`idle`（2帧）和 `eat`（4帧）。
- 六款独立 `*.png`：每张 96×144，6列×6行布局中的实际帧区为首行6帧；透明背景、最近邻像素。
- `witch_customers_all.png`：六款横向合辑精灵表，6列×6行，每行一个顾客。
- `preview_nearest_8x.png`：最近邻8倍审阅预览，按顾客分行、每行6帧。
- `customers.json`：变体、帧、标签和源信息。
- `tools/build_customers.py`：直接在16×24画布上整数像素绘制；不读取、不缩放参考大图。
- `tools/validate_customers.py`：独立解析Aseprite块、PNG尺寸/alpha、图层和标签。

## 六款区别

1. 绿帽棕辫：两侧辫子、绿色服装与围裙。
2. 蓝帽浅金：浅金短发、蓝色服装。
3. 酒红帽深卷发：卷发块、酒红服装。
4. 橙帽黑短发：黑色短发、橙棕服装。
5. 青帽灰发：灰色侧发、青色服装。
6. 粉帽深蓝长发：两侧长深蓝发、粉紫服装。

视觉参考由 media-generation 生成，仅用于配色/轮廓方向；最终文件全部由脚本原生16×24逐像素绘制。

## 接入规则

`Scenes/Gameplay/loop_state.gd` 为每位新顾客保存稳定 `variant`，不会每帧随机。顾客仍直接落座，没有走路系统。成功上菜后收入立即只记一次，顾客保持座位并进入3秒 `eating` 状态，期间不扣耐心、不接受再次上菜；用餐结束后离席，保持满座限制和原有结算/次日流程。

`Scenes/Gameplay/play_area.gd` 只替换餐厅顾客绘制和必要状态显示，运行时从PNG文件读取并保留原有程序地图与循环。

## 验证

```powershell
python Art/Character/WitchCustomers/tools/validate_customers.py
python Scenes/Gameplay/run_verification.py headless
```

独立资源报告会写入 `validation_report.json`。Aseprite应用内打开验证未完成：本机未安装/未在PATH发现Aseprite，因此只做了独立二进制解析和Godot运行验证。
