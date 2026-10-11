# 原创基础资源图标（16×16）

| 资源 | 可编辑源文件 | 透明导出 |
|---|---|---|
| 木材：木段及切面年轮 | wood.aseprite | wood.png |
| 石头：灰绿色石块 | stone.aseprite | stone.png |
| 黄金：柔和金块 | gold.aseprite | gold.png |
| 铁矿：冷灰原石及暖色矿粒 | iron_ore.aseprite | iron_ore.png |
| 魔女币：紫灰币、魔女帽及月牙 | witch_coin.aseprite | witch_coin.png |

全部原创逐像素绘制，原生 16×16，未从参考大图缩小或提取游戏素材。低饱和配色、左上光照、硬像素边缘；PNG 为 RGBA，alpha 仅 0/255，外围留透明边距。

每个 Aseprite 文件含一个 32-bit RGBA 帧和四个独立可编辑的普通像素图层（从底至顶）：Outline（轮廓）、Base color（底色）、Light and shadow（明暗）、Details（细节）。图层像素按语义分配，无扁平合并替代源文件。

## 预览

preview_nearest_16x.png：五图横排，每个图标最近邻放大 16 倍。棋盘格只存在于预览，不存在于透明 PNG 中。

## 制作及验证

- tools/build_resources.py：逐像素定义及 Aseprite 二进制生成脚本。拒绝覆盖既有输出。
- tools/validate_resources.py：独立解析文件头、帧头、图层及压缩 cel，检查尺寸、位深、alpha、透明边距及四层内容；将解码的四层合成，与 PNG 逐字节比较。
- validation_report.json：五个源文件及 PNG 的实际校验结果，全部通过。
- 未在 PATH 或项目中发现 Aseprite 可执行程序；没有安装软件或搜索项目之外的文件。因此未做 Aseprite 应用/CLI 打开测试，采用二进制结构校验、zlib 解码和像素级往返一致性验证。
- 已人工查看最近邻放大合集。

项目根目录复核命令：

```powershell
python Art/Icon/Resources16_Original/tools/validate_resources.py
```

生图工具仅生成木材造型与配色参考；它输出的是带烘焙棋盘格的 JPEG，未作为任何成品图标的像素输入。参考保存在项目 output/media 目录。主场景、project.godot 和现有资源没有修改。
