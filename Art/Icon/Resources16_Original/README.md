# 原创资源图标（16×16，第二版）

| 资源 | 可编辑源文件 | 透明导出 |
|---|---|---|
| 木材：木段及切面年轮 | wood.aseprite | wood.png |
| 石头：灰绿色石块 | stone.aseprite | stone.png |
| 黄金：暖色金属锭 | gold.aseprite | gold.png |
| 铁矿：蓝灰原石及成簇矿粒 | iron_ore.aseprite | iron_ore.png |
| 铁锭：冷色金属锭 | iron.aseprite | iron.png |
| 鱼：青绿色鱼身、浅色腹部 | fish.aseprite | fish.png |
| 魔女币：金色币沿、紫色魔女帽纹章 | witch_coin.aseprite | witch_coin.png |

全部直接在 **16×16 原生网格**上绘制，主体外围至少留 1 像素透明边距，每个图标使用 6–7 种不透明颜色。统一左上光照、右下阴影、硬像素边缘；PNG 为 RGBA，alpha 仅 0/255。没有缩小大图或提取参考图像素。

每个 Aseprite 文件含一个 32-bit RGBA 帧和四个独立可编辑的普通像素图层（从底至顶）：Outline（轮廓）、Base color（底色）、Light and shadow（明暗）、Details（细节）。图层像素按语义分配，无扁平合并替代源文件。

## 预览

`preview_nearest_16x.png`：保留原文件名以兼容已有链接；当前七图合集为 10 倍最近邻主预览、两种背景上的 3 倍预览，以及原生 1 倍预览。棋盘格仅存在于预览中。

## 游戏接入与参考

`Scenes/UI/hud_art.gd` 统一加载这套 PNG，HUD、快捷栏、背包、木箱和服务菜单中通过 `ornament()` 显示的资源沿用相同素材。实际内容按原生 16×16 居中放在已有 24×24 UI 区域，最近邻显示，不改变布局、输入或库存逻辑。`Scenes/Equipment/upgrade_panel.gd` 的金币、木材、铁锭费用直接引用同套图标。

石头和黄金作为已有资源图标继续维护；此次未新增对应玩法或物品。网络参考图、作者页面和逐像素绘制要点见 [REFERENCES.md](REFERENCES.md)。

## 制作及验证

- tools/build_resources.py：原生像素源稿和四层 Aseprite 导出；默认拒绝覆盖，明确传入 `--replace` 才更新本目录输出。
- tools/validate_resources.py：独立解析文件头、帧头、图层及压缩 cel，检查尺寸、位深、alpha、透明边距及四层内容；将解码的四层合成，与 PNG 逐字节比较。
- manifest.json：导出清单、图层、光源、像素规格和 PNG 哈希。
- validation_report.json：七组源文件及 PNG 的实际校验结果。采用二进制结构校验、zlib 解码和像素级往返一致性验证，未声明 Aseprite 应用打开测试。
- 已人工查看最近邻放大合集、浅色和深色背景、原生尺寸预览。
- 本次修改前的目标文件快照和隔离游戏验证结果保存在 `output/resource_icons_v2/`。
- Godot 导入、库存 63 项、默认图形后端的装备界面 183 项、装备无窗口 175 项均通过；实际背包和升级费用截图已检查。本地化词库 844 条检查通过。
- OpenGL 兼容模式的 183 项功能检查通过，但该验证进程退出时报一条纹理释放错误（`equipment.log`）；项目默认图形后端同场景验证干净退出（`equipment_native.log`）。

项目根目录复核命令：

```powershell
python Art/Icon/Resources16_Original/tools/build_resources.py --replace
python Art/Icon/Resources16_Original/tools/validate_resources.py
```

沿用项目已有的可编辑逐像素源稿工作流，玩家界面文字保持原样。
