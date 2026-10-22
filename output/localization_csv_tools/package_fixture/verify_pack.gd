extends SceneTree
func _initialize() -> void:
    run.call_deferred()
func run() -> void:
    var runtime = root.get_node("Localization")
    var failures := 0
    if runtime.catalog_rows.is_empty(): failures += 1
    if FileAccess.file_exists("res://Localization/catalog.gd"): failures += 1
    if FileAccess.file_exists("res://Excel/Localization/Localization.xlsx"): failures += 1
    for index in range(runtime.LOCALES.size()):
        runtime.set_language(runtime.LOCALES[index], false)
        for row in runtime.catalog_rows:
            if String(TranslationServer.translate(row[0])) != row[index + 1]: failures += 1
    print("CSV PACKAGE VERIFY END entries=", runtime.catalog_rows.size(), " failures=", failures)
    quit(failures)
