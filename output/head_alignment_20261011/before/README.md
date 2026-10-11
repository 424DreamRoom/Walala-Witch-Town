# 主角：Aseprite 原生 32×32

2026-10-11：通过本机 **Aseprite 1.3.18.6** 的 Lua 绘图接口，在 `Sprite(32,32)` 画布上直接绘制全部像素、图层和动画，使用 Aseprite 本身保存 `walala-witch.aseprite`。没有导入大图后缩小，没有复用或修改 `MyArt/` 原稿。保留紫色弯尖帽、银白短发、月牙帽饰、奶油领口和小挎包，使用 24 个不透明颜色及透明背景。

## 文件

- **`walala-witch.aseprite`**：主要可编辑原稿，32×32、152 帧、9 图层、28 标签。
- `walala-witch.png`：Aseprite 导出的 256×608 精灵表，8 列、19 行，每帧保留完整 32×32 画布。
- `walala-witch.json`：Aseprite 导出的原始帧位置、时长、标签和图层信息。
- `character-manifest.json`：运行时动画目录，保留源文件帧时长及循环策略。
- `design-preview.png`、`animations-preview.gif`：四方向及四种主要动作预览，使用整数最近邻放大。
- `contact-sheet.png`：全部 152 帧预览。
- `validation-report.json`、`runtime-validation.json`：源文件及实际 Godot 渲染验证。

## 动画

方向顺序为 `down / up / right / left`，每个方向 38 帧。标签采用动作加方向，如 `idle-down`、`run-left`。

| 标签前缀 | 每方向帧数 | 动作 |
|---|---:|---|
| `idle` | 4 | 呼吸、头部起伏和正侧面的眨眼 |
| `walk` | 8 | 双脚交替、手臂摆动及披风摆动 |
| `run` | 8 | 独立奔跑姿势、摆臂、腾空及侧面后飘披风 |
| `cast` | 8 | 预备、举杖、蓄力、青绿色魔力释放、收势 |
| `fish-cast` | 4 | 钓鱼抛竿姿势 |
| `fish-wait` | 2 | 持杖等待 |
| `fish-reel` | 4 | 收竿姿势 |

砍树、采矿、除草及农田施法统一使用 **`cast`**。采集控制器内部 `chop/mine` 状态、资源判定、命中时机、奖励、音效和行动时长保留，视觉映射统一到施法标签，并按行动时长播放完整的 8 帧。钓鱼保留现有玩法与独立姿势，鱼线起点跟随新画面的法杖尖端。

脚底锚点为 `(16,32)`，运行时显示 32×32，采用最近邻显示。待机、行走和奔跑按源文件时长循环；施法与抛竿/收竿播放一次并停在末帧。切换行走与奔跑时重置动画相位。

## 图层

由下至上：`hair_back`、`legs`、`cape`、`outfit`、`face`、`hair_front`、`hat`、`hands_wand`、`magic`。帽子、前后头发、面部、服装、腿部、双手法杖及魔力特效均可单独编辑。地面阴影由游戏绘制。

2026-10-11 背面头部对齐：全部 38 个 `*-up` 帧的 `hair_back`、`hair_front` 图层向右平移 1 个原始像素，使头发轮廓与衣领、帽檐中线对齐。保留原有像素、颜色、透明度、32×32 画布、帽子、身体及其他方向；`tools/draw_witch.lua` 同步使用修正坐标。修改前备份和像素核对记录见 `output/head_alignment_20261011/`。

## 编辑和导出

直接在 Aseprite 中编辑 `.aseprite` 原稿，然后运行下列命令导出并验证；默认不会重新绘制或覆盖原稿：

```powershell
python Art/Character/Storybook/WalalaWitchAseprite32/tools/build.py
```

只有显式添加 **`--redraw`** 才会调用 `tools/draw_witch.lua` 重绘原稿。需要 Aseprite 1.3+ 和 Pillow；可通过环境变量 `ASEPRITE_BIN` 指定 Aseprite 路径。当前机器的 Python 运行环境见 Codex workspace dependencies。绘图接口依据 [Aseprite Sprite API](https://www.aseprite.org/api/sprite) 和 [Image API](https://www.aseprite.org/api/image)。

生成脚本仅向本素材目录及 `output/witch-aseprite32/` 写入。Lua 也拒绝 `MyArt` 路径及其他素材目录。导出前后核对 `MyArt/` 全部文件 SHA256，不移动、覆盖或清理原稿。

## 验证

```powershell
python Art/Character/Storybook/WalalaWitchAseprite32/tools/verify.py import
python Art/Character/Storybook/WalalaWitchAseprite32/tools/verify.py lane
python Art/Character/Storybook/WalalaWitchAseprite32/tools/verify.py render
python Art/Character/Storybook/WalalaWitchAseprite32/tools/verify.py harvest
```

测试使用 `output/witch-aseprite32/profile/` 的隔离设置、存档及操作系统用户目录。Aseprite 创建、重新打开和独立导出验证通过；全部 152 帧为二值透明，28 个标签范围连续且正确，奔跑帧与行走帧独立。Godot 实际渲染 192 项通过，包括全部 152 帧不透明像素与源图逐像素一致；四方向移动、动画、碰撞及相机 67 项通过。采集回归结果和旧动画对照记录见 `integration-validation.json`，详细日志、游戏截图及对照夹具在 `output/witch-aseprite32/`。
