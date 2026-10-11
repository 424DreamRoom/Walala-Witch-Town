# NPC 原生 32×32 Aseprite 源稿

2026-10-11：17 位 NPC 共 257 帧，全部通过本机 Aseprite 的 Lua 像素 API 在 **32×32 RGBA 画布**中直接绘制，并由 Aseprite `Sprite:saveAs` 保存原生 `.aseprite`。未导入大图、缩小旧素材或使用自制二进制写入器。配色沿用角色设定，单个角色使用 18–23 个不透明颜色，透明度仅为 0 或 255。

## 交付文件

| 目录 | 数量 | 帧与用途 |
| --- | --- | --- |
| `residents/*.aseprite` | 10 | 茉莉、余烬、澪、露米、星芒、陶陶、皮普、芦苇、霜铃、奥萝；每人 22 帧 |
| `customers/*.aseprite` | 6 | 绿帽棕辫、蓝帽浅金、酒红帽卷发、橙帽短发、青帽灰发、粉帽深蓝长发；每人 6 帧 |
| `guides/yingluo.aseprite` | 1 | 萤萝；1 帧静态站姿，保留游戏原有行走位移表现 |
| `portraits/*.png` | 10 | 从居民原文件第 17 帧原生导出的 32×32 待机头像 |

每个原文件含六个独立、可见、解锁的普通像素图层，从底至顶为 `Boots`、`Clothing`、`Face and hands`、`Hair`、`Headwear`、`Accessories`。图层未扁平化，帽子、头发、脸部、服装和配件可分别修改。

居民帧索引保持游戏接口：0–3 下、4–7 上、8–11 右、12–15 左，16–17 待机，18–21 用餐。对应 `walk_down/up/right/left`、`idle`、`eat` 标签；行走每帧 140 ms，待机 900/160 ms，用餐每帧 500 ms。六位餐厅客人为 0–1 待机、2–5 用餐。脚底锚点统一为 (16,32)。每个方向的四帧行走、四帧用餐均有独立像素变化。

同名 PNG 为 Aseprite 原生横向精灵表：居民 704×32，客人 192×32，萤萝 32×32。精灵表宽度是多帧拼接宽度，原文件画布和每一帧都是 32×32。`preview.png` 是最近邻放大审阅图；`directions-preview.png` 展示居民方向及用餐；各角色 `*-preview.gif` 为动画预览。

## 编辑与导出

直接在 Aseprite 打开对应 `.aseprite` 编辑即可。更新源文件后，以下命令仅重新导出 PNG、头像、预览和校验，**不会重新绘制原文件**：

```powershell
& 'C:/Users/30283/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' Art/Characters/NPC32/tools/build_npcs.py --export-only
& 'C:/Users/30283/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' Art/Characters/NPC32/tools/verify_runtime.py import
```

首次创建原文件使用 `build_npcs.py`；已经存在原文件时默认拒绝覆盖。`--replace-generated` 会用 Lua 配方重绘 NPC32 目录中的原文件，丢弃其中的手工编辑，勿用于编辑后的原稿。角色配方保存在 `tools/build_npcs.py` 与生成的 `tools/specs.lua`，实际像素绘制保存在 `tools/draw_npcs.lua`。Aseprite 路径可由 `--aseprite` 指定。

游戏的居民、商店员工、餐厅客人、居民手记头像、对话头像及萤萝均已切换到本目录。世界精灵显示 1:1，脚底偏移统一为 (0,-16)，保留原有帧索引、输入映射、碰撞、日程和结算逻辑。旧目录素材保留。未修改玩家可见文案，因此没有变更语言词库。

## 验证记录

- `validation.json`：17 个 Aseprite 原文件均由 Aseprite 重新打开导出；独立解码 257 帧、图层、透明度、脚底和动画差异，分层合成与原生 PNG 逐字节一致。
- `runtime-import.json`：仅将 27 张实际使用的 PNG 放入隔离小项目导入，避免扫描原稿目录。导入缓存复制回游戏。
- `runtime-art.json`：173 项专项检查全部通过。包含 257 帧全部实际 GPU 渲染像素逐字节一致、10 位居民四向帧与脚底、全部 16 位客人的等待及四帧用餐、萤萝、商店员工和完整 32×32 对话头像。
- `runtime-regression.json`：巡灯员回归 133 项、世界遮挡与排序 1064 项通过。较广流程回归未全部通过：居民雨雪避雨两项、商店进入铁匠铺一项失败，旧 NPC 素材在独立测试进程中复现完全相同失败，见 `runtime-baseline.json`；餐厅流程回归在日落/菜单/食谱流程失败并中止，未完成旧素材对照。本次没有更改这些玩法流程。
- 实机截图：`output/npc32/town.png`、`dialogue.png`、`restaurant.png`、`blacksmith.png`、`store.png`；全部 257 帧的 GPU 导出为 `output/npc32/all-257-frames-rendered.png`。

验证使用 `output/npc32/` 中的隔离 APPDATA/LOCALAPPDATA 以及脚本指定的测试设置与存档。`MyArt/` 只读，制作、导出、导入与实机检查前后均核对其中三个原文件的路径和 SHA-256，未发生变化。所有工具、原文件、导出和测试产物均位于 `MyArt/` 之外。

```powershell
& 'C:/Users/30283/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' Art/Characters/NPC32/tools/verify_runtime.py art
```

Aseprite 原生 API 依据：[Sprite](https://aseprite.org/api/sprite)、[Image](https://aseprite.org/api/image)、[命令行导出](https://aseprite.org/docs/cli/)。
