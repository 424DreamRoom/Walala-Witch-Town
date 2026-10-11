# 物品栏数字字体

`digits8.tres` 是项目原创的 4×6 像素数字字形，使用 8 像素行高、5 像素字距，覆盖 `0–9`。用于底部物品栏角标与数量；保持字号 8 和最近邻采样，使用控件的 1 像素阴影。

字形与透明图集均由 `build_digits.gd` 定义，字体图集内嵌在资源中，无需导入外部图片。重新生成：

```powershell
& $godotExe --path C:/Godot/Walala-Witch-Town --headless --script res://Art/Fonts/HudDigits8/build_digits.gd
```

生成目标仅为本目录中的 `digits8.tres`，不读取或写入 `MyArt/`。
