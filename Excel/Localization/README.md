# 多语言表格

在 `Localization.xlsx` 中维护文案，每行填写完整的五列：

| LanguageKey | Simplified Chinese | English | Japanese | Traditional Chinese |
| --- | --- | --- | --- | --- |
| 固定查找键 | 简体中文 | 英语 | 日语 | 繁体中文 |

现有条目的键沿用原中文文本，修改显示内容时保留 `LanguageKey`。保留 `%s`、`%d` 等占位符以及富文本标签，单元格使用纯文本。各列可以调换顺序，表头名称保持不变。

Godot 编辑器打开时，保存 Excel 后会自动生成同目录的 `Localization.csv`；游戏直接读取 CSV。启动游戏前也会再次导出和校验。错误可在编辑器输出中查看，失败时保留已有 CSV。

编辑器关闭时，在项目根目录运行 `python Localization/build_catalog.py --watch` 持续监听；运行 `python Localization/build_catalog.py` 可立即导出一次。需要 Python 3.10+，插件支持 `WALALA_PYTHON` 指定解释器。

CSV、`.csv.import`、`Localization/messages.tsv` 和 `Localization/catalog.gd` 均是生成结果；修改翻译以 Excel 为准。更多规则和验证命令见 `Localization/README.md`。
