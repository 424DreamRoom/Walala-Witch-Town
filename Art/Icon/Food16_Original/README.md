# 原创食物图标 / Original food icons

20 个原生 16×16 原创逐像素图标，低饱和柔和配色，与 Resources16_Original 同系列。没有缩小生成参考图，没有提取游戏素材。

每种提供独立透明 RGBA PNG 和 32-bit RGBA Aseprite 源文件。源文件均为一帧、四个非空普通像素图层：Outline（轮廓）、Base color（底色）、Light and shadow（明暗）、Details（细节）。图层可独立编辑，不是扁平图冒充源文件。

## 清单 / Manifest

| 中文 | English | PNG | Aseprite |
|---|---|---|---|
| 鱼肉 | Fish meat | fish_meat.png | fish_meat.aseprite |
| 鸡腿 | Chicken drumstick | chicken_leg.png | chicken_leg.aseprite |
| 西红柿 | Tomato | tomato.png | tomato.aseprite |
| 鸡蛋 | Egg | egg.png | egg.aseprite |
| 白菜 | Napa cabbage | napa_cabbage.png | napa_cabbage.aseprite |
| 茄子 | Eggplant | eggplant.png | eggplant.aseprite |
| 土豆 | Potato | potato.png | potato.aseprite |
| 胡萝卜 | Carrot | carrot.png | carrot.aseprite |
| 洋葱 | Onion | onion.png | onion.aseprite |
| 南瓜 | Pumpkin | pumpkin.png | pumpkin.aseprite |
| 蘑菇 | Mushroom | mushroom.png | mushroom.aseprite |
| 香草 | Herbs | herbs.png | herbs.aseprite |
| 浆果 | Berries | berries.png | berries.aseprite |
| 苹果 | Apple | apple.png | apple.aseprite |
| 玉米 | Corn | corn.png | corn.aseprite |
| 小麦 | Wheat | wheat.png | wheat.aseprite |
| 虾 | Shrimp | shrimp.png | shrimp.aseprite |
| 牛肉 | Beef | beef.png | beef.aseprite |
| 牛奶 | Milk | milk.png | milk.aseprite |
| 奶酪 | Cheese | cheese.png | cheese.aseprite |

鱼肉为带浅色肉纹和底部皮边的切块，而非整鱼；鸡腿带浅色骨头；白菜为纵向浅色叶梗和绿色顶部，不是圆生菜；牛奶采用瓶装造型。图标光源为左上方，外围保留真正透明边距。

## 预览 / Preview

preview_nearest_12x.png：5 列 × 4 行，按上述顺序，最近邻放大 12 倍，完整画布 1120×1008。棋盘格仅在合集预览中，资产 PNG 不含棋盘格。已查看完整合集，并将胡萝卜刻纹由绿色修正为暖棕色，再次查看修正版。

## 实际校验 / Validation

manifest.json 提供完整中英文名称及文件映射；validation_report.json 为实际校验结果，20 项全部通过。

- 严格 16×16、PNG 格式、RGBA、alpha 仅 0/255；外边距透明，透明像素 RGBA 为 0/0/0/0。
- Aseprite 文件大小、文件头 magic、帧头、32-bit 位深、图层块、压缩 cel 块全部解析通过。
- 每个源文件四个非空图层及四个 cel；独立解压、按图层顺序合成，与对应 PNG 的 RGBA 字节完全一致。
- 清单数量 20，文件映射无缺漏、无重复名称；20 个像素内容哈希各不相同。
- 未在 PATH 找到 Aseprite CLI，未做 Aseprite 应用打开验证；采用复用的独立二进制解析及像素往返验证。不安装软件，不搜索未授权项目外文件。

项目根目录复核：

```powershell
python -B Art/Icon/Food16_Original/tools/validate_food.py
```

制作脚本 tools/build_food.py 复用前期 Aseprite 写入器，校验脚本 tools/validate_food.py 复用前期独立解析器，均不会修改 Resources16_Original。制作脚本拒绝覆盖已有成品。

生图参考为一株长形白菜，只借鉴叶梗与配色，未读取参考像素用于成品。参考由媒体工具保存到项目 output/media 目录。

只新增本目录食物素材及制作/说明/校验文件与生成参考。未修改菜谱、库存、玩法、场景、project.godot 或已有资源；保留用户原有变更。
