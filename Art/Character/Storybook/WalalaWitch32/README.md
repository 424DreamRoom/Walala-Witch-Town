# 主角 32×32 全身新版

2026-10-11：主角重新设计为原生32×32画布。紫色弯尖帽、月牙饰扣、银白短发、琥珀色眼睛、奶油色领口、短斗篷和挎包沿用角色身份，全身比例重新安排。帽子、脸、服装和双靴完整落在同一格内。

## 素材

- `walala-witch-32.png`：160×128，5列×4行，共20帧；方向顺序下/上/右/左，每行待机1帧、行走4帧。
- `../WalalaTools32/witch-tools-32.png`：160×384，5列×12行，共60帧；四方向采集、施法、等待和收杆。
- `character-keys.png`：64×64四向关键帧，每格32×32；人物占25×30，放置于(4,2)，共享32色调色板（含透明色）。工具帧最多38个不透明颜色。所有动画透明度严格为0或255。
- `grid-preview.png`：四方向像素格预览；`design-preview.png`：四方向与部分法杖姿势；`walk-*.gif`：四方向循环。
- `frames/`：六层PNG；`.aseprite`、JSON及精灵表由同一图层导出。hair层存放整个头部，outfit层存放躯干，body层存放靴子，equipment/fx用于魔杖与特效。此分组供动画合成，帽子、头发和脸未分层。

脚底锚点为(16,32)，世界显示尺寸32×32，最近邻显示。主场景、主菜单和命名头像使用同一新版精灵表；工具动作同步替换。地面碰撞、移动速度、动画索引及玩法逻辑沿用现有实现。原版与V2素材保留。

## 来源与重建

使用内置imagegen编辑模式，以`character-reference.png`中的本项目四方向角色为参考生成全身造型。完整提示见[`generation-prompt.txt`](generation-prompt.txt)，生成原图见`generated-character.png`。随后按方向切分、最近邻取样、二值透明处理及共享调色板归并，导出为原生32×32关键帧。行走使用整数像素部件位移，魔杖动作使用项目已有动作姿势重新适配32×32画布。

视觉研究沿用[mellynade](https://mellynade.itch.io/witch-animation-pack)、[Elthen](https://elthen.itch.io/2d-pixel-art-witch-sprites)与[Little Witch](https://opengameart.org/content/little-witch-0)的帽型轮廓、有限色阶及小尺寸辨识方式；未下载或拼接这些作品的像素。

需要Pillow：

```powershell
python Art/Character/Storybook/tools/build_witch_32.py
```

默认从可编辑关键帧重建；`--prepare-keys`从保存的生成原图重新准备关键帧。脚本仅向`WalalaWitch32/`和`WalalaTools32/`导出。`MyArt/`严格只读，导出前后核对`myart-before.json`全部原稿SHA256。

`validation-report.json`记录80帧的原生尺寸、二值透明、脚底、动作差异及PNG图层/Aseprite兼容源/精灵表逐字节一致性。兼容源已独立解析验证，未在Aseprite应用内打开验证。

实际Godot渲染结果见`runtime-validation.json`，隔离的设置、存档、日志和截图在`output/witch-32/`。验证入口为`output/witch-32/run_checks.py`，接受`import`、`render`、`lane`、`harvest`参数。

实机验证：Godot4.7.2导入无错误；80帧全部不透明像素与源图完全一致，含菜单脚底位置及完整命名头像共95项通过；移动、四向动画及碰撞51项通过；采集和钓鱼126项通过（含9组真实工具动作截图）。完整采集回归仍有4项既有换日检查失败，与上一版使用原始角色及工具贴图运行的基线日志逐项一致，未修改换日玩法。详细结果见`integration-validation.json`。
