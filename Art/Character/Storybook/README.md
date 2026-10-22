# 参考画风人物重绘

2026-10-22 当前主角已切换为 [WalalaWitchCuteAseprite32](WalalaWitchCuteAseprite32/README.md)：原生32×32可爱版，圆脸、大眼、腮红与上提帽檐，保留152帧、28标签和既有脚底锚点。共享动画入口仍在 `WalalaWitchAseprite32/witch_animation.gd`，其素材常量指向新版；旧版源文件保留。新旧对照见 `WalalaWitchCuteAseprite32/before-after.png`。

2026-10-11 当前主角使用 [WalalaWitchAseprite32](WalalaWitchAseprite32/README.md)：在本机 Aseprite 的32×32画布中直接绘制并保存原生源文件，含四方向 idle / walk / run / cast，独立奔跑姿势及统一的砍树、采矿施法动画；另保留钓鱼姿势。共152帧、9个可编辑图层、28个标签。下文素材和生成流程作为历史版本保留。

上一版记录：2026-10-11 运行时主角和工具动作切换为原生 **32×32** 的 [WalalaWitch32](WalalaWitch32/README.md) / `WalalaTools32`。该版重新设计四方向全身比例，保留紫帽、银发、奶油色领口与挎包，含20帧移动及60帧法杖动作。下文32×48资源、[V2](WalalaWitchV2/README.md)与旧流程作为历史版本保留；该版使用 `tools/build_witch_32.py` 重建。

按 `游戏参考截屏/东方夜雀食堂/主角的家（加上主角）.png` 中人物的大头短身、大眼睛、细轮廓与柔和布料阴影制作的原创像素人物。保留主角紫色弯尖帽、银白短发，增加奶油色衣领、月牙帽饰和小挎包；六位客人保留各自的帽色、发型和身份。参考取样、画风约定与有意差异见 `STYLE.md`。

每帧原生 32×48，直接在整数像素上绘制，透明度仅 0/255。游戏显示尺寸为 32×48，脚底锚点为 (16,48)，通过最近邻整数缩放到窗口。主角四方向、行走和跑步帧率沿用既有动画接口。

2026-10-10 主角体型修订：四方向20帧重新绘制较窄的肩部、收腰斗篷与短裙摆，短发更贴合脸型，帽檐收至24像素，腿部露出更多；地面阴影同步收窄。`slimming-comparison.png` 上行为修订前，下行为修订后。主角单独重建使用 `python Art/Character/Storybook/tools/run_pipeline.py --hero-only`。

本次体型修订验证：20帧严格资源检查零错误/零警告，兼容源与PNG逐帧一致；全部20帧的第35–42行躯干轮廓均比旧版窄，正面待机19→15像素、背面23→15、侧面17→11，数据在 `WalalaWitch/Verification/slimming-metrics.json`。Godot四方向/移动/碰撞51项、场景与窗口95项通过；实际人物像素和窗口最近邻放大比对通过。

## 当前资源

- `WalalaWitch/walala-witch.png`：160×192，5列×4行，依次下/上/右/左；每行第0列待机、第1至4列行走，共20帧。
- `WitchCustomers/<id>/<id>.png`：六款独立192×48精灵表，每款2帧待机、4帧进食，共36帧。
- 各角色的 `character-manifest.json` 和 `frames/`：主要可编辑源，统一六图层 `shadow/body/outfit/hair/equipment/fx`；阴影由游戏绘制。
- 各角色的 `*.aseprite`：从同一图层源写出的兼容格式文件；独立解析验证与PNG逐帧一致。本机没有Aseprite，未通过Aseprite应用制作或打开验证。
- 各角色的 `*.json`、`*-preview.gif`、`contact-sheet.png`、`validation-report.json`：同源切帧信息、预览和严格验证结果。
- `design-preview.png`：四方向主角与六位客人的造型预览。
- `before-after.png`：相同游戏尺寸的新旧主角对比，以及两位同风格客人之间的主角，含1倍与4倍最近邻预览。
- `WalalaWitch/walk-*.gif`：四方向独立循环预览。
- `source-validation.json`：56帧的图层、兼容源文件、精灵表与JSON独立逐字节一致性验证。
- `render-validation.json`：实际Godot截图与人物素材的像素比对，以及720p/1080p窗口的最近邻缩放比对。

## 接入

`Scenes/LanternLane/lantern_lane.gd` 加载新主角；`Scenes/Gameplay/play_area.gd` 加载六位新客人。`CHARACTER_SIZE` 为统一的原生/世界显示尺寸，提示文字依此避开人物。F5运行项目即可查看。

## 重建

```powershell
python Art/Character/Storybook/tools/run_pipeline.py
```

默认调用已安装的 `generate-consistent-pixel-animations` 技能导出与验证工具，也可通过 `--skill-dir` 指定技能位置。运行会重新生成本目录的图层与导出，编辑PNG源后仅导出请加 `--export-only`。这不是Aseprite文件的反向导入工具。

2026-10-10 资源校验：7位人物、56帧严格验证零错误/零警告；兼容源的6图层、标签、时长、透明度、脚底位置与动作帧差异全部通过独立检查。Godot四方向动画、移动与碰撞51项通过；场景/窗口95项、客人用餐15项通过。9组人物截图的所有不透明像素与源帧完全相同；13组720p/1080p窗口与原生画布的最近邻放大结果逐像素一致。实机截图见 `Art/Environment/Hearthwood/Verification/` 以及 `Scenes/Gameplay/Verification/`。尚未验证导出包或其他平台。
