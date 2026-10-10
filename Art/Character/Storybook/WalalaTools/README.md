# 小女巫采集工具动作

沿用小女巫现有紫帽、银发及纤细服装，不缩放人物。每帧32×48，脚底第47行，脚底锚点(16,48)，透明度仅0/255，最近邻渲染。运行时使用独立动作精灵，动作结束恢复原有待机/移动精灵；共享碰撞、脚底阴影及Y排序。

`witch-tools.png` 为5列×12行、160×576 PNG，总计60帧。`witch-tools.json` 和 `character-manifest.json` 记录切格、帧时长及动作标签。每组方向均为 down / up / right / left。

| 动作 | 帧范围 | 每方向帧数 | 每帧时长 |
|---|---|---:|---:|
| chop | 0–15 | 4 | 170ms |
| mine | 16–31 | 4 | 170ms |
| cast | 32–43 | 3 | 150ms |
| wait | 44–47 | 1 | 300ms |
| reel | 48–59 | 3 | 200ms |

`frames/` 含每帧的 shadow/body/outfit/hair/equipment/fx 六层PNG；`witch-tools.aseprite` 为包含同样图层、帧时长及20个方向标签的Aseprite兼容源。已用独立二进制解析器检查图层与导出PNG逐像素一致；未用本机Aseprite应用打开验证。

```powershell
python Art/Character/Storybook/tools/build_tools.py
python Art/Character/Storybook/tools/validate_sources.py
python Scenes/Gameplay/run_verification.py harvest_capture
python Art/Character/Storybook/tools/build_tools.py --runtime-preview
```

生成器同时生成本项目原创砍树、挖矿、抛竿、咬钩、收鱼WAV音效，不依赖下载。`runtime-preview.png` 从真实游戏截图裁切并最近邻放大，非合成游戏场景。完整窗口截图位于 `Scenes/Gameplay/Verification/Harvest/`。
