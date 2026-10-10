# 木香小镇环境美术

根据 `游戏参考截屏/东方夜雀食堂/主角的家（加上主角）.png` 的视觉特征制作的原创 PNG 像素素材：斜俯视、深色细轮廓、木纹和织物纹样、柔和的灰绿与玫瑰色家具、窗边暖光。截图仅提供室内参考，室外屋顶、树木与石路据此延伸设计。没有复制截图像素、原作角色或 UI。

制作方式为用户确认的逐像素绘制，使用 Pillow 在原生分辨率落点，不调用图像生成 API。`tools/build_art.py` 为可重建的绘制源，`manifest.json` 记录固定随机种子、调色板和资源尺寸。

- 小镇：`town_ground.png`、九间 `shop_*.png`、`town_tree.png`、`planter.png`、`menu.png`；1280×960 世界，沿用既有建筑和道路位置。
- 野外与餐厅：`field_background.png`、`restaurant_background.png`，以及四种 `gather_*.png`；640×360 原生画布。
- 小女巫之家：`home_ground.png` 和独立的 `home_*.png` 家具；640×480 世界。床、书架、药剂台、厨房、沙发、圆桌、木凳和书桌使用同一材质与像素尺度。
- `town_layout.json`、`home_layout.json`、`field_layout.json`：地图对象、碰撞、入口与出生点数据。
- `town_overview.png`、`home_overview.png`：合成美术总览；`home_with_witch.png` 为加入现有角色的尺寸预览。运行时加载拆分素材，角色没有烘焙进地图。

旧版资源保留在 `Scenes/LanternLane/Art/`。游戏图片使用最近邻过滤、整数倍缩放。主角和六位客人使用 `Art/Character/Storybook/` 的原生32×48参考画风重绘，`home_with_witch.png` 预览同步使用新人物。

## 室外装饰

小镇新增57处庭院与街边装饰：花坛、路灯、长椅、信箱、水井、小池塘、栅栏、药草盆、木桶和果箱。草地碎点减少，庭院补充草丛、石边与踏石。入口使用叶子、餐碗、月牙图案的像素木路牌，靠近时仍显示原有互动文字。

`outdoor_*.png` 共19种原生像素素材；`field_overview.png` 为野外合成总览。野外增加20个独立树木/灌木/地面对象；东侧树林与小池塘为边界外的背景景观。树木与人物共同按脚底Y排序，树干、倒木和石块使用小范围实体碰撞；花草没有新增采集或交互功能。采集文字独立绘制在树冠上方。

仅重建室外素材使用：

```powershell
python Art/Environment/Hearthwood/tools/build_outdoors.py
python Art/Environment/Hearthwood/tools/validate_outdoors.py
```

该命令更新室外PNG、布局、总览与资源清单。完整环境重建仍使用 `tools/build_art.py`，最后自动应用同一室外装饰绘制流程。

## 环境动画

小镇及野外的树木、灌木、蕨草、花坛、药草盆和旧花盆自动轻轻摇曳；树冠与嫩枝在整数像素上移动，树根、花盆及实体碰撞固定。每个物件按地图位置取不同起始相位，避免全部同步摆动。晴天为1–2像素微风，雨雪时使用2–3像素的较强摇曳帧，并略微加快节奏。

池塘有移动的像素涟漪与轻浮动睡莲，池岸保持固定；街灯玻璃内暖光轻微变化，家中书桌烛火有小幅跳动。野外右侧原来烘焙在背景中的树、灌木和池塘已拆成独立物件，与其他室外物件共同按脚底Y排序。它们位于地图边界外，无新增碰撞或采集交互。

`Ambient/` 包含11类原生PNG精灵表、对应GIF和 `manifest.json`。每组12帧，植物有微风与较强风两组；左右各留4像素透明余量。动画使用最近邻过滤，不旋转或缩放物件。生成器检查植物帧的固定底部、透明度与原素材调色板，水面和灯火在各自局部色块上变化。`Scenes/Gameplay/ambient_animation.gd` 统一控制这些像素帧；砍树时和原受击抖动并存，砍完后切回单帧树桩，次日重新生成摇曳树木。

```powershell
python Art/Environment/Hearthwood/tools/build_ambient.py
python Scenes/WitchHome/run_verification.py ambient_capture
python Art/Environment/Hearthwood/tools/build_ambient.py --runtime-preview
```

室外重建器会自动重建环境动画。`Ambient/runtime-field.gif` 为24帧真实Godot画面构成的循环预览；原生截图、窗口截图及日志位于 `Verification/Ambient/` 和 `Verification/ambient_capture.log`。导出时应将 `Ambient/manifest.json` 与地图布局JSON一起纳入导出过滤。

## 进入小女巫之家

F5 运行项目，从出生点向西走到第一间绿屋顶住宅，在门前“家 E”路标处按 E。室内底部台阶处按 E 回到小镇；R 回到室内安全出生点。家具独立加载并参与碰撞和 Y 排序，镜头随角色滚动，室内停止雨雪绘制与雨声。

## 验证记录

同日环境动画验证：11类原生动画生成通过，Godot窗口环境动画105项、小镇移动51项、室内和窗口95项、室外采集路线及遮挡48项、砍树/挖矿/钓鱼80项均通过，无脚本错误。动画专用检查验证真实时间推进、不同物件的起始相位、树根/花盆像素固定、雨雪切换到较强风帧、砍树受击与摇曳并存、树桩停止摇曳、室内烛火及出入场景的处理。动态树冠经过24帧实际渲染像素差异检查；1280×720窗口与原生画布最近邻放大一致。

Godot 4.7.2 / Windows，2026-10-10 初次美术接入验证：31 张 PNG 完整性检查通过；新家无窗口验证 32 项、窗口验证 53 项、小镇移动与碰撞回归 50 项、两日经营流程回归 93 项全部通过。窗口验证保存小镇、住宅外观、室内南北、野外和餐厅实机截图；1280×720 与 1920×1080 截图均与原生画布最近邻放大结果逐像素一致。

同日精简 UI 后，场景与界面无窗口检查 47 项、窗口检查 77 项、两日经营鼠标回归 121 项全部通过；`Verification/` 实机截图已更新为精简后的界面。

同日人物参考画风重绘后，小镇动画/移动/碰撞51项、场景与窗口95项、客人用餐15项通过。7位人物共56帧严格资源校验通过；9组实际人物像素与源帧、13组窗口最近邻放大比对全部一致。当前截图已更新为新人物。

同日室外装饰验证：19种PNG的尺寸与像素透明度通过检查；使用10×6脚底碰撞盒的四方向寻路确认15个小镇目的地、全部9个采集点与野外出口可达。Godot室外实测48项、小镇回归51项、场景与窗口回归95项通过，包含真实移动至全部采集点并采集、倒木碰撞、入口出入，以及树后遮挡/树前人物像素完整显示。日志为 `Verification/outdoors_capture.log`；8组实际截图以 `outdoor_` 开头，窗口与原生画布的最近邻放大逐像素一致。室外重建的PNG和布局哈希完全一致，室内和人物资源哈希保持一致。室外专用检查使用 `python Scenes/WitchHome/run_verification.py outdoors_capture`，截图缩放校验使用 `python Art/Environment/Hearthwood/tools/validate_outdoors.py --screens`。

验证脚本为 `Scenes/WitchHome/verify_home.gd`，执行器为 `Scenes/WitchHome/run_verification.py`。运行 `python Scenes/WitchHome/run_verification.py headless` 或 `capture` 可重新检查；日志与实机截图在本目录 `Verification/`，经营回归日志在 `output/loop_headless.log`。尚未验证导出包或其他平台。
