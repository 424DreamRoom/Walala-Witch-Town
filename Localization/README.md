# 哗啦啦魔女镇 · 多语言

支持简体中文 `zh_CN`、英语 `en`、日语 `ja`、繁体中文 `zh_TW`。主菜单或局内暂停菜单的「设置 → 游戏 → 语言」即时切换，语言名称始终使用各自文字。首次使用简体中文，选择保存在 `user://preferences.cfg` 的 `[game] language` 中，跨场景和重启保留。「恢复本页」不重置语言。

主菜单、六个存档栏位、暂停菜单、设置、时钟、背包、任务手记、向导对话、采集与钓鱼提示、商店交易、料理、结算及鸣谢均已纳入翻译。沿用 Fusion Pixel 12 字体及木框主题；字体覆盖完整四语言词库。英文时钟使用紧凑天数与星期缩写，较长对话和任务描述自动换行。常驻 HUD 和已删除的说明区域维持现有布局。

## 维护

`messages.tsv` 是 UTF-8 翻译源，每行依次为原文、英文、日文、繁体中文，含换行的单元格使用 TSV 引号。编辑后运行：

```powershell
python Localization/build_catalog.py
```

生成器检查重复、空译文、运行代码与界面鸣谢中遗漏的中文原文，以及 `%s` / `%d` / `%.1f` 等占位符，再生成 `catalog.gd`。鸣谢界面由 `localized_text.gd` 维护；`Sounds/Walala/CREDITS.txt` 是来源与许可证开发资料，不作为界面文案扫描。同时拦截词库中的按键和鼠标操作提示；实际按键名称用于设置值，其他界面不显示操作教学，遵循根目录 `AGENTS.md`。`localization.gd` 作为 Autoload 启动时注册原生 Godot `Translation`，生成词库由脚本预加载，随项目脚本导出。

描述和对话支持 BBCode。带标签的完整原文作为翻译键，各语言可调整强调词在句中的位置，须保留相同的样式标签及参数，例如 `[color=#247f78]…[/color]`。生成器检查颜色、粗体、斜体、下划线、删除线、等宽、字号及描边等常用标签的闭合和嵌套，并比较各语言的样式标签；`[lb]` / `[rb]` 用于显示字面方括号。界面先翻译再解析，逐字显示统计解析后的字符，回看保留富文本样式。维护示例及专项验证见 `Scenes/UI/README.md`。

文字跳动 `[jump]…[/jump]` 和左右摇曳 `[sway]…[/sway]` 使用同样的完整句子翻译及标签校验，支持带参数的写法。游戏设置中的两个效果开关也有四语言翻译，切换语言不改变开关值，动画标签随译文更新。

静态 `Label`、`Button` 和普通 `OptionButton` 保留简体中文原文，使用 Godot 自动翻译。动态格式串使用 `tr(source) % values`；参数含物品名、地点、时段时使用 `localized_text.gd` 的 `format(source, values)`，先翻译模板和字符串参数，再插入数字。自绘文字必须先 `tr()` 再测量、居中和绘制。动态视图监听 `Localization.language_changed`，暂停期间也能刷新。

游戏状态保留原资源 ID、料理索引、任务 ID 和原文消息，语言不写入六个进度存档。切换语言不改变库存、金币、任务、位置或时间；旧存档格式仍可读取。格式化反馈使用临时模板与参数，结算根据数值状态生成当前语言文本。鸣谢仅展示资源名称与作者署名，主菜单与游戏内入口共用同一份内容；详细来源与许可证保留在项目资料中。

## 验证

```powershell
python Localization/run_verification.py headless
python Localization/run_verification.py capture
python Localization/run_verification.py restart
```

验证四套词库的实际查找、全部字体字符、真实语言下拉操作、即时刷新、按钮与文字宽度、暂停期间状态不变、跨语言存档兼容及两个独立进程间的语言记忆。截图和日志写入 `Verification/`，测试使用独立设置和存档路径，结束后清理测试数据。可用 `--godot PATH` 或 `GODOT_BIN` 指定 Godot。
