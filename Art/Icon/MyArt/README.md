# 用户手绘食物素材

`MyArt/` 只由用户维护，禁止工具向其中写入、重命名、覆盖、移动或删除文件。
这里的 `Food/*.png` 是面包、鸡蛋、番茄原稿的运行时导出，保持 16×16 画布、原始颜色及透明度。
不在原稿目录创建 `.import`、清单或缓存；Godot 引用这里的 PNG。

```powershell
python Art/Icon/MyArt/export_food.py --aseprite 'C:/steam/steamapps/common/Aseprite/Aseprite.exe'
```

需要 Python 3.9+、Pillow 与 Aseprite。脚本只读原稿，使用 Aseprite 原生合成导出，前后核对整个 `MyArt/` 的文件路径和 SHA-256。`manifest.json` 登记来源、源文件哈希、尺寸及 RGBA 哈希，重新导出可更新游戏素材。

`Scenes/Businesses/food_catalog.gd` 集中登记图标、名称和价格：面包6金、鸡蛋4金、番茄5金。橡果杂货店展示三张食材卡片及柜台实物；购买进入共享背包，支持99份堆叠、木箱转移、保存及读档。新食物保持独立物品，不转换成旧蘑菇、莓果或香草库存。背包及木箱复用相同图标。

预览与验证：

```powershell
python Scenes/Businesses/run_myart_verification.py headless
python Scenes/Businesses/run_myart_verification.py capture
python Scenes/Businesses/run_myart_verification.py preview
```

使用进程独立的 `output/myart_shop/session_<PID>/` 设置和存档，不读写正式进度。截图保存在 `output/myart_shop/`。预览从白天商店柜台开始，包含测试金币及已购食材，可直接查看商店和背包；操作方法沿用 `Scenes/Businesses/README.md`。
