# 女巫造型美化 V2

保留紫帽、银白短发、琥珀色眼睛以及此前收窄的服装和体型。新版重点是弯折帽尖、弧形帽檐、奶油色帽带与月牙饰扣、分组银发和清楚的眼睛高光。2026-10-11 已接入小镇主角、主菜单、命名头像和全部魔杖工具动作。

网络参考：

- [mellynade — Pixel Witch Animation Pack](https://mellynade.itch.io/witch-animation-pack)：小尺寸轮廓、帽子与发型的区分、四方向一致性。
- [Elthen — 2D Pixel Art Witch Sprites](https://elthen.itch.io/2d-pixel-art-witch-sprites)：弯帽和有限色阶的动作辨识度。
- [sinh.png — Little Witch](https://opengameart.org/content/little-witch-0)：紧凑的像素色块与角色识别。

以上只作视觉研究，未下载或拼接其像素。新版头部由内置 imagegen 根据本项目四方向参考图生成，随后切分、最近邻缩小、二值透明度处理并以八叉树归并为 48 色共享调色板。完整生成提示保存在 `generation-prompt.txt`；生成结果是 `generated-heads.png`，原角色排版参考是 `head-layout-reference.png`，原生可编辑头部关键帧是 `head-keys.png`（64×72、2列×2行，顺序正面/背面/右侧/左侧）。

资源和接口：

- `walala-witch-v2.png`：160×192，5列×4行，20帧；每帧32×48；下/上/右/左；第0列待机，第1–4列行走。
- `../WalalaToolsV2/witch-tools-v2.png`：160×576，60帧；全部采集、施法、等待和收杆方向与原版一致。
- `frames/`、manifest、JSON 和六图层 Aseprite 兼容源保持一致。新版完整头部统一存入 hair 图层，装备层保留包与魔杖。该分层用于动作合成，不声称脸、头发和帽子可分别编辑。
- `before-after.png` 和 `design-preview.png`：四方向对比以及部分工具姿势；独立方向 GIF 供循环检查。
- `validation-report.json`：PNG图层、Aseprite兼容源和精灵表的逐字节一致性，透明度、脚底、方向与动作覆盖检查。
- `body-source-sha256.json` 记录合成时使用的原有图层哈希。服装、腿、手持魔杖和动作特效沿用现有图层，未重建原有生成器。
- `myart-before.json` 记录原稿哈希。导出前后全部核对；`MyArt/` 只读，绝不作为写入或清理目标。

重建合成导出（需要 Pillow）：

```powershell
python Art/Character/Storybook/tools/build_witch_v2.py
```

从保存的生成结果重新切分关键帧再合成，使用 `--prepare-keys`。脚本只写入 `WalalaWitchV2/` 和 `WalalaToolsV2/`；原有主角、工具素材及其未提交修改保留。原有 `run_pipeline.py` 继续维护旧版角色；需要同步其服装或动作变更时，再运行本脚本。

世界显示尺寸32×48、脚底锚点(16,48)、移动速度、碰撞、动画帧率、输入和界面文案均保持原有逻辑。Aseprite兼容源已用独立解析器核对，未在 Aseprite 应用内验证。

实机验证记录见 `runtime-validation.json`：Godot 4.7.2 资源导入无错误；12组四方向、行走和工具姿势截图的全部不透明像素与导出源逐像素相同；126项采集与钓鱼检查通过。完整采集回归仍有4项日结束/次日刷新检查失败，使用原版主角和原版工具纹理重跑同一验证，失败项完全一致，因此保留现有玩法代码。测试设置和存档均隔离在 `output/witch-v2/profile/`，日志和实机截图保存在 `output/witch-v2/`。
