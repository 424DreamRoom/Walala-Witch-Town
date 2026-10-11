# 萤萝 · 巡灯员

萤萝提着月灯、携带酒红手记，保管小镇尚未写完的故事。她以鼠尾草绿斗篷、紫灰短发、月牙帽饰区别于现有居民。新游戏起名后由她欢迎玩家，此后负责十二章主线的目标对话与完成结算。

`yingluo_world_32.png` 是游戏当前使用的原生 **32×32 RGBA** 场景精灵，以 1:1 尺寸、最近邻采样显示。站立时不进行小数缩放，脚底为排序与碰撞原点。形象重新简化为短身比例、绿色帽子、紫灰短发、提灯和手记，当前为朝前静态站姿。

新版由内置 image_gen 生成简化像素形象，完整生成图保存在 `yingluo_world_32_source.png`。按用户要求，通过 `export_world_32.gd` 最近邻导出到准确的 32×32 画布；不插值混色，保留采样点 alpha。新版提示词在 `prompts-32.json`，哈希和导出过程在 `manifest.json`。可重建：`godot --headless --path . --script res://Art/Characters/Yingluo/export_world_32.gd`。

`yingluo.png` 为原有对话立绘，保持 1024×1536。旧版 `yingluo_world.png` 与 `prompts.json` 保留供追溯，游戏不再使用其 36×54 缩放形象。

素材、导入文件与测试产物均位于 `MyArt/` 外。仅导入实际使用纹理的工具为 `Scenes/Campaign/run_guide_verification.py import`；原稿目录在运行前后只读核对哈希。此工具不生成或清理原稿目录。
