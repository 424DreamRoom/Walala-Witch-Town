# 建造素材

69 个独立 SVG 图标位于 `icons/`，按占地尺寸导出的场景 SVG 位于 `objects/`。已有七种室内家具继续使用其原有场景美术。配方与中文、英语、日语、繁体中文名称由 `Scenes/Building/tools/build_catalog_assets.py` 维护；运行后需再执行 `python Localization/build_catalog.py`。

素材使用木色、奶油色、鼠尾草绿和玫瑰色的原创轮廓，不含多洛可小镇的图像或数据文件。参考其工作台制作家具、设施的流程，配方数值、物件命名和图像均为本项目设计。参考资料：[手工工作台](https://doloctown.huijiwiki.com/wiki/%E6%89%8B%E5%B7%A5%E5%B7%A5%E4%BD%9C%E5%8F%B0)、[床](https://doloctown.huijiwiki.com/wiki/%E5%BA%8A)。

`manifest.json` 记录全部图标 ID 和 SHA-256；生成过程只读核对 `MyArt/` 哈希，不把原稿作为生成、覆盖或清理目标。完整材料和场地清单见 [CATALOG.md](CATALOG.md)。
