# 哗啦啦魔女镇 · 多语言

支持简体中文 `zh_CN`、英语 `en`、日语 `ja`、繁体中文 `zh_TW`。主菜单或局内暂停菜单的「设置 → 游戏 → 语言」即时切换，语言名称始终使用各自文字。首次使用简体中文，选择保存在 `user://preferences.cfg` 的 `[game] language` 中，跨场景和重启保留。「恢复本页」不重置语言。

主菜单、六个存档栏位、暂停菜单、设置、时钟、背包、任务手记、向导对话、采集与钓鱼提示、商店交易、料理、结算及鸣谢均已纳入翻译。沿用 Fusion Pixel 12 字体及木框主题；字体覆盖完整四语言词库。英文时钟使用紧凑天数与星期缩写，较长对话和任务描述自动换行。常驻 HUD 和已删除的说明区域维持现有布局。

## 维护

`Excel/Localization/Localization.xlsx` 是翻译源，现有文本已迁入用户创建的五列表格。每一行是一条文本，按表头名称映射语言，列顺序可以调整：

| 表头 | 用途 |
| --- | --- |
| `LanguageKey` | 固定查找键，供 `tr(key)` 使用，不随译文修改 |
| `Simplified Chinese` | 简体中文 `zh_CN` |
| `English` | 英语 `en` |
| `Japanese` | 日语 `ja` |
| `Traditional Chinese` | 繁体中文 `zh_TW` |

迁移条目的 `LanguageKey` 沿用原中文原文，兼容现有场景、动态文本和存档。只改显示文案时编辑后面四列；新增条目也可使用 `MENU_PLAY` 等符号键，并在代码中使用 `tr("MENU_PLAY")`。简体中文列同时注册为兼容别名，键和别名不得与其他条目冲突。

Godot 已启用 `Walala Excel Localization` 编辑器插件。编辑器打开时，每秒检查已保存的 Excel 内容，发生变化即校验并更新同目录、同文件名的 CSV；启动游戏前再强制校验一次，失败时阻止启动。Excel 未保存的内容不会导出。游戏启动时直接读取 `Excel/Localization/` 下所有 CSV，通过 `TranslationServer` 显示对应语言，运行时不依赖 Excel、Python 或 `catalog.gd`。已经运行的游戏可由开发代码调用 `Localization.reload_catalog()` 重新加载，或重新启动游戏。

开发导出使用 Python 3.10+ 标准库。插件自动查找 Python，也支持环境变量 `WALALA_PYTHON` 或项目设置 `walala/localization/python_executable` 指定解释器。编辑器关闭时可启动独立监听：

```powershell
python Localization/build_catalog.py --watch
```

一次性导出、检查输出是否最新：

```powershell
python Localization/build_catalog.py
python Localization/build_catalog.py --check
```

可在同目录添加其他 `.xlsx`，每本表映射一个同名 CSV；同一本工作簿的非空工作表使用相同表头并合并导出。Excel 的 `~$` 临时锁文件自动忽略。删除或改名工作簿时需显式处理旧 CSV；生成器发现没有匹配 Excel 的 CSV 会报告错误，不自动删除文件。

生成器检查重复键、空译文、运行代码与界面鸣谢中遗漏的中文原文，以及 `%s` / `%d` / `%.1f` 等占位符和富文本标签。单元格使用纯文本；换行、逗号、引号按标准 CSV 编码，禁止公式和 Excel 错误值。校验通过后原子替换各个输出文件，错误保留已有 CSV。`messages.tsv` 和 `catalog.gd` 同步生成，作为已有开发工具的兼容快照，不再手工维护；游戏不加载它们。CSV 配套的 `.csv.import` 将其设为原始文件，须与 CSV 一起保留；导出预设包含 `*.csv` 并排除兼容 `catalog.gd`。

鸣谢界面由 `localized_text.gd` 维护；`Sounds/Walala/CREDITS.txt` 是来源与许可证开发资料，不作为界面文案扫描。同时拦截词库中的按键和鼠标操作提示；实际按键名称用于设置值，其他界面不显示操作教学，遵循根目录 `AGENTS.md`。

描述和对话支持 BBCode。带标签的完整原文作为翻译键，各语言可调整强调词在句中的位置，须保留相同的样式标签及参数，例如 `[color=#247f78]…[/color]`。生成器检查颜色、粗体、斜体、下划线、删除线、等宽、字号及描边等常用标签的闭合和嵌套，并比较各语言的样式标签；`[lb]` / `[rb]` 用于显示字面方括号。界面先翻译再解析，逐字显示统计解析后的字符，回看保留富文本样式。维护示例及专项验证见 `Scenes/UI/README.md`。

文字跳动 `[jump]…[/jump]` 和左右摇曳 `[sway]…[/sway]` 使用同样的完整句子翻译及标签校验，支持带参数的写法。游戏设置中的两个效果开关也有四语言翻译，切换语言不改变开关值，动画标签随译文更新。

静态 `Label`、`Button` 和普通 `OptionButton` 保留简体中文原文，使用 Godot 自动翻译。动态格式串使用 `tr(source) % values`；参数含物品名、地点、时段时使用 `localized_text.gd` 的 `format(source, values)`，先翻译模板和字符串参数，再插入数字。自绘文字必须先 `tr()` 再测量、居中和绘制。动态视图监听 `Localization.language_changed`，暂停期间也能刷新。

游戏状态保留原资源 ID、料理索引、任务 ID 和原文消息，语言不写入六个进度存档。切换语言不改变库存、金币、任务、位置或时间；旧存档格式仍可读取。格式化反馈使用临时模板与参数，结算根据数值状态生成当前语言文本。鸣谢仅展示资源名称与作者署名，主菜单与游戏内入口共用同一份内容；详细来源与许可证保留在项目资料中。

## 验证

```powershell
python Localization/run_verification.py headless
python Localization/run_verification.py capture
python Localization/run_verification.py restart
python Localization/run_verification.py csv
python Localization/test_excel_catalog.py
```

验证四套 CSV 词库的实际查找、全部字体字符、真实语言下拉操作、即时刷新、按钮与文字宽度、暂停期间状态不变、跨语言存档兼容及两个独立进程间的语言记忆。CSV 专项检查 BOM、表头重排、多行及引号、符号键与中文别名、更新和错误回退；Python 测试在临时项目中验证自动导出、文件监听及无效更新不覆盖 CSV。截图和日志写入 `Verification/`，测试将应用数据目录隔离到独立 profile，不读取玩家正式设置或存档。测试环境的 Windows 根证书存储错误不影响离线验证，其余引擎及脚本错误仍视为失败。可用 `--godot PATH` 或 `GODOT_BIN` 指定 Godot。
